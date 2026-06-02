import 'dart:io' show Platform;

/// Android-only Face ID enrollment responsiveness (iOS uses session defaults).
abstract final class AndroidEnrollmentConfig {
  AndroidEnrollmentConfig._();

  static bool get enabled => Platform.isAndroid;

  static const int positioningFramesRequired = 1;

  static const int stableFramesRequired = 1;

  /// Consecutive in-pose frames before advancing the guided arrow.
  static const int poseHoldFramesRequired = 2;

  static const int captureIntervalMs = 80;

  static const double minStabilityScore = 0.22;

  /// Straight step — centering (looser than side poses).
  static const double straightCenterMin = 0.28;

  static const double straightDistanceMin = 0.22;

  /// Side/up/down — slightly stricter framing.
  static const double poseCenterMin = 0.30;

  static const double poseDistanceMin = 0.24;

  /// Landmark yaw for straight (pitch uses delta from neutral — see below).
  static const double straightYawAbs = 14;

  /// Max |pitch − neutralPitch| while on straight (not absolute pitch).
  static const double straightPitchFromNeutral = 10;

  static const double sideYawMin = 6;

  static const double tiltPitchMin = 6;

  static const double sideYawDelta = 4.0;

  static const double tiltPitchDelta = 4.0;
}
