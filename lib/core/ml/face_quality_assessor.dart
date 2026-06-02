import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:attendance_kiosk_app/core/ml/face_enrollment_angles.dart';
import 'package:attendance_kiosk_app/core/ml/face_portal_frame_gate.dart';
import 'package:image/image.dart' as img;

/// Production-grade frame quality gate for face recognition.
///
/// Rejects frames that would produce low-quality embeddings: too small,
/// off-center, blurry, dark/over-exposed, eyes closed, or extreme pose.
class FaceQualityAssessor {
  FaceQualityAssessor._();

  static const double minVisibilityRatio = 0.15;
  static const double maxOffCenterRatio = 0.18;

  /// Kiosk live path — permissive so registered users unlock easily.
  static const double kioskMinVisibilityRatio = 0.08;
  static const double kioskMaxOffCenterRatio = 0.26;
  static const double kioskMinEyeOpen = 0.22;
  static const double kioskMaxYawAbs = 40;
  static const double kioskMaxPitchAbs = 34;
  static const double kioskMaxRollAbs = 20;

  static const double minEyeOpenForRecognition = 0.45;
  static const double maxYawAbs = 18;
  static const double maxPitchAbs = 15;
  static const double maxRollAbs = 12;
  static const double minBrightness = 55;
  static const double maxBrightness = 215;
  static const double minSharpness = 25;

  /// Cheap pre-checks using only ML Kit data. Run on every frame.
  static FaceQualityResult preScreen({
    required Face face,
    required int frameWidth,
    required int frameHeight,
    bool requireOpenEyes = true,
    double pitchLimit = maxPitchAbs,
    double yawLimit = maxYawAbs,
    double rollLimit = maxRollAbs,
  }) {
    final box = face.boundingBox;
    final visibility = (box.width * box.height) / (frameWidth * frameHeight);
    if (visibility < minVisibilityRatio) {
      return FaceQualityResult.fail(
        FaceQualityIssue.tooSmall,
        'Move closer — face too small in frame',
      );
    }

    final cxOff = (box.center.dx - frameWidth / 2).abs() / frameWidth;
    final cyOff = (box.center.dy - frameHeight / 2).abs() / frameHeight;
    if (cxOff > maxOffCenterRatio || cyOff > maxOffCenterRatio) {
      return FaceQualityResult.fail(
        FaceQualityIssue.offCenter,
        'Center your face in the frame',
      );
    }

    final yaw = face.headEulerAngleY ?? 0;
    final pitch = face.headEulerAngleX ?? 0;
    final roll = face.headEulerAngleZ ?? 0;
    if (pitch.abs() > pitchLimit) {
      return FaceQualityResult.fail(
        FaceQualityIssue.poseBad,
        pitchLimit > 20
            ? 'Tilt a little less — stay in the oval'
            : 'Hold your head level — not tilted up/down',
      );
    }
    if (yaw.abs() > yawLimit) {
      return FaceQualityResult.fail(
        FaceQualityIssue.poseBad,
        'Face the camera more directly',
      );
    }
    if (roll.abs() > rollLimit) {
      return FaceQualityResult.fail(
        FaceQualityIssue.poseBad,
        'Hold your head straight — do not tilt sideways',
      );
    }

    if (requireOpenEyes) {
      final le = face.leftEyeOpenProbability;
      final re = face.rightEyeOpenProbability;
      if (le != null && re != null) {
        final avg = (le + re) / 2;
        if (avg < minEyeOpenForRecognition) {
          return FaceQualityResult.fail(
            FaceQualityIssue.eyesClosed,
            'Open your eyes wide',
          );
        }
      }
    }

    final leLm = face.landmarks[FaceLandmarkType.leftEye];
    final reLm = face.landmarks[FaceLandmarkType.rightEye];
    final noseLm = face.landmarks[FaceLandmarkType.noseBase];
    if (leLm == null || reLm == null || noseLm == null) {
      return FaceQualityResult.fail(
        FaceQualityIssue.partial,
        'Face partially hidden — show full face',
      );
    }

    final dxEye = (reLm.position.x - leLm.position.x).toDouble();
    final dyEye = (reLm.position.y - leLm.position.y).toDouble();
    final eyeDist = math.sqrt(dxEye * dxEye + dyEye * dyEye);
    if (eyeDist < 36) {
      return FaceQualityResult.fail(
        FaceQualityIssue.tooSmall,
        'Move closer — face too small',
      );
    }

    return FaceQualityResult.ok(
      yaw: yaw,
      pitch: pitch,
      roll: roll,
      visibility: visibility,
    );
  }

  /// Lenient gates for Face ID circle enrollment — keeps the stream moving.
  static FaceQualityResult preScreenEnrollment({
    required Face face,
    required int frameWidth,
    required int frameHeight,
  }) {
    final box = face.boundingBox;
    final visibility = (box.width * box.height) / (frameWidth * frameHeight);
    if (visibility < 0.08) {
      return FaceQualityResult.fail(
        FaceQualityIssue.tooSmall,
        'Move a little closer',
      );
    }

    final cxOff = (box.center.dx - frameWidth / 2).abs() / frameWidth;
    final cyOff = (box.center.dy - frameHeight / 2).abs() / frameHeight;
    if (cxOff > 0.28 || cyOff > 0.28) {
      return FaceQualityResult.fail(
        FaceQualityIssue.offCenter,
        'Center your face in the frame',
      );
    }

    final angles = FaceEnrollmentAngles.fromFace(face);
    final yaw = angles.yaw;
    final pitch = angles.pitch;
    final roll = face.headEulerAngleZ ?? 0;
    if (pitch.abs() > 35 || yaw.abs() > 50 || roll.abs() > 28) {
      return FaceQualityResult.fail(
        FaceQualityIssue.poseBad,
        'Keep your head inside the circle',
      );
    }

    final leLm = face.landmarks[FaceLandmarkType.leftEye];
    final reLm = face.landmarks[FaceLandmarkType.rightEye];
    if (leLm == null || reLm == null) {
      return FaceQualityResult.fail(
        FaceQualityIssue.partial,
        'Face not fully visible',
      );
    }

    return FaceQualityResult.ok(
      yaw: yaw,
      pitch: pitch,
      roll: roll,
      visibility: visibility,
    );
  }

  /// Minimal gates for kiosk unlock — speed over strict pose (registration is strict).
  /// Android kiosk — size, landmarks, and euler pose (no classification required).
  static FaceQualityResult preScreenKioskAndroid({
    required Face face,
    required int frameWidth,
    required int frameHeight,
  }) {
    final instant = preScreenKioskInstant(
      face: face,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
    );
    if (!instant.passed) return instant;

    final yaw = face.headEulerAngleY;
    final pitch = face.headEulerAngleX;
    final roll = face.headEulerAngleZ;
    if (yaw == null && pitch == null && roll == null) {
      return instant;
    }
    final y = yaw ?? 0;
    final p = pitch ?? 0;
    final r = roll ?? 0;
    if (p.abs() > kioskMaxPitchAbs) {
      return FaceQualityResult.fail(
        FaceQualityIssue.poseBad,
        'Tilt a little less — stay in the oval',
      );
    }
    if (y.abs() > kioskMaxYawAbs) {
      return FaceQualityResult.fail(
        FaceQualityIssue.poseBad,
        'Face the kiosk more directly',
      );
    }
    if (r.abs() > kioskMaxRollAbs) {
      return FaceQualityResult.fail(
        FaceQualityIssue.poseBad,
        'Hold your head straight',
      );
    }
    return FaceQualityResult.ok(yaw: y, pitch: p, roll: r);
  }

  /// Guided pose steps (left/right/up/down) — face must be visible; do not
  /// require both eyes (ML Kit often drops one eye landmark when the head tilts).
  static FaceQualityResult preScreenGuidedPoseStep({
    required Face face,
    required int frameWidth,
    required int frameHeight,
  }) {
    if (frameWidth <= 0 || frameHeight <= 0) {
      return FaceQualityResult.fail(
        FaceQualityIssue.partial,
        'prescreen: invalid frame size',
      );
    }
    final box = face.boundingBox;
    final visibility = (box.width * box.height) / (frameWidth * frameHeight);
    if (visibility < 0.05) {
      return FaceQualityResult.fail(
        FaceQualityIssue.tooSmall,
        'prescreen: face too small (${(visibility * 100).toStringAsFixed(0)}%)',
      );
    }

    final nose = face.landmarks[FaceLandmarkType.noseBase];
    final le = face.landmarks[FaceLandmarkType.leftEye];
    final re = face.landmarks[FaceLandmarkType.rightEye];
    final eulerOk = face.headEulerAngleY != null && face.headEulerAngleX != null;
    if (nose != null || (le != null && re != null) || eulerOk) {
      return FaceQualityResult.ok();
    }
    return FaceQualityResult.fail(
      FaceQualityIssue.partial,
      'prescreen: need nose, both eyes, or head pose',
    );
  }

  static FaceQualityResult preScreenKioskInstant({
    required Face face,
    required int frameWidth,
    required int frameHeight,
  }) {
    if (frameWidth <= 0 || frameHeight <= 0) {
      return FaceQualityResult.fail(FaceQualityIssue.partial, '');
    }
    final box = face.boundingBox;
    final visibility = (box.width * box.height) / (frameWidth * frameHeight);
    if (visibility < 0.08) {
      return FaceQualityResult.fail(FaceQualityIssue.tooSmall, '');
    }
    final leLm = face.landmarks[FaceLandmarkType.leftEye];
    final reLm = face.landmarks[FaceLandmarkType.rightEye];
    if (leLm == null || reLm == null) {
      return FaceQualityResult.fail(FaceQualityIssue.partial, '');
    }
    return FaceQualityResult.ok();
  }

  /// Kiosk portal UI — platform pre-check + face centered in the circle.
  static FaceQualityResult preScreenKioskPortal({
    required Face face,
    required int frameWidth,
    required int frameHeight,
  }) {
    final base = Platform.isAndroid
        ? preScreenKioskInstant(
            face: face,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
          )
        : preScreenKiosk(
            face: face,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
          );
    if (!base.passed) return base;

    if (!FacePortalFrameGate.faceInPortal(
      face: face,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
    )) {
      return FaceQualityResult.fail(
        FaceQualityIssue.offCenter,
        'Center your face in the circle',
      );
    }
    return base;
  }

  /// Faster pre-check for kiosk (no crop blur). Balances speed vs quality.
  static FaceQualityResult preScreenKiosk({
    required Face face,
    required int frameWidth,
    required int frameHeight,
  }) {
    final box = face.boundingBox;
    final visibility = (box.width * box.height) / (frameWidth * frameHeight);
    if (visibility < kioskMinVisibilityRatio) {
      return FaceQualityResult.fail(
        FaceQualityIssue.tooSmall,
        'Move a little closer',
      );
    }

    final cxOff = (box.center.dx - frameWidth / 2).abs() / frameWidth;
    final cyOff = (box.center.dy - frameHeight / 2).abs() / frameHeight;
    if (cxOff > kioskMaxOffCenterRatio || cyOff > kioskMaxOffCenterRatio) {
      return FaceQualityResult.fail(
        FaceQualityIssue.offCenter,
        'Center your face in the frame',
      );
    }

    final yaw = face.headEulerAngleY ?? 0;
    final pitch = face.headEulerAngleX ?? 0;
    final roll = face.headEulerAngleZ ?? 0;
    if (pitch.abs() > kioskMaxPitchAbs || yaw.abs() > kioskMaxYawAbs) {
      return FaceQualityResult.fail(
        FaceQualityIssue.poseBad,
        'Look straight at the kiosk',
      );
    }
    if (roll.abs() > kioskMaxRollAbs) {
      return FaceQualityResult.fail(
        FaceQualityIssue.poseBad,
        'Hold your head level',
      );
    }

    final le = face.leftEyeOpenProbability;
    final re = face.rightEyeOpenProbability;
    if (le != null && re != null && (le + re) / 2 < kioskMinEyeOpen) {
      return FaceQualityResult.fail(
        FaceQualityIssue.eyesClosed,
        'Open your eyes',
      );
    }

    final leLm = face.landmarks[FaceLandmarkType.leftEye];
    final reLm = face.landmarks[FaceLandmarkType.rightEye];
    if (leLm == null || reLm == null) {
      return FaceQualityResult.fail(
        FaceQualityIssue.partial,
        'Face not fully visible',
      );
    }

    return FaceQualityResult.ok(yaw: yaw, pitch: pitch, roll: roll, visibility: visibility);
  }

  /// Pixel-level quality on the aligned face crop (run only on capture
  /// frames to keep the live stream fast).
  ///
  /// Combines a simple gray-mean brightness check with a 3×3 Laplacian
  /// variance ("sharpness") metric — the standard cheap blur detector.
  static FaceQualityResult assessCrop(
    img.Image crop, {
    double? minSharpnessThreshold,
  }) {
    final sharpnessMin = minSharpnessThreshold ?? minSharpness;
    final w = crop.width;
    final h = crop.height;
    if (w < 32 || h < 32) {
      return FaceQualityResult.fail(
        FaceQualityIssue.tooSmall,
        'Face crop too small',
      );
    }

    final gray = List<int>.filled(w * h, 0);
    var sum = 0.0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = crop.getPixel(x, y);
        final g = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
        gray[y * w + x] = g;
        sum += g;
      }
    }
    final mean = sum / (w * h);
    if (mean < minBrightness) {
      return FaceQualityResult.fail(
        FaceQualityIssue.tooDark,
        'Lighting too low — move to a brighter spot',
      );
    }
    if (mean > maxBrightness) {
      return FaceQualityResult.fail(
        FaceQualityIssue.tooBright,
        'Too bright — reduce direct light',
      );
    }

    // Laplacian 3×3 variance.
    var lapSum = 0.0;
    var lapSqSum = 0.0;
    var count = 0;
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        final lap = (4 * gray[i] -
                gray[i - 1] -
                gray[i + 1] -
                gray[i - w] -
                gray[i + w])
            .toDouble();
        lapSum += lap;
        lapSqSum += lap * lap;
        count++;
      }
    }
    final lapMean = lapSum / count;
    final variance = (lapSqSum / count) - (lapMean * lapMean);
    if (variance < sharpnessMin) {
      return FaceQualityResult.fail(
        FaceQualityIssue.blurry,
        'Hold still — image is blurry',
      );
    }

    return FaceQualityResult.ok(
      brightness: mean,
      sharpness: variance,
    );
  }
}

enum FaceQualityIssue {
  tooSmall,
  offCenter,
  poseBad,
  eyesClosed,
  partial,
  blurry,
  tooDark,
  tooBright,
  none,
}

class FaceQualityResult {
  const FaceQualityResult({
    required this.passed,
    required this.issue,
    required this.message,
    this.yaw,
    this.pitch,
    this.roll,
    this.visibility,
    this.brightness,
    this.sharpness,
  });

  factory FaceQualityResult.ok({
    double? yaw,
    double? pitch,
    double? roll,
    double? visibility,
    double? brightness,
    double? sharpness,
  }) {
    return FaceQualityResult(
      passed: true,
      issue: FaceQualityIssue.none,
      message: null,
      yaw: yaw,
      pitch: pitch,
      roll: roll,
      visibility: visibility,
      brightness: brightness,
      sharpness: sharpness,
    );
  }

  factory FaceQualityResult.fail(FaceQualityIssue issue, String message) {
    return FaceQualityResult(
      passed: false,
      issue: issue,
      message: message,
    );
  }

  final bool passed;
  final FaceQualityIssue issue;
  final String? message;
  final double? yaw;
  final double? pitch;
  final double? roll;
  final double? visibility;
  final double? brightness;
  final double? sharpness;
}
