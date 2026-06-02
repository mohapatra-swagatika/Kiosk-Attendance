import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:attendance_kiosk_app/core/ml/android_enrollment_config.dart';
import 'package:attendance_kiosk_app/core/ml/face_guided_step.dart';

/// Head pose for Face ID enrollment (same gate semantics as iOS).
///
/// User-centric convention (matches on-screen arrows and iOS validation):
///   +yaw  = user turns head to their right
///   −yaw  = user turns head to their left
///   +pitch = user tilts chin up (look up)
///   −pitch = user tilts chin down (look down)
///
/// iOS uses ML Kit euler directly. Android NV21 front camera reports the same
/// yaw axis as iOS but inverts pitch (X); we flip pitch only on Android.
abstract final class FaceEnrollmentAngles {
  FaceEnrollmentAngles._();

  static ({double yaw, double pitch, String source}) fromFace(Face face) {
    final eulerY = face.headEulerAngleY;
    final eulerX = face.headEulerAngleX;

    if (!Platform.isAndroid) {
      return (
        yaw: eulerY ?? 0,
        pitch: eulerX ?? 0,
        source: 'euler_ios',
      );
    }

    if (_eulerUsable(eulerY, eulerX)) {
      return (
        yaw: eulerY!,
        pitch: -eulerX!,
        source: 'euler_android',
      );
    }

    final lm = _fromLandmarksAndroid(face);
    if (lm != null) {
      return (yaw: lm.yaw, pitch: lm.pitch, source: 'landmark_android');
    }

    return (
      yaw: eulerY ?? 0,
      pitch: eulerX != null ? -eulerX : 0,
      source: 'euler_partial',
    );
  }

  static bool _eulerUsable(double? y, double? x) =>
      y != null && x != null && !y.isNaN && !x.isNaN;

  /// Landmark fallback aligned with [euler_android] pitch/yaw signs.
  static ({double yaw, double pitch})? _fromLandmarksAndroid(Face face) {
    final le = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final re = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
    if (le == null || re == null || nose == null) return null;

    final dx = (re.x - le.x).toDouble();
    final dy = (re.y - le.y).toDouble();
    final eyeDist = math.sqrt(dx * dx + dy * dy);
    if (eyeDist < 8) return null;

    final eyeMidX = (le.x + re.x) / 2.0;
    final eyeMidY = (le.y + re.y) / 2.0;

    final yawRatio = (nose.x - eyeMidX) / eyeDist;
    final pitchRatio = (nose.y - eyeMidY) / eyeDist;

    final yaw = yawRatio * 45.0;
    final pitch = -pitchRatio * 42.0;

    return (yaw: yaw, pitch: pitch);
  }
}

/// Pose gate vs straight baseline (Android enrollment — straight step only).
final class FaceEnrollmentPoseBaseline {
  double? _yaw;
  double? _pitch;

  bool get isSet => _yaw != null && _pitch != null;

  double? get baselineYaw => _yaw;

  double? get baselinePitch => _pitch;

  void set({required double yaw, required double pitch}) {
    _yaw = yaw;
    _pitch = pitch;
  }

  void reset() {
    _yaw = null;
    _pitch = null;
  }

  /// Describe the rule used for debug logs.
  String checkStep({
    required FaceIdGuidedStep step,
    required double yaw,
    required double pitch,
    double? neutralPitch,
  }) {
    final passed = matches(
      step: step,
      yaw: yaw,
      pitch: pitch,
      neutralPitch: neutralPitch,
    );
    final rule = _ruleText(step: step, yaw: yaw, pitch: pitch, neutralPitch: neutralPitch);
    return passed ? 'PASS $rule' : 'FAIL $rule';
  }

  bool matches({
    required FaceIdGuidedStep step,
    required double yaw,
    required double pitch,
    double? neutralPitch,
  }) {
    switch (step) {
      case FaceIdGuidedStep.straight:
        final pitchDelta = neutralPitch != null ? pitch - neutralPitch : 0.0;
        return yaw.abs() <= AndroidEnrollmentConfig.straightYawAbs &&
            pitchDelta.abs() <= AndroidEnrollmentConfig.straightPitchFromNeutral;
      case FaceIdGuidedStep.left:
        if (!isSet) return yaw <= -AndroidEnrollmentConfig.sideYawMin;
        return yaw <= _yaw! - AndroidEnrollmentConfig.sideYawDelta;
      case FaceIdGuidedStep.right:
        if (!isSet) return yaw >= AndroidEnrollmentConfig.sideYawMin;
        return yaw >= _yaw! + AndroidEnrollmentConfig.sideYawDelta;
      case FaceIdGuidedStep.up:
        if (!isSet) {
          return pitch >= AndroidEnrollmentConfig.tiltPitchMin;
        }
        return pitch >= _pitch! + AndroidEnrollmentConfig.tiltPitchDelta;
      case FaceIdGuidedStep.down:
        if (!isSet) {
          return pitch <= -AndroidEnrollmentConfig.tiltPitchMin;
        }
        return pitch <= _pitch! - AndroidEnrollmentConfig.tiltPitchDelta;
      case FaceIdGuidedStep.done:
        return true;
    }
  }

  String _ruleText({
    required FaceIdGuidedStep step,
    required double yaw,
    required double pitch,
    double? neutralPitch,
  }) {
    switch (step) {
      case FaceIdGuidedStep.straight:
        final d = neutralPitch != null ? pitch - neutralPitch : 0.0;
        return 'straight |yaw|<=${AndroidEnrollmentConfig.straightYawAbs} '
            '(yaw=${yaw.toStringAsFixed(1)}) |pitchΔ|<=${AndroidEnrollmentConfig.straightPitchFromNeutral} '
            '(Δ=${d.toStringAsFixed(1)})';
      case FaceIdGuidedStep.left:
        final need = isSet
            ? _yaw! - AndroidEnrollmentConfig.sideYawDelta
            : -AndroidEnrollmentConfig.sideYawMin;
        return 'left yaw<=${need.toStringAsFixed(1)} (yaw=${yaw.toStringAsFixed(1)} '
            'base=${_yaw?.toStringAsFixed(1) ?? "n/a"})';
      case FaceIdGuidedStep.right:
        final need = isSet
            ? _yaw! + AndroidEnrollmentConfig.sideYawDelta
            : AndroidEnrollmentConfig.sideYawMin;
        return 'right yaw>=${need.toStringAsFixed(1)} (yaw=${yaw.toStringAsFixed(1)})';
      case FaceIdGuidedStep.up:
        final need = isSet
            ? _pitch! + AndroidEnrollmentConfig.tiltPitchDelta
            : AndroidEnrollmentConfig.tiltPitchMin;
        return 'up pitch>=${need.toStringAsFixed(1)} (pitch=${pitch.toStringAsFixed(1)} '
            'base=${_pitch?.toStringAsFixed(1) ?? "n/a"})';
      case FaceIdGuidedStep.down:
        final need = isSet
            ? _pitch! - AndroidEnrollmentConfig.tiltPitchDelta
            : -AndroidEnrollmentConfig.tiltPitchMin;
        return 'down pitch<=${need.toStringAsFixed(1)} (pitch=${pitch.toStringAsFixed(1)})';
      case FaceIdGuidedStep.done:
        return 'done';
    }
  }
}
