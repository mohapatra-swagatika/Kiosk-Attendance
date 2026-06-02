import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';
import 'package:attendance_kiosk_app/core/ml/face_match_debug_log.dart';
import 'package:attendance_kiosk_app/core/ml/face_profile_poses.dart';

/// Step-by-step trace for registration → storage → kiosk recognition (debug).
abstract final class FaceRecognitionTrace {
  FaceRecognitionTrace._();

  /// Verbose enrollment pose logs in debug/profile, or release with:
  /// `flutter run --dart-define=FACE_ENROLL_TRACE=true`
  static const bool _enrollTraceFlag =
      bool.fromEnvironment('FACE_ENROLL_TRACE', defaultValue: false);

  static bool get enrollmentTraceEnabled =>
      !kReleaseMode || _enrollTraceFlag;

  /// Verbose kiosk matching logs in debug/profile, or release with:
  /// `flutter run --dart-define=FACE_KIOSK_TRACE=true`
  static const bool _kioskTraceFlag =
      bool.fromEnvironment('FACE_KIOSK_TRACE', defaultValue: false);

  static bool get kioskTraceEnabled => !kReleaseMode || _kioskTraceFlag;

  static const String _tag = 'FaceTrace';
  static DateTime? _lastSimilarityTraceAt;
  static DateTime? _lastKioskSkipTraceAt;
  static const Duration _similarityTraceInterval = Duration(seconds: 2);
  static const Duration _kioskSkipTraceInterval = Duration(seconds: 2);

  static void log(String step, String detail) {
    if (kReleaseMode && !_kioskTraceFlag && !_enrollTraceFlag) return;
    final platform = Platform.isAndroid ? 'android' : 'ios';
    debugPrint('[$_tag][$platform] $step — $detail');
    FaceMatchDebugLog.log('[$platform] $step: $detail');
  }

  static DateTime? _lastEnrollmentTraceAt;
  static const Duration _enrollmentTraceInterval = Duration(milliseconds: 120);

  static void enrollmentDetect({
    required int rawFaceCount,
    required int usedFaceCount,
    required int ignoredSpurious,
    required String note,
  }) {
    log(
      'ENROLL_DETECT',
      'raw=$rawFaceCount used=$usedFaceCount ignored=$ignoredSpurious $note',
    );
  }

  /// Throttled pose / step gate trace during Android enrollment.
  static void enrollmentPose({
    required String step,
    required int faceCount,
    required double yaw,
    required double pitch,
    double? roll,
    required double center,
    required double distance,
    required double stability,
    required bool framingOk,
    required bool inTarget,
    required bool stepQueued,
    required String detail,
    double? neutralPitch,
    double? pitchDelta,
    String angleSource = '',
    double? baselineYaw,
    double? baselinePitch,
  }) {
    if (!enrollmentTraceEnabled) return;
    final now = DateTime.now();
    if (!stepQueued &&
        _lastEnrollmentTraceAt != null &&
        now.difference(_lastEnrollmentTraceAt!) < _enrollmentTraceInterval) {
      return;
    }
    _lastEnrollmentTraceAt = now;
    log(
      'ENROLL_POSE',
      'step=$step faces=$faceCount src=$angleSource '
      'yaw=${yaw.toStringAsFixed(1)} pitch=${pitch.toStringAsFixed(1)} '
      'roll=${roll?.toStringAsFixed(1) ?? "n/a"} '
      'baseYaw=${baselineYaw?.toStringAsFixed(1) ?? "n/a"} '
      'basePitch=${baselinePitch?.toStringAsFixed(1) ?? "n/a"} '
      'neutral=${neutralPitch?.toStringAsFixed(1) ?? "n/a"} '
      'pitchΔ=${pitchDelta?.toStringAsFixed(1) ?? "n/a"} '
      'center=${center.toStringAsFixed(2)} dist=${distance.toStringAsFixed(2)} '
      'stab=${stability.toStringAsFixed(2)} frame=$framingOk '
      'target=$inTarget queued=$stepQueued | $detail',
    );
  }

  static void enrollmentStepAdvanced({
    required String fromStep,
    required String toStep,
    required double yaw,
    required double pitch,
  }) {
    log(
      'ENROLL_STEP',
      '$fromStep→$toStep yaw=${yaw.toStringAsFixed(1)} pitch=${pitch.toStringAsFixed(1)}',
    );
  }

  static void registrationCompleted({
    required String employeeId,
    required int sampleCount,
    required double yawSpread,
  }) {
    log(
      'REGISTRATION_COMPLETE',
      'employeeId=$employeeId samples=$sampleCount yawSpread=${yawSpread.toStringAsFixed(1)}',
    );
  }

  static void embeddingGenerated({
    required String phase,
    required int dim,
    bool cropOk = true,
  }) {
    log(
      'EMBEDDING_GENERATED',
      'phase=$phase dim=$dim cropOk=$cropOk',
    );
  }

  static DateTime? _lastEmbedFailTraceAt;
  static const Duration _embedFailTraceInterval = Duration(milliseconds: 800);

  static void embeddingFailed({required String phase, required String reason}) {
    if (phase == 'kiosk') {
      final now = DateTime.now();
      if (_lastEmbedFailTraceAt != null &&
          now.difference(_lastEmbedFailTraceAt!) < _embedFailTraceInterval) {
        return;
      }
      _lastEmbedFailTraceAt = now;
    }
    log('EMBEDDING_FAILED', 'phase=$phase reason=$reason');
  }

  /// Why kiosk did not reach embed/match this frame (throttled).
  static void kioskSkip(String reason, {bool force = false}) {
    if (!kioskTraceEnabled) return;
    final now = DateTime.now();
    if (!force &&
        _lastKioskSkipTraceAt != null &&
        now.difference(_lastKioskSkipTraceAt!) < _kioskSkipTraceInterval) {
      return;
    }
    _lastKioskSkipTraceAt = now;
    log('KIOSK_SKIP', reason);
  }

  static void embeddingCached({required int dim, int? trackingId}) {
    log(
      'EMBEDDING_CACHED',
      'phase=kiosk dim=$dim track=${trackingId ?? "none"}',
    );
  }

  static void profileSaved({
    required String employeeId,
    required Map<String, dynamic> profile,
    required bool diskVerified,
  }) {
    log(
      'PROFILE_SAVED',
      'employeeId=$employeeId v=${profile['v']} diskVerified=$diskVerified '
      'templates=${_templateCount(profile)}',
    );
    FaceMatchDebugLog.logProfileSummary(
      label: 'SAVED',
      employeeId: employeeId,
      profile: profile,
    );
  }

  static void galleryLoaded({
    required int count,
    required List<String> employeeIds,
  }) {
    log(
      'GALLERY_LOADED',
      'count=$count ids=${employeeIds.isEmpty ? "(empty)" : employeeIds.join(", ")}',
    );
  }

  static void kioskProbeReady({
    required List<double> probe,
    required int galleryCount,
  }) {
    log(
      'KIOSK_PROBE',
      'dim=${probe.length} gallery=$galleryCount '
      'preview=${FaceMatchDebugLog.vectorPreview(probe)}',
    );
  }

  static void similarityScores({
    required List<double> probe,
    required Map<String, Map<String, dynamic>> gallery,
    bool force = false,
  }) {
    if (!kDebugMode) return;
    final now = DateTime.now();
    if (!force &&
        _lastSimilarityTraceAt != null &&
        now.difference(_lastSimilarityTraceAt!) < _similarityTraceInterval) {
      return;
    }
    _lastSimilarityTraceAt = now;
    for (final entry in gallery.entries) {
      final straight = _poseVector(entry.value, FaceProfilePoses.straight);
      if (straight == null || straight.length != probe.length) continue;
      final cosStraight = FaceEmbeddingCodec.cosineSimilarity(probe, straight);
      final anchor = FaceEmbeddingCodec.identityAnchorScore(probe, entry.value);
      log(
        'SIMILARITY',
        'employee=${entry.key} straight=${cosStraight.toStringAsFixed(4)} '
        'anchor=${anchor.toStringAsFixed(4)}',
      );
    }
  }

  static void matchVerdict({
    required bool accepted,
    required String employeeId,
    required double bestScore,
    required double margin,
    required String reason,
  }) {
    log(
      accepted ? 'MATCH_ACCEPTED' : 'MATCH_REJECTED',
      'employee=$employeeId score=${bestScore.toStringAsFixed(4)} '
      'margin=${margin.toStringAsFixed(4)} reason=$reason',
    );
  }

  /// Per-frame kiosk decision (Android stability debugging).
  static void kioskFrameDecision({
    required String bestEmployeeId,
    required double score,
    required double margin,
    required double threshold,
    required String phase,
    required String verdict,
    String reason = '',
    bool usedCachedEmbed = false,
    double? cropSharpness,
    int? confirmStreak,
    int? unknownStreak,
  }) {
    if (!kioskTraceEnabled || !Platform.isAndroid) return;
    log(
      'KIOSK_FRAME',
      'best=$bestEmployeeId score=${score.toStringAsFixed(4)} '
      'margin=${margin.toStringAsFixed(4)} thr=${threshold.toStringAsFixed(2)} '
      'phase=$phase verdict=$verdict '
      'cache=$usedCachedEmbed sharp=${cropSharpness?.toStringAsFixed(1) ?? "n/a"} '
      'confirm=${confirmStreak ?? 0} unknown=${unknownStreak ?? 0}'
      '${reason.isNotEmpty ? ' reason=$reason' : ''}',
    );
  }

  static int _templateCount(Map<String, dynamic> profile) {
    final bank = profile[FaceProfilePoses.templatesKey];
    if (bank is List) return bank.length;
    return 0;
  }

  static List<double>? _poseVector(Map<String, dynamic> profile, String pose) {
    final raw = profile[pose];
    if (raw is! List) return null;
    return raw.map((e) => (e as num).toDouble()).toList();
  }
}
