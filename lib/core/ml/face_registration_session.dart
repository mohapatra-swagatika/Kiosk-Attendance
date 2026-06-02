import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/ml/android_enrollment_config.dart';
import 'package:attendance_kiosk_app/core/ml/android_nv21_align.dart';
import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';
import 'package:attendance_kiosk_app/core/ml/face_enrollment_angles.dart';
import 'package:attendance_kiosk_app/core/ml/face_portal_frame_gate.dart';
import 'package:attendance_kiosk_app/core/ml/face_guided_step.dart';
import 'package:attendance_kiosk_app/core/ml/face_frame_analysis.dart';
import 'package:attendance_kiosk_app/core/ml/face_id_live_metrics.dart';
import 'package:attendance_kiosk_app/core/ml/face_profile_poses.dart';
import 'package:attendance_kiosk_app/core/ml/face_quality_assessor.dart';
import 'package:attendance_kiosk_app/core/ml/face_recognition_trace.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

export 'package:attendance_kiosk_app/core/ml/face_guided_step.dart';

enum FaceIdEnrollPhase {
  positioning,
  scanning,
  finished,
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
  int get positioningFramesRequired => Platform.isAndroid
      ? AndroidEnrollmentConfig.positioningFramesRequired
      : 4;

  /// Scanning is open-ended; we only auto-finish when ring is complete.
  static const Duration scanningSoftDeadline = Duration(seconds: 25);

  Duration get _scanningSoftDeadline {
    if (guided && Platform.isAndroid) {
      return const Duration(seconds: 35);
    }
    return scanningSoftDeadline;
  }

  /// Capture cadence — fast enough to feel responsive, slow enough to
  /// avoid duplicate near-identical samples (Android slightly slower for quality).
  static const int _minMsBetweenCaptureAttemptsDefault = 280;

  /// Hard cap so a fidgety user doesn't pile up dozens of samples.
  static const int _maxSamples = 16;

  double get _minStabilityScore => Platform.isAndroid
      ? AndroidEnrollmentConfig.minStabilityScore
      : 0.45;

  /// Android uses slightly fewer samples than iOS but same stability gates.
  int get _targetSamples => Platform.isAndroid ? 7 : 8;

  double get _minYawSpread => Platform.isAndroid ? 18 : 20;

  int get _stableFramesRequired => Platform.isAndroid
      ? AndroidEnrollmentConfig.stableFramesRequired
      : 2;

  double get _yawCaptureGap => Platform.isAndroid ? 3.5 : 4.0;

  double get _positionCenterMin => Platform.isAndroid
      ? AndroidEnrollmentConfig.straightCenterMin
      : 0.42;

  double get _positionDistanceMin => Platform.isAndroid
      ? AndroidEnrollmentConfig.straightDistanceMin
      : 0.38;

  int get _minMsBetweenCaptureAttempts => Platform.isAndroid
      ? AndroidEnrollmentConfig.captureIntervalMs
      : _minMsBetweenCaptureAttemptsDefault;

  FaceIdGuidedStep? _throttleStep;

  FaceIdEnrollPhase _phase = FaceIdEnrollPhase.positioning;
  DateTime _phaseStartedAt = DateTime.now();
  int _positioningFrames = 0;
  int _stableFrames = 0;
  int _lastCaptureAttemptMs = 0;
  double? _lastCapturedYaw;
  double _smoothedRing = 0;

  double? _lastYaw;
  double? _lastPitch;
  double? _lastRoll;
  String _lastAngleSource = '';
  bool _faceInPortal = true;
  double? _lastCenterX;
  double? _lastCenterY;
  double _minYawSeen = 90;
  double _maxYawSeen = -90;
  bool _sawBlink = false;
  bool _sawEyesClosed = false;

  final List<_CapturedSample> _samples = [];

  static const List<FaceIdGuidedStep> _guidedRequired = [
    FaceIdGuidedStep.straight,
    FaceIdGuidedStep.left,
    FaceIdGuidedStep.right,
    FaceIdGuidedStep.up,
    FaceIdGuidedStep.down,
  ];

  final Set<FaceIdGuidedStep> _capturedGuidedSteps = {};

  /// Android guided: pose steps the user has already passed (arrow advanced).
  final Set<FaceIdGuidedStep> _poseCompletedSteps = {};

  int _poseHoldFrames = 0;

  /// Sticky green arrow on Android — cleared only when the step changes.
  bool _androidPoseHighlight = false;

  FaceIdGuidedStep? _androidPendingCaptureStep;

  /// Landmark pitch at neutral straight (nose below eyes is normal in 2D).
  double? _androidNeutralPitch;

  final FaceEnrollmentPoseBaseline _poseBaseline = FaceEnrollmentPoseBaseline();

  /// Embeddings already captured this session (for Android align calibration).
  List<List<double>> get captureEmbeddings =>
      _samples.map((s) => s.embedding).toList(growable: false);
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

  /// True when the active guided pose is satisfied (UI highlight).
  bool get guidedPoseInTarget {
    if (!guided || _phase != FaceIdEnrollPhase.scanning) return false;
    if (Platform.isAndroid) return _androidPoseHighlight;
    final y = _lastYaw;
    final p = _lastPitch;
    if (y == null || p == null) return false;
    return _isWithinGuidedTarget(yaw: y, pitch: p);
  }

  void resetForNewEnrollment() {
    _poseBaseline.reset();
    _capturedGuidedSteps.clear();
    _poseCompletedSteps.clear();
    _poseHoldFrames = 0;
    _androidPoseHighlight = false;
    _androidPendingCaptureStep = null;
    _androidNeutralPitch = null;
    _guidedStep = FaceIdGuidedStep.straight;
    _throttleStep = null;
  }

  /// Step to embed when [processFrame] last returned true (Android guided).
  FaceIdGuidedStep? get pendingGuidedCaptureStep => _androidPendingCaptureStep;

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
      if (Platform.isAndroid && guided) {
        _poseHoldFrames = 0;
      }
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
      mirrorPreviewX: Platform.isAndroid,
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
      _androidPendingCaptureStep = null;
      _statusMessage = primaryGuidance;
      _detailMessage = guided && Platform.isAndroid && _guidedStep == FaceIdGuidedStep.done
          ? FaceRegistrationStrings.faceIdAlmostDone
          : _guidedDetailHint();
      return;
    }
    if (embedding.length != FaceEmbeddingCodec.neuralEmbeddingDim) return;

    if (!_embeddingAcceptedForCapture(embedding)) {
      _statusMessage = primaryGuidance;
      _detailMessage = FaceRegistrationStrings.faceIdHoldStillForScan;
      return;
    }

    final yaw = _lastYaw ?? 0;
    final pitch = _lastPitch ?? 0;
    _lastCapturedYaw = yaw;

    final stepAtCapture = Platform.isAndroid &&
            guided &&
            _phase == FaceIdEnrollPhase.scanning
        ? _androidPendingCaptureStep
        : (guided && _phase == FaceIdEnrollPhase.scanning ? _guidedStep : null);
    _androidPendingCaptureStep = null;

    _samples.add(
      _CapturedSample(
        yaw: yaw,
        pitch: pitch,
        embedding: embedding,
        guidedStep: stepAtCapture,
      ),
    );
    if (stepAtCapture != null) {
      _capturedGuidedSteps.add(stepAtCapture);
      if (Platform.isAndroid && stepAtCapture == FaceIdGuidedStep.straight) {
        _poseBaseline.set(yaw: yaw, pitch: pitch);
      }
    }
    _statusMessage = primaryGuidance;
    if (guided && _phase == FaceIdEnrollPhase.scanning) {
      if (!Platform.isAndroid) {
        _advanceGuidedStepAfterCapture(yaw: yaw, pitch: pitch);
      } else if (_guidedStep == FaceIdGuidedStep.done) {
        _tryFinishAndroidGuidedEnrollment();
      }
      _detailMessage = _guidedDetailHint();
    } else {
      _detailMessage = _maybeAdvanceFromCircle();
    }
  }

  void _handleNoFace(FaceFrameAnalysis analysis) {
    _liveMetrics = FaceIdLiveMetrics.empty();
    if (analysis.faceCount > 1) {
      if (kDebugMode && Platform.isAndroid) {
        FaceRecognitionTrace.enrollmentDetect(
          rawFaceCount: analysis.faceCount,
          usedFaceCount: 0,
          ignoredSpurious: 0,
          note: 'ui_multiple_faces',
        );
      }
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
        DateTime.now().difference(_phaseStartedAt) > _scanningSoftDeadline) {
      // Accept whatever we have if we collected a reasonable amount.
      if (guided) {
        if (Platform.isAndroid) {
          _tryFinishAndroidGuidedEnrollment();
        } else if (_guidedEnrollmentComplete()) {
          _completeEnrollment();
        }
        return;
      }
      const minSamples = 4;
      const minSpread = 10.0;
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
    final angles = FaceEnrollmentAngles.fromFace(face);
    final yaw = angles.yaw;
    final pitch = angles.pitch;
    final roll = face.headEulerAngleZ ?? 0;
    _lastAngleSource = angles.source;
    _lastYaw = yaw;
    _lastPitch = pitch;
    _lastRoll = roll;

    // Android: establish a neutral pitch baseline early (front camera + ML Kit can
    // report a consistent per-device pitch offset even when the user looks "straight").
    if (Platform.isAndroid &&
        guided &&
        _guidedStep == FaceIdGuidedStep.straight &&
        _androidNeutralPitch == null) {
      if (_faceFramingOk(step: FaceIdGuidedStep.straight) &&
          _liveMetrics.stabilityScore >= _minStabilityScore) {
        _androidNeutralPitch = pitch;
        if (FaceRecognitionTrace.enrollmentTraceEnabled) {
          FaceRecognitionTrace.log(
            'ENROLL_NEUTRAL',
            'neutralPitch=${pitch.toStringAsFixed(1)} src=${angles.source}',
          );
        }
      }
    }
    // The UI preview is center-cropped (BoxFit.cover) inside the portal. The ML
    // frame can include extra content outside the visible portal. For the
    // straight step we allow a larger margin so "face looks centered in circle"
    // doesn't stall on small coordinate discrepancies.
    final portalMargin = Platform.isAndroid && guided && _guidedStep == FaceIdGuidedStep.straight
        ? 1.20
        : 1.02;
    _faceInPortal = FacePortalFrameGate.faceInPortal(
      face: face,
      frameWidth: w,
      frameHeight: h,
      centerMargin: portalMargin,
    );

    final quality = _prescreenForScanning(face: face, frameWidth: w, frameHeight: h);
    if (!quality.passed) {
      _stableFrames = 0;
      _statusMessage = primaryGuidance;
      _detailMessage = quality.message?.trim().isNotEmpty == true
          ? quality.message
          : FaceRegistrationStrings.faceIdPositionFace;
      _logEnrollmentPose(
        faceCount: 1,
        yaw: yaw,
        pitch: pitch,
        roll: roll,
        inTarget: false,
        queued: false,
        detail:
            'reject=prescreen ${quality.message ?? quality.issue.name} | '
            '${_poseBaseline.checkStep(step: _guidedStep, yaw: yaw, pitch: pitch, neutralPitch: _androidNeutralPitch)}',
        angleSource: angles.source,
      );
      return false;
    }

    if (_liveMetrics.stabilityScore >= _minStabilityScore) {
      _stableFrames++;
    } else {
      _stableFrames = math.max(0, _stableFrames - 1);
    }
    _minYawSeen = math.min(_minYawSeen, yaw);
    _maxYawSeen = math.max(_maxYawSeen, yaw);

    if (_samples.length >= _maxSamples) {
      if (_circleRequirementsMet()) _completeEnrollment();
      return false;
    }

    if (!guided || !Platform.isAndroid) {
      final advance = _maybeAdvanceFromCircle();
      if (advance != null) {
        _detailMessage = advance;
        return false;
      }
    }

    final androidInstantGuided = Platform.isAndroid && guided;

    if (_captureInFlight && !androidInstantGuided) {
      _statusMessage = primaryGuidance;
      _detailMessage = FaceRegistrationStrings.faceIdCapturingSample;
      return false;
    }

    if (!androidInstantGuided && _stableFrames < _stableFramesRequired) {
      _statusMessage = primaryGuidance;
      _detailMessage = FaceRegistrationStrings.faceIdHoldStillForScan;
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!androidInstantGuided) {
      final stepChanged = _throttleStep != _guidedStep;
      if (stepChanged) {
        _throttleStep = _guidedStep;
      } else if (now - _lastCaptureAttemptMs < _minMsBetweenCaptureAttempts) {
        _statusMessage = primaryGuidance;
        _detailMessage = guided ? _guidedDetailHint() : _scanningDetailHint();
        return false;
      }
    }

    if (guided) {
      if (androidInstantGuided) {
        _updateAndroidPoseHold(yaw: yaw, pitch: pitch);
      }

      if (_guidedStep == FaceIdGuidedStep.done) {
        if (androidInstantGuided) {
          if (_tryFinishAndroidGuidedEnrollment()) return false;
          return _tryQueueAndroidEmbedRetry();
        }
        if (_guidedEnrollmentComplete()) {
          _completeEnrollment();
        }
        return false;
      }

      if (androidInstantGuided) {
        if (_tryQueueAndroidGuidedCapture(yaw: yaw, pitch: pitch)) {
          return true;
        }
        _statusMessage = primaryGuidance;
        _detailMessage = _guidedDetailHint();
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

  FaceQualityResult _prescreenForScanning({
    required Face face,
    required int frameWidth,
    required int frameHeight,
  }) {
    if (Platform.isAndroid && guided) {
      if (_guidedStep == FaceIdGuidedStep.straight) {
        return FaceQualityAssessor.preScreenEnrollment(
          face: face,
          frameWidth: frameWidth,
          frameHeight: frameHeight,
        );
      }
      return FaceQualityAssessor.preScreenGuidedPoseStep(
        face: face,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
      );
    }
    return FaceQualityAssessor.preScreenEnrollment(
      face: face,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
    );
  }

  bool _faceFramingOk({FaceIdGuidedStep? step}) {
    if (!_faceInPortal) return false;
    if (Platform.isAndroid) {
      final straight = step == null || step == FaceIdGuidedStep.straight;
      final centerMin = straight
          ? AndroidEnrollmentConfig.straightCenterMin
          : AndroidEnrollmentConfig.poseCenterMin;
      final distMin = straight
          ? AndroidEnrollmentConfig.straightDistanceMin
          : AndroidEnrollmentConfig.poseDistanceMin;
      return _liveMetrics.centerScore >= centerMin &&
          _liveMetrics.distanceScore >= distMin;
    }
    return _liveMetrics.centerScore >= 0.42 &&
        _liveMetrics.distanceScore >= 0.35;
  }

  bool _isWithinGuidedTarget({required double yaw, required double pitch}) {
    if (!_faceFramingOk(step: _guidedStep)) return false;

    if (Platform.isAndroid && guided) {
      return _poseBaseline.matches(
        step: _guidedStep,
        yaw: yaw,
        pitch: pitch,
        neutralPitch: _androidNeutralPitch,
      );
    }

    switch (_guidedStep) {
      case FaceIdGuidedStep.straight:
        return yaw.abs() <= 7 && pitch.abs() <= 7;
      case FaceIdGuidedStep.left:
        return yaw <= -12;
      case FaceIdGuidedStep.right:
        return yaw >= 12;
      case FaceIdGuidedStep.up:
        return pitch >= 10;
      case FaceIdGuidedStep.down:
        return pitch <= -10;
      case FaceIdGuidedStep.done:
        return true;
    }
  }

  void _updateAndroidPoseHold({required double yaw, required double pitch}) {
    if (_poseCompletedSteps.contains(_guidedStep)) {
      return;
    }
    if (_isWithinGuidedTarget(yaw: yaw, pitch: pitch)) {
      _poseHoldFrames++;
      final need = _guidedStep == FaceIdGuidedStep.straight ? 1 : AndroidEnrollmentConfig.poseHoldFramesRequired;
      if (_poseHoldFrames >= need) {
        _androidPoseHighlight = true;
      }
    } else {
      _poseHoldFrames = 0;
    }
  }

  bool _androidPoseReadyToAdvance() {
    final need = _guidedStep == FaceIdGuidedStep.straight ? 1 : AndroidEnrollmentConfig.poseHoldFramesRequired;
    return _poseHoldFrames >= need;
  }

  bool _tryFinishAndroidGuidedEnrollment() {
    if (_poseCompletedSteps.length < _guidedRequired.length) return false;
    if (_guidedEnrollmentComplete()) {
      _completeEnrollment();
      return true;
    }
    if (_capturedGuidedSteps.contains(FaceIdGuidedStep.straight) &&
        _samples.length >= 3 &&
        !_captureInFlight) {
      _completeEnrollment();
      return true;
    }
    return false;
  }

  bool _tryQueueAndroidEmbedRetry() {
    if (_captureInFlight) return false;
    for (final step in _guidedRequired) {
      if (_capturedGuidedSteps.contains(step)) continue;
      _androidPendingCaptureStep = step;
      _statusMessage = primaryGuidance;
      _detailMessage = FaceRegistrationStrings.faceIdAlmostDone;
      return true;
    }
    _tryFinishAndroidGuidedEnrollment();
    return false;
  }

  /// Android: pose matched → advance arrow now, embed this step in background.
  bool _tryQueueAndroidGuidedCapture({
    required double yaw,
    required double pitch,
  }) {
    final roll = _lastRoll ?? 0;
    final step = _guidedStep;
    if (step == FaceIdGuidedStep.done) return false;
    if (_poseCompletedSteps.contains(step)) {
      _logEnrollmentPose(
        faceCount: 1,
        yaw: yaw,
        pitch: pitch,
        roll: roll,
        inTarget: true,
        queued: false,
        detail: 'reject=step_already_done',
      );
      return false;
    }
    if (!_androidPoseReadyToAdvance()) {
      _logEnrollmentPose(
        faceCount: 1,
        yaw: yaw,
        pitch: pitch,
        roll: roll,
        inTarget: false,
        queued: false,
        detail: _poseRejectDetail(yaw: yaw, pitch: pitch),
        angleSource: _lastAngleSource,
      );
      return false;
    }

    _poseCompletedSteps.add(step);
    _androidPendingCaptureStep = step;
    if (step == FaceIdGuidedStep.straight && !_poseBaseline.isSet) {
      _poseBaseline.set(yaw: yaw, pitch: pitch);
    }
    final from = step.name;
    _advanceGuidedStepImmediate();
    if (FaceRecognitionTrace.enrollmentTraceEnabled) {
      FaceRecognitionTrace.enrollmentStepAdvanced(
        fromStep: from,
        toStep: _guidedStep.name,
        yaw: yaw,
        pitch: pitch,
      );
    }
    _logEnrollmentPose(
      faceCount: 1,
      yaw: yaw,
      pitch: pitch,
      roll: roll,
      inTarget: true,
      queued: true,
      detail: _poseBaseline.checkStep(
        step: step,
        yaw: yaw,
        pitch: pitch,
        neutralPitch: _androidNeutralPitch,
      ),
      angleSource: _lastAngleSource,
    );
    _statusMessage = primaryGuidance;
    _detailMessage = _guidedDetailHint();
    return true;
  }

  String _poseRejectDetail({required double yaw, required double pitch}) {
    if (_poseHoldFrames > 0 &&
        _poseHoldFrames < AndroidEnrollmentConfig.poseHoldFramesRequired) {
      return 'reject=pose_hold $_poseHoldFrames/${AndroidEnrollmentConfig.poseHoldFramesRequired}';
    }
    if (!_faceInPortal) {
      return 'reject=portal outside_circle';
    }
    if (!_faceFramingOk(step: _guidedStep)) {
      return 'reject=framing center=${_liveMetrics.centerScore.toStringAsFixed(2)} '
          'dist=${_liveMetrics.distanceScore.toStringAsFixed(2)}';
    }
    return 'reject=pose src=$_lastAngleSource '
        '${_poseBaseline.checkStep(step: _guidedStep, yaw: yaw, pitch: pitch, neutralPitch: _androidNeutralPitch)}';
  }

  void _logEnrollmentPose({
    required int faceCount,
    required double yaw,
    required double pitch,
    required double roll,
    required bool inTarget,
    required bool queued,
    required String detail,
    String angleSource = '',
  }) {
    if (!FaceRecognitionTrace.enrollmentTraceEnabled || !Platform.isAndroid) {
      return;
    }
    final neutral = _androidNeutralPitch;
    FaceRecognitionTrace.enrollmentPose(
      step: _guidedStep.name,
      faceCount: faceCount,
      yaw: yaw,
      pitch: pitch,
      roll: roll,
      center: _liveMetrics.centerScore,
      distance: _liveMetrics.distanceScore,
      stability: _liveMetrics.stabilityScore,
      framingOk: _faceFramingOk(step: _guidedStep),
      inTarget: inTarget,
      stepQueued: queued,
      detail: detail,
      neutralPitch: neutral,
      pitchDelta: neutral != null ? pitch - neutral : null,
      angleSource: angleSource,
      baselineYaw: _poseBaseline.baselineYaw,
      baselinePitch: _poseBaseline.baselinePitch,
    );
  }

  bool _shouldAttemptGuidedCapture({required double yaw, required double pitch}) {
    if (_stableFrames < _stableFramesRequired) return false;
    if (!_isWithinGuidedTarget(yaw: yaw, pitch: pitch)) return false;
    if (_capturedGuidedSteps.contains(_guidedStep)) return false;
    return true;
  }

  bool _guidedEnrollmentComplete() =>
      _guidedRequired.every(_capturedGuidedSteps.contains);

  void _advanceGuidedStepAfterCapture({required double yaw, required double pitch}) {
    if (!_isWithinGuidedTarget(yaw: yaw, pitch: pitch)) return;
    _advanceGuidedStepImmediate();
  }

  void _advanceGuidedStepImmediate() {
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
    _poseHoldFrames = 0;
    _androidPoseHighlight = false;
    _lastCapturedYaw = null;
    _throttleStep = null;
  }

  String _guidedDetailHint() {
    final yaw = _lastYaw ?? 0;
    final pitch = _lastPitch ?? 0;
    if (!_isWithinGuidedTarget(yaw: yaw, pitch: pitch)) {
      return _guidedPoseNudge();
    }
    switch (_guidedStep) {
      case FaceIdGuidedStep.straight:
        return FaceRegistrationStrings.faceIdHoldStillForScan;
      case FaceIdGuidedStep.left:
      case FaceIdGuidedStep.right:
      case FaceIdGuidedStep.up:
      case FaceIdGuidedStep.down:
        return FaceRegistrationStrings.faceIdCapturingSample;
      case FaceIdGuidedStep.done:
        return FaceRegistrationStrings.faceIdAlmostDone;
    }
  }

  String _guidedPoseNudge() {
    switch (_guidedStep) {
      case FaceIdGuidedStep.straight:
        return FaceRegistrationStrings.faceIdPositionFace;
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
          if (Platform.isAndroid) {
            return (0.10 + stepProgress * 0.90).clamp(0.10, 0.99);
          }
          final y = _lastYaw ?? 0;
          final p = _lastPitch ?? 0;
          final inTarget =
              _isWithinGuidedTarget(yaw: y, pitch: p) ? 0.05 : 0.0;
          return (0.10 + stepProgress * 0.88 + inTarget).clamp(0.10, 0.99);
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
    final step = Platform.isAndroid ? 0.28 : 0.14;
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

  bool _embeddingAcceptedForCapture(List<double> embedding) {
    final existing = _samples.map((s) => s.embedding).toList();
    if (existing.isEmpty) return true;

    final step =
        guided && _phase == FaceIdEnrollPhase.scanning ? _guidedStep : null;
    if (Platform.isAndroid && guided && step != null) {
      return true;
    }

    return FaceEmbeddingCodec.isEnrollmentSampleConsistent(
      candidate: embedding,
      existing: existing,
    );
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
      switch (s.guidedStep) {
        case FaceIdGuidedStep.straight:
          straight.add(s.embedding);
        case FaceIdGuidedStep.left:
          left.add(s.embedding);
        case FaceIdGuidedStep.right:
          right.add(s.embedding);
        case FaceIdGuidedStep.up:
          up.add(s.embedding);
        case FaceIdGuidedStep.down:
          down.add(s.embedding);
        case FaceIdGuidedStep.done:
        case null:
          if (s.yaw < -7) {
            left.add(s.embedding);
          } else if (s.yaw > 7) {
            right.add(s.embedding);
          } else {
            straight.add(s.embedding);
          }
          if (s.pitch > 7) {
            up.add(s.embedding);
          } else if (s.pitch < -7) {
            down.add(s.embedding);
          }
      }
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
      kAndroidNv21AlignProfileKey: AndroidNv21AlignCalibrator.enrollmentLockedIndex,
    };
  }
}

class _CapturedSample {
  _CapturedSample({
    required this.yaw,
    required this.pitch,
    required this.embedding,
    this.guidedStep,
  });
  final double yaw;
  final double pitch;
  final List<double> embedding;
  final FaceIdGuidedStep? guidedStep;
}
