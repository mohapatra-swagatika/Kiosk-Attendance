import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';
import 'package:attendance_kiosk_app/core/ml/face_frame_analysis.dart';
import 'package:attendance_kiosk_app/core/ml/face_id_live_metrics.dart';
import 'package:attendance_kiosk_app/core/ml/face_profile_poses.dart';
import 'package:attendance_kiosk_app/core/ml/face_quality_assessor.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum FaceIdEnrollPhase {
  positioning,
  scanning,
  finished,
}

enum FaceIdGuidedStep {
  straight,
  left,
  right,
  up,
  down,
  done,
}

/// Smooth, automatic Face ID enrollment.
///
/// Design notes:
///   * No explicit "turn left / turn right / blink" steps — the session
///     captures samples opportunistically whenever the user moves their head
///     a little.
///   * Targets ~8 distinct samples across a wide enough yaw range.
///   * Stops as soon as the ring is full; never traps the user in a phase.
class FaceRegistrationSession {
  FaceRegistrationSession({this.guided = true});

  /// When true, uses an explicit Face ID-like step flow:
  /// 1) Capture a straight sample
  /// 2) Guide left, right, up, down
  /// While still using the same capture + payload logic.
  final bool guided;

  /// Frames the face must be centered + at a sane distance before scanning.
  static const int positioningFramesRequired = 4;

  /// Scanning is open-ended; we only auto-finish when ring is complete.
  static const Duration scanningSoftDeadline = Duration(seconds: 25);

  /// Capture cadence — fast enough to feel responsive, slow enough to
  /// avoid duplicate near-identical samples.
  static const int _minMsBetweenCaptureAttempts = 280;

  /// Hard cap so a fidgety user doesn't pile up dozens of samples.
  static const int _maxSamples = 16;

  static const double _minStabilityScore = 0.45;

  /// iOS keeps original enrollment pacing; Android is slightly faster/looser.
  int get _targetSamples => Platform.isAndroid ? 6 : 8;

  double get _minYawSpread => Platform.isAndroid ? 14 : 20;

  int get _stableFramesRequired => Platform.isAndroid ? 1 : 2;

  double get _yawCaptureGap => Platform.isAndroid ? 3.0 : 4.0;

  double get _positionCenterMin => Platform.isAndroid ? 0.38 : 0.42;

  double get _positionDistanceMin => Platform.isAndroid ? 0.32 : 0.38;

  FaceIdEnrollPhase _phase = FaceIdEnrollPhase.positioning;
  DateTime _phaseStartedAt = DateTime.now();
  int _positioningFrames = 0;
  int _stableFrames = 0;
  int _lastCaptureAttemptMs = 0;
  double? _lastCapturedYaw;
  double _smoothedRing = 0;

  double? _lastYaw;
  double? _lastPitch;
  double? _lastCenterX;
  double? _lastCenterY;
  double _minYawSeen = 90;
  double _maxYawSeen = -90;
  bool _sawBlink = false;
  bool _sawEyesClosed = false;

  final List<_CapturedSample> _samples = [];
  FaceIdGuidedStep _guidedStep = FaceIdGuidedStep.straight;
  bool _locked = false;
  bool _captureInFlight = false;
  bool _completed = false;

  String? _statusMessage;
  String? _detailMessage;
  FaceIdLiveMetrics _liveMetrics = FaceIdLiveMetrics.empty();

  FaceIdEnrollPhase get phase => _phase;
  FaceIdGuidedStep get guidedStep => guided ? _guidedStep : FaceIdGuidedStep.done;
  bool get isLocked => _locked;
  bool get isPositioningPhase => _phase == FaceIdEnrollPhase.positioning;
  FaceIdLiveMetrics get liveMetrics => _liveMetrics;
  String? get statusMessage => _statusMessage;
  String? get detailMessage => _detailMessage;
  double get faceIdRingProgress => _smoothedRing;

  bool get hasStraightSample {
    for (final s in _samples) {
      if (s.yaw.abs() <= 7 && s.pitch.abs() <= 7) return true;
    }
    return false;
  }

  void tickAnimation() {
    if (_locked) return;
    _tickPhaseTimeouts();
    _tickRingSmoothing();
  }

  String get primaryGuidance {
    switch (_phase) {
      case FaceIdEnrollPhase.positioning:
        return FaceRegistrationStrings.faceIdPositionFace;
      case FaceIdEnrollPhase.scanning:
        if (!guided) return FaceRegistrationStrings.faceIdCompleteCircle;
        switch (_guidedStep) {
          case FaceIdGuidedStep.straight:
            return 'Look straight';
          case FaceIdGuidedStep.left:
            return FaceRegistrationStrings.faceIdTurnLeft;
          case FaceIdGuidedStep.right:
            return FaceRegistrationStrings.faceIdTurnRight;
          case FaceIdGuidedStep.up:
            return FaceRegistrationStrings.faceIdTiltUp;
          case FaceIdGuidedStep.down:
            return FaceRegistrationStrings.faceIdTiltDown;
          case FaceIdGuidedStep.done:
            return FaceRegistrationStrings.faceIdAlmostDone;
        }
      case FaceIdEnrollPhase.finished:
        return FaceRegistrationStrings.faceIdComplete;
    }
  }

  bool processFrame(
    FaceFrameAnalysis analysis, {
    double? smoothedCenterX,
    double? smoothedCenterY,
  }) {
    if (_locked || _phase == FaceIdEnrollPhase.finished) return false;

    _tickPhaseTimeouts();

    if (!analysis.hasSingleFace) {
      _stableFrames = 0;
      _handleNoFace(analysis);
      _tickRingSmoothing();
      return false;
    }

    final face = analysis.face!;
    final w = analysis.imageWidth;
    final h = analysis.imageHeight;

    _liveMetrics = FaceIdLiveMetrics.fromAnalysis(
      analysis,
      lastCenterX: _lastCenterX,
      lastCenterY: _lastCenterY,
      smoothedCenterX: smoothedCenterX,
      smoothedCenterY: smoothedCenterY,
    );

    final box = face.boundingBox;
    _lastCenterX = smoothedCenterX ?? box.center.dx;
    _lastCenterY = smoothedCenterY ?? box.center.dy;

    _trackBlink(face);

    switch (_phase) {
      case FaceIdEnrollPhase.positioning:
        _processPositioning();
        _tickRingSmoothing();
        return false;
      case FaceIdEnrollPhase.scanning:
        final request = _processScanning(face, w, h);
        _tickRingSmoothing();
        return request;
      case FaceIdEnrollPhase.finished:
        return false;
    }
  }

  void markCaptureStarted() {
    _captureInFlight = true;
  }

  void markCaptureFinished({required bool success, List<double>? embedding}) {
    _captureInFlight = false;
    _lastCaptureAttemptMs = DateTime.now().millisecondsSinceEpoch;

    if (!success || embedding == null) {
      _statusMessage = primaryGuidance;
      _detailMessage = _scanningDetailHint();
      return;
    }
    if (embedding.length != FaceEmbeddingCodec.neuralEmbeddingDim) return;

    final existing = _samples.map((s) => s.embedding).toList();
    if (!FaceEmbeddingCodec.isEnrollmentSampleConsistent(
      candidate: embedding,
      existing: existing,
    )) {
      _statusMessage = primaryGuidance;
      _detailMessage = FaceRegistrationStrings.faceIdHoldStillForScan;
      return;
    }

    final yaw = _lastYaw ?? 0;
    final pitch = _lastPitch ?? 0;
    _lastCapturedYaw = yaw;

    _samples.add(_CapturedSample(yaw: yaw, pitch: pitch, embedding: embedding));
    _statusMessage = primaryGuidance;
    if (guided && _phase == FaceIdEnrollPhase.scanning) {
      _advanceGuidedStepAfterCapture(yaw: yaw, pitch: pitch);
      _detailMessage = _guidedDetailHint();
    } else {
      _detailMessage = _maybeAdvanceFromCircle();
    }
  }

  void _handleNoFace(FaceFrameAnalysis analysis) {
    _liveMetrics = FaceIdLiveMetrics.empty();
    if (analysis.faceCount > 1) {
      _statusMessage = FaceRegistrationStrings.faceIdSingleFace;
      _detailMessage = null;
      return;
    }
    if (_phase == FaceIdEnrollPhase.positioning) {
      _positioningFrames = 0;
    }
    _statusMessage = primaryGuidance;
    _detailMessage = _phase == FaceIdEnrollPhase.scanning
        ? _scanningDetailHint()
        : null;
  }

  void _tickPhaseTimeouts() {
    if (_phase == FaceIdEnrollPhase.scanning &&
        DateTime.now().difference(_phaseStartedAt) > scanningSoftDeadline) {
      // Accept whatever we have if we collected a reasonable amount.
      final minSamples = Platform.isAndroid ? 3 : 4;
      final minSpread = Platform.isAndroid ? 8.0 : 10.0;
      if (_samples.length >= minSamples && (_maxYawSeen - _minYawSeen) >= minSpread) {
        _completeEnrollment();
      }
    }
  }

  bool _processPositioning() {
    if (_liveMetrics.hasFace &&
        _liveMetrics.centerScore >= _positionCenterMin &&
        _liveMetrics.distanceScore >= _positionDistanceMin) {
      _positioningFrames++;
      if (_positioningFrames >= positioningFramesRequired) {
        _phase = FaceIdEnrollPhase.scanning;
        _phaseStartedAt = DateTime.now();
        _statusMessage = FaceRegistrationStrings.faceIdFaceDetected;
        _detailMessage = FaceRegistrationStrings.faceIdSlowScanHint;
      } else {
        _statusMessage = _liveMetrics.guidance;
        _detailMessage = FaceRegistrationStrings.faceIdPositionFace;
      }
    } else {
      _positioningFrames = 0;
      _statusMessage = _liveMetrics.guidance;
      _detailMessage = FaceRegistrationStrings.faceIdPositionFace;
    }
    return false;
  }

  bool _processScanning(Face face, int w, int h) {
    final quality = FaceQualityAssessor.preScreenEnrollment(
      face: face,
      frameWidth: w,
      frameHeight: h,
    );
    if (!quality.passed) {
      _stableFrames = 0;
      _statusMessage = primaryGuidance;
      _detailMessage = quality.message;
      return false;
    }

    if (_liveMetrics.stabilityScore >= _minStabilityScore) {
      _stableFrames++;
    } else {
      _stableFrames = math.max(0, _stableFrames - 1);
    }

    final yaw = quality.yaw ?? face.headEulerAngleY ?? 0;
    final pitch = quality.pitch ?? face.headEulerAngleX ?? 0;
    _lastYaw = yaw;
    _lastPitch = pitch;
    _minYawSeen = math.min(_minYawSeen, yaw);
    _maxYawSeen = math.max(_maxYawSeen, yaw);

    if (_samples.length >= _maxSamples) {
      if (_circleRequirementsMet()) _completeEnrollment();
      return false;
    }

    final advance = _maybeAdvanceFromCircle();
    if (advance != null) {
      _detailMessage = advance;
      return false;
    }

    if (_captureInFlight) {
      _statusMessage = primaryGuidance;
      _detailMessage = FaceRegistrationStrings.faceIdCapturingSample;
      return false;
    }

    if (_stableFrames < _stableFramesRequired) {
      _statusMessage = primaryGuidance;
      _detailMessage = FaceRegistrationStrings.faceIdHoldStillForScan;
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastCaptureAttemptMs < _minMsBetweenCaptureAttempts) {
      _statusMessage = primaryGuidance;
      _detailMessage = guided ? _guidedDetailHint() : _scanningDetailHint();
      return false;
    }

    if (guided) {
      if (_guidedStep == FaceIdGuidedStep.done) {
        _completeEnrollment();
        return false;
      }
      if (_shouldAttemptGuidedCapture(yaw: yaw, pitch: pitch)) {
        _statusMessage = primaryGuidance;
        _detailMessage = FaceRegistrationStrings.faceIdCapturingSample;
        return true;
      }
      _statusMessage = primaryGuidance;
      _detailMessage = _guidedDetailHint();
      return false;
    }

    if (_shouldAttemptCapture(yaw)) {
      _statusMessage = primaryGuidance;
      _detailMessage = FaceRegistrationStrings.faceIdCapturingSample;
      return true;
    }

    _statusMessage = primaryGuidance;
    _detailMessage = _scanningDetailHint();
    return false;
  }

  bool _isWithinGuidedTarget({required double yaw, required double pitch}) {
    switch (_guidedStep) {
      case FaceIdGuidedStep.straight:
        return yaw.abs() <= 7 && pitch.abs() <= 7;
      case FaceIdGuidedStep.left:
        return yaw <= -12;
      case FaceIdGuidedStep.right:
        return yaw >= 12;
      case FaceIdGuidedStep.up:
        // ML Kit headEulerAngleX is positive when the face tilts UP on iOS.
        // (Empirically: users reported "Look Up" never triggers unless sign is flipped.)
        return pitch >= 10;
      case FaceIdGuidedStep.down:
        return pitch <= -10;
      case FaceIdGuidedStep.done:
        return true;
    }
  }

  bool _shouldAttemptGuidedCapture({required double yaw, required double pitch}) {
    // Require stability and a step-specific angle target before capturing.
    if (_stableFrames < _stableFramesRequired) return false;
    if (!_isWithinGuidedTarget(yaw: yaw, pitch: pitch)) return false;

    // Avoid recapturing the same step with near-identical angles.
    final last = _lastCapturedYaw;
    if (last != null && (yaw - last).abs() < 2.0 && _guidedStep != FaceIdGuidedStep.up && _guidedStep != FaceIdGuidedStep.down) {
      return false;
    }
    return true;
  }

  void _advanceGuidedStepAfterCapture({required double yaw, required double pitch}) {
    if (!_isWithinGuidedTarget(yaw: yaw, pitch: pitch)) return;

    switch (_guidedStep) {
      case FaceIdGuidedStep.straight:
        _guidedStep = FaceIdGuidedStep.left;
      case FaceIdGuidedStep.left:
        _guidedStep = FaceIdGuidedStep.right;
      case FaceIdGuidedStep.right:
        _guidedStep = FaceIdGuidedStep.up;
      case FaceIdGuidedStep.up:
        _guidedStep = FaceIdGuidedStep.down;
      case FaceIdGuidedStep.down:
        _guidedStep = FaceIdGuidedStep.done;
      case FaceIdGuidedStep.done:
        break;
    }
  }

  String _guidedDetailHint() {
    switch (_guidedStep) {
      case FaceIdGuidedStep.straight:
        return FaceRegistrationStrings.faceIdPositionFace;
      case FaceIdGuidedStep.left:
      case FaceIdGuidedStep.right:
      case FaceIdGuidedStep.up:
      case FaceIdGuidedStep.down:
        return FaceRegistrationStrings.faceIdSlowScanHint;
      case FaceIdGuidedStep.done:
        return FaceRegistrationStrings.faceIdAlmostDone;
    }
  }

  bool _shouldAttemptCapture(double yaw) {
    if (_samples.isEmpty) return true;
    if (_lastCapturedYaw == null) return true;
    // Only capture if the head moved meaningfully since the last sample.
    return (yaw - _lastCapturedYaw!).abs() >= _yawCaptureGap;
  }

  String _scanningDetailHint() {
    final spread = _maxYawSeen - _minYawSeen;
    if (_samples.length < 3) {
      return FaceRegistrationStrings.faceIdSlowScanHint;
    }
    if (spread < _minYawSpread) {
      return FaceRegistrationStrings.faceIdSlowScanHint;
    }
    if (_samples.length < _targetSamples) {
      return FaceRegistrationStrings.faceIdMoreAnglesNeeded;
    }
    return FaceRegistrationStrings.faceIdAlmostDone;
  }

  bool _circleRequirementsMet() {
    final spread = _maxYawSeen - _minYawSeen;
    return _samples.length >= _targetSamples && spread >= _minYawSpread;
  }

  double _rawRingTarget() {
    switch (_phase) {
      case FaceIdEnrollPhase.positioning:
        return (_positioningFrames / positioningFramesRequired * 0.10)
            .clamp(0.0, 0.10);
      case FaceIdEnrollPhase.scanning:
        if (guided) {
          final stepProgress = switch (_guidedStep) {
            FaceIdGuidedStep.straight => 0.0,
            FaceIdGuidedStep.left => 0.20,
            FaceIdGuidedStep.right => 0.40,
            FaceIdGuidedStep.up => 0.60,
            FaceIdGuidedStep.down => 0.80,
            FaceIdGuidedStep.done => 1.0,
          };
          return (0.10 + stepProgress * 0.88).clamp(0.10, 0.99);
        }

        final sampleRatio = (_samples.length / _targetSamples).clamp(0.0, 1.0);
        final spread = (_maxYawSeen - _minYawSeen).clamp(0.0, 40.0) / 40.0;
        final stabilityBonus =
            (_stableFrames / _stableFramesRequired * 0.06).clamp(0.0, 0.06);
        final blinkBonus = _sawBlink ? 0.04 : 0.0;
        // Sample collection drives 70% of the ring, yaw spread 18%, plus small bonuses.
        return (0.10 +
                sampleRatio * 0.70 +
                spread * 0.18 +
                stabilityBonus +
                blinkBonus)
            .clamp(0.10, 0.99);
      case FaceIdEnrollPhase.finished:
        return 1.0;
    }
  }

  void _tickRingSmoothing() {
    final target = _rawRingTarget();
    final delta = target - _smoothedRing;
    final step = Platform.isAndroid ? 0.22 : 0.14;
    if (delta > 0) {
      _smoothedRing += delta * step + 0.003;
      if (_smoothedRing > target) _smoothedRing = target;
    } else if (delta < -0.02) {
      _smoothedRing = target;
    }
    _smoothedRing = _smoothedRing.clamp(0.0, 1.0);
  }

  String? _maybeAdvanceFromCircle() {
    if (!_circleRequirementsMet()) return null;
    _completeEnrollment();
    return FaceRegistrationStrings.faceIdAlmostDone;
  }

  void _trackBlink(Face face) {
    final le = face.leftEyeOpenProbability;
    final re = face.rightEyeOpenProbability;
    if (le == null || re == null) return;
    final avg = (le + re) / 2;
    if (!_sawEyesClosed && avg < 0.38) _sawEyesClosed = true;
    if (_sawEyesClosed && avg > 0.55) _sawBlink = true;
  }

  void _completeEnrollment() {
    if (_completed) return;
    _completed = true;
    _phase = FaceIdEnrollPhase.finished;
    _phaseStartedAt = DateTime.now();
    _locked = true;
    _smoothedRing = 1.0;
    _statusMessage = FaceRegistrationStrings.faceIdComplete;
    _detailMessage = FaceRegistrationStrings.saving;
  }

  Map<String, dynamic>? buildProfilePayload() {
    if (!_completed || !_locked || _samples.isEmpty) return null;

    final straight = <List<double>>[];
    final left = <List<double>>[];
    final right = <List<double>>[];
    final up = <List<double>>[];
    final down = <List<double>>[];

    for (final s in _samples) {
      if (s.yaw < -7) {
        left.add(s.embedding);
      } else if (s.yaw > 7) {
        right.add(s.embedding);
      } else {
        straight.add(s.embedding);
      }
      if (s.pitch < -7) up.add(s.embedding);
      if (s.pitch > 7) down.add(s.embedding);
    }

    if (straight.isEmpty && left.isNotEmpty) {
      straight.add(left.first);
    }
    if (straight.isEmpty && right.isNotEmpty) {
      straight.add(right.first);
    }
    if (straight.isEmpty) return null;

    final straightAvg = FaceEmbeddingCodec.combinePoseVectorsRobust(straight);
    final leftAvg = left.isNotEmpty
        ? FaceEmbeddingCodec.combinePoseVectorsRobust(left)
        : straightAvg;
    final rightAvg = right.isNotEmpty
        ? FaceEmbeddingCodec.combinePoseVectorsRobust(right)
        : straightAvg;
    final upAvg = up.isNotEmpty
        ? FaceEmbeddingCodec.combinePoseVectorsRobust(up)
        : straightAvg;
    final downAvg = down.isNotEmpty
        ? FaceEmbeddingCodec.combinePoseVectorsRobust(down)
        : straightAvg;
    final combined = FaceEmbeddingCodec.combinePoseVectorsRobust([
      straightAvg,
      leftAvg,
      rightAvg,
      upAvg,
      downAvg,
    ]);
    final templateCandidates = <List<double>>[
      straightAvg,
      leftAvg,
      rightAvg,
      upAvg,
      downAvg,
      combined,
      ..._samples.map((s) => s.embedding),
    ];
    final diverseBank = FaceEmbeddingCodec.pickDiverseEnrollmentTemplates(
      templateCandidates,
      maxCount: 14,
    );

    return {
      'v': FaceEmbeddingCodec.storageVersionTflite,
      FaceProfilePoses.combined: combined,
      FaceProfilePoses.straight: straightAvg,
      FaceProfilePoses.left: leftAvg,
      FaceProfilePoses.right: rightAvg,
      FaceProfilePoses.up: upAvg,
      FaceProfilePoses.down: downAvg,
      FaceProfilePoses.templatesKey: diverseBank,
      'enrollmentMode': 'faceIdSmooth',
      'samples': _samples.length,
      'yawSpread': _maxYawSeen - _minYawSeen,
      'sawBlink': _sawBlink,
    };
  }
}

class _CapturedSample {
  _CapturedSample({
    required this.yaw,
    required this.pitch,
    required this.embedding,
  });
  final double yaw;
  final double pitch;
  final List<double> embedding;
}
