import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/ml/android_kiosk_probe_fusion.dart';
import 'package:attendance_kiosk_app/core/ml/android_ml_tuning.dart';
import 'package:attendance_kiosk_app/core/ml/camera_frame_clone.dart';
import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';
import 'package:attendance_kiosk_app/core/ml/face_frame_analysis.dart';
import 'package:attendance_kiosk_app/core/ml/face_match_debug_log.dart';
import 'package:attendance_kiosk_app/core/ml/face_recognition_trace.dart';
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
  }) : _analyzer = analyzer,
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

  static int get _maxProbeRing =>
      Platform.isAndroid ? AndroidKioskProbeFusion.maxRing : 2;

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
    if (Platform.isAndroid) {
      return AndroidKioskProbeFusion.combine(_probeRing, latest);
    }
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

  void _storeEmbedCache(
    int? trackingId,
    List<double> embedding, {
    double? matchScore,
  }) {
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
      FaceRecognitionTrace.kioskSkip('gallery_empty (enrolledFaceCount=0)');
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
      FaceRecognitionTrace.kioskSkip('frame_clone_null');
      return const KioskPipelineIdle();
    }

    FaceFrameAnalysis analysis;
    if (Platform.isAndroid) {
      // Run detect when scheduled OR when we have no valid cached face (every-other-
      // frame cadence was skipping embed/match entirely after a detect timeout).
      final runDetect =
          _scheduler.shouldRunDetection || !_scheduler.hasCachedFace;
      if (runDetect) {
        final fresh = await _analyzer.detectClone(clone);
        if (fresh.hasSingleFace) {
          _scheduler.cacheAnalysis(fresh);
          analysis = fresh;
        } else if (_scheduler.hasCachedFace) {
          analysis = _scheduler.cachedAnalysis!;
        } else {
          analysis = fresh;
        }
      } else {
        analysis = _scheduler.cachedAnalysis!;
      }
    } else if (_scheduler.shouldRunDetection) {
      analysis = await _analyzer.detectClone(clone);
      _scheduler.cacheAnalysis(analysis);
    } else if (_scheduler.hasCachedFace) {
      analysis = _scheduler.cachedAnalysis!;
    } else {
      FaceRecognitionTrace.kioskSkip('no_cached_face');
      return const KioskPipelineIdle();
    }

    if (!analysis.hasSingleFace) {
      session.onNoReliableFace();
      if (!Platform.isAndroid || !_scheduler.hasCachedFace) {
        _scheduler.reset();
        _clearEmbedCache();
      }
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

    var face = analysis.face!;
    final usedCachedEmbed = _cachedEmbedForTrack(trackingId) != null;
    List<double>? embedding = _cachedEmbedForTrack(trackingId);
    double? cropSharpness;

    if (embedding == null) {
      if (!session.canRunEmbed()) {
        FaceRecognitionTrace.kioskSkip('embed_throttled');
        return const KioskPipelineIdle();
      }
      // Android: landmarks must come from the same [clone] as the NV21 bytes.
      if (Platform.isAndroid) {
        final synced = await _analyzer.detectClone(clone);
        if (!synced.hasSingleFace || synced.face == null) {
          // Avoid a hard skip when detect is flaky: fall back to cached face.
          if (_scheduler.hasCachedFace) {
            final cached = _scheduler.cachedAnalysis!;
            if (cached.hasSingleFace && cached.face != null) {
              face = cached.face!;
              analysis = cached;
            } else {
              FaceRecognitionTrace.kioskSkip('embed_sync_no_face');
              return const KioskPipelineIdle();
            }
          } else {
            FaceRecognitionTrace.kioskSkip('embed_sync_no_face');
            return const KioskPipelineIdle();
          }
        }
        if (synced.hasSingleFace && synced.face != null) {
          _scheduler.cacheAnalysis(synced);
          face = synced.face!;
          analysis = synced;
        }
      }
      KioskEmbedResult embed;
      try {
        embed = await _analyzer.embedWhenReady(
          clone: clone,
          face: face,
          gallery: _faces.gallerySnapshot,
        );
      } catch (e, st) {
        FaceRecognitionTrace.embeddingFailed(
          phase: 'kiosk',
          reason: 'exception: $e',
        );
        if (kDebugMode) {
          debugPrintStack(stackTrace: st);
        }
        return const KioskPipelineIdle();
      }
      if (!embed.ok || embed.embedding == null) {
        final hint = embed.message?.trim();
        if (hint == null || hint.isEmpty) {
          FaceRecognitionTrace.embeddingFailed(
            phase: 'kiosk',
            reason: 'embed returned null',
          );
        }
        if (hint != null && hint.isNotEmpty) {
          return KioskPipelineStatus(hint);
        }
        return const KioskPipelineIdle();
      }
      embedding = embed.embedding!;
      cropSharpness = embed.cropSharpness;
      session.markEmbedProcessed();
      _recordProbe(trackingId, embedding);
    } else {
      FaceRecognitionTrace.embeddingCached(
        dim: embedding.length,
        trackingId: trackingId,
      );
    }

    final probeEmbedding = embedding;
    final probe = _probeForMatch(probeEmbedding);
    FaceRecognitionTrace.kioskProbeReady(
      probe: probe,
      galleryCount: _faces.enrolledFaceCount,
    );

    final matchEither = await _faces.matchEmployee(
      probe,
      lockedEmployeeId: lockedId,
      // Android: kiosk uses TFLite scoring (yaw/pitch not used). Passing null
      // avoids any platform-specific euler quirks leaking into matching.
      probeYaw: Platform.isAndroid ? null : face.headEulerAngleY,
      probePitch: Platform.isAndroid ? null : face.headEulerAngleX,
    );

    final thr = FaceEmbeddingCodec.effectiveMatchThreshold;

    return matchEither.fold((f) => KioskPipelineStatus(f.message), (outcome) {
      final bestId = outcome.employeeId ?? outcome.bestEmployeeId ?? '?';
      final score = outcome.rejected ? outcome.bestScore : outcome.confidence;

      if (outcome.rejected || outcome.employeeId == null) {
        // Do not clear embedding cache on reject: Android probes can be noisy frame-to-frame,
        // and clearing causes oscillation between good/bad embeddings for the same track.
        FaceRecognitionTrace.kioskFrameDecision(
          bestEmployeeId: bestId,
          score: score,
          margin: outcome.margin,
          threshold: thr,
          phase: usedCachedEmbed ? 'match_cached' : 'match_fresh',
          verdict: 'reject_probe',
          reason: outcome.reason ?? '',
          usedCachedEmbed: usedCachedEmbed,
          cropSharpness: cropSharpness,
          confirmStreak: session.matchConfirmStreakCount,
          unknownStreak: session.unknownStreakCount,
        );
        return _handleReject(outcome, session);
      }

      final id = outcome.employeeId!;
      _storeEmbedCache(
        trackingId,
        probeEmbedding,
        matchScore: outcome.confidence,
      );
      session.refreshFaceLock(id);

      if (session.isEmployeeOnCooldown(id)) {
        session.clearUnknownStreak();
        return const KioskPipelineIdle();
      }

      final confirmed = session.registerMatchCandidate(
        id,
        confidence: outcome.confidence,
        margin: outcome.margin,
        yaw: face.headEulerAngleY,
        pitch: face.headEulerAngleX,
      );

      FaceRecognitionTrace.kioskFrameDecision(
        bestEmployeeId: id,
        score: outcome.confidence,
        margin: outcome.margin,
        threshold: thr,
        phase: usedCachedEmbed ? 'match_cached' : 'match_fresh',
        verdict: confirmed ? 'confirm_open' : 'confirm_pending',
        reason: confirmed ? 'confirmed' : 'pending',
        usedCachedEmbed: usedCachedEmbed,
        cropSharpness: cropSharpness,
        confirmStreak: session.matchConfirmStreakCount,
        unknownStreak: session.unknownStreakCount,
      );

      if (!confirmed) {
        return const KioskPipelineIdle();
      }

      FaceMatchDebugLog.log(
        'Kiosk match $id conf=${outcome.confidence.toStringAsFixed(4)}',
      );
      return KioskPipelineMatch(employeeId: id, confidence: outcome.confidence);
    });
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

    if (Platform.isAndroid &&
        session.pendingEmployeeIdValue != null &&
        session.matchConfirmStreakCount >= 1 &&
        bestId == session.pendingEmployeeIdValue &&
        score >= 0.68) {
      return const KioskPipelineIdle();
    }

    final frames = Platform.isAndroid
        ? session.requiredUnknownStreakForScore(score)
        : FaceEmbeddingCodec.unknownConfirmFrames(
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
