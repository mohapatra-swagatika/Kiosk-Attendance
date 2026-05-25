import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/ml/android_ml_tuning.dart';
import 'package:attendance_kiosk_app/core/ml/camera_frame_clone.dart';
import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';
import 'package:attendance_kiosk_app/core/ml/face_frame_analysis.dart';
import 'package:attendance_kiosk_app/core/ml/face_match_debug_log.dart';
import 'package:attendance_kiosk_app/core/ml/kiosk_face_analyzer.dart';
import 'package:attendance_kiosk_app/core/ml/kiosk_frame_scheduler.dart';
import 'package:attendance_kiosk_app/core/ml/kiosk_live_gate.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/face_repository.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/providers/kiosk_scan_session.dart';

sealed class KioskPipelineTick {
  const KioskPipelineTick();
}

class KioskPipelineStatus extends KioskPipelineTick {
  const KioskPipelineStatus(this.message);
  final String message;
}

class KioskPipelineMatch extends KioskPipelineTick {
  const KioskPipelineMatch({
    required this.employeeId,
    required this.confidence,
  });

  final String employeeId;
  final double confidence;
}

class KioskPipelineUnknown extends KioskPipelineTick {
  const KioskPipelineUnknown(this.reason);
  final String reason;
}

class KioskPipelineIdle extends KioskPipelineTick {
  const KioskPipelineIdle();
}

/// Production kiosk unlock: scheduled detect → live gate → embed → cosine match.
class KioskRecognitionPipeline {
  KioskRecognitionPipeline({
    required KioskFaceAnalyzer analyzer,
    required FaceRepository faceRepository,
  })  : _analyzer = analyzer,
        _faces = faceRepository;

  final KioskFaceAnalyzer _analyzer;
  final FaceRepository _faces;
  final KioskFrameScheduler _scheduler = KioskFrameScheduler();
  final KioskLiveGate _liveGate = KioskLiveGate();

  static Duration get _embedCacheTtl => Platform.isAndroid
      ? AndroidMlTuning.kioskEmbedCacheTtl
      : const Duration(milliseconds: 500);

  List<double>? _cachedEmbedding;
  int? _cachedTrackingId;
  DateTime? _cachedEmbedAt;

  /// Recent embeddings for the active ML Kit track — fused before match.
  final List<List<double>> _probeRing = [];
  /// Fewer fused probes → less blurring of identity across head movement.
  static const int _maxProbeRing = 2;

  Future<void> preloadGallery() async {
    await _faces.preloadGallery();
  }

  /// Full reset (leaving kiosk / cold start).
  void reset() {
    softReset();
    _liveGate.reset();
  }

  /// After a dialog — keep live gate + session lock; drop frame/embed caches only.
  void softReset() {
    _scheduler.reset();
    _clearEmbedCache();
  }

  void _clearEmbedCache() {
    _cachedEmbedding = null;
    _cachedTrackingId = null;
    _cachedEmbedAt = null;
    _probeRing.clear();
  }

  void _recordProbe(int? trackingId, List<double> embedding) {
    if (trackingId == null) return;
    if (_cachedTrackingId != null && trackingId != _cachedTrackingId) {
      _probeRing.clear();
    }
    _probeRing.add(embedding);
    while (_probeRing.length > _maxProbeRing) {
      _probeRing.removeAt(0);
    }
  }

  List<double> _probeForMatch(List<double> latest) {
    if (_probeRing.isEmpty) return latest;
    return FaceEmbeddingCodec.fuseProbeEmbeddings(_probeRing) ?? latest;
  }

  List<double>? _cachedEmbedForTrack(int? trackingId) {
    if (_cachedEmbedding == null || trackingId == null) return null;
    if (_cachedTrackingId != trackingId) return null;
    final at = _cachedEmbedAt;
    if (at == null) return null;
    if (DateTime.now().difference(at) > _embedCacheTtl) return null;
    return _cachedEmbedding;
  }

  void _storeEmbedCache(int? trackingId, List<double> embedding) {
    _cachedEmbedding = embedding;
    _cachedTrackingId = trackingId;
    _cachedEmbedAt = DateTime.now();
  }

  Future<KioskPipelineTick> processFrame({
    required CameraImage image,
    required CameraDescription description,
    required DeviceOrientation orientation,
    required KioskScanSession session,
  }) async {
    if (!session.canProcessFrame()) {
      return const KioskPipelineIdle();
    }

    // No embeddings — skip clone, ML Kit, and TFLite (keeps preview fluid).
    if (_faces.enrolledFaceCount == 0) {
      session.markFrameProcessed();
      session.clearUnknownStreak();
      _scheduler.reset();
      _clearEmbedCache();
      return const KioskPipelineIdle();
    }

    session.markFrameProcessed();

    final clone = CameraFrameClone.fromCameraImage(
      image: image,
      description: description,
      orientation: orientation,
    );
    if (clone == null) {
      return const KioskPipelineIdle();
    }

    FaceFrameAnalysis analysis;
    if (_scheduler.shouldRunDetection) {
      analysis = await _analyzer.detectClone(clone);
      _scheduler.cacheAnalysis(analysis);
    } else if (_scheduler.hasCachedFace) {
      analysis = _scheduler.cachedAnalysis!;
    } else {
      return const KioskPipelineIdle();
    }

    if (!analysis.hasSingleFace) {
      session.onNoReliableFace();
      _scheduler.reset();
      _clearEmbedCache();
      return const KioskPipelineIdle();
    }

    session.onFacePresent();
    final trackingId = analysis.trackingId;
    session.bindFaceTrack(trackingId);

    final lockedId = session.lockedEmployeeId;
    if (lockedId != null && session.isEmployeeOnCooldown(lockedId)) {
      session.clearUnknownStreak();
      return const KioskPipelineIdle();
    }

    if (!session.liveGateSatisfied) {
      final liveHint = _liveGate.feed(analysis);
      if (liveHint != null) {
        return KioskPipelineStatus(liveHint);
      }
    }
    if (_liveGate.isOpen) {
      session.markLiveGatePassed();
    }

    final face = analysis.face!;
    List<double>? embedding = _cachedEmbedForTrack(trackingId);

    if (embedding == null) {
      if (!session.canRunEmbed()) {
        return const KioskPipelineIdle();
      }
      final embed = await _analyzer.embedWhenReady(clone: clone, face: face);
      if (!embed.ok || embed.embedding == null) {
        return const KioskPipelineIdle();
      }
      embedding = embed.embedding!;
      session.markEmbedProcessed();
      _storeEmbedCache(trackingId, embedding);
      _recordProbe(trackingId, embedding);
    }

    final probe = _probeForMatch(embedding);

    final matchEither = await _faces.matchEmployee(
      probe,
      lockedEmployeeId: lockedId,
      probeYaw: face.headEulerAngleY,
      probePitch: face.headEulerAngleX,
    );

    return matchEither.fold(
      (f) => KioskPipelineStatus(f.message),
      (outcome) {
        if (outcome.rejected || outcome.employeeId == null) {
          return _handleReject(outcome, session);
        }

        final id = outcome.employeeId!;
        session.refreshFaceLock(id);

        if (session.isEmployeeOnCooldown(id)) {
          session.clearUnknownStreak();
          return const KioskPipelineIdle();
        }

        if (!session.registerMatchCandidate(
          id,
          confidence: outcome.confidence,
          margin: outcome.margin,
          yaw: face.headEulerAngleY,
          pitch: face.headEulerAngleX,
        )) {
          return const KioskPipelineIdle();
        }

        FaceMatchDebugLog.log(
          'Kiosk match $id conf=${outcome.confidence.toStringAsFixed(4)}',
        );
        return KioskPipelineMatch(
          employeeId: id,
          confidence: outcome.confidence,
        );
      },
    );
  }

  KioskPipelineTick _handleReject(
    FaceMatchOutcome outcome,
    KioskScanSession session,
  ) {
    final score = outcome.bestScore;
    final bestId = outcome.bestEmployeeId;
    final margin = outcome.margin;

    if (session.shouldSuppressUnknown(
      bestEmployeeId: bestId,
      bestScore: score,
    )) {
      session.clearUnknownStreak();
      return const KioskPipelineIdle();
    }

    final frames = FaceEmbeddingCodec.unknownConfirmFrames(
      bestScore: score,
      margin: margin,
    );
    if (session.registerBiometricUnknown(requiredStreak: frames)) {
      final detail = outcome.reason?.trim();
      final message = (detail != null && detail.isNotEmpty)
          ? detail
          : KioskStrings.unknownFace;
      return KioskPipelineUnknown(message);
    }

    return const KioskPipelineIdle();
  }

  Future<void> dispose() => _analyzer.dispose();
}
