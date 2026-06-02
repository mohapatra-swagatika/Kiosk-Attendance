import 'dart:io' show Platform;

/// Android-only ML / camera tuning. iOS code paths must not read these values.
class AndroidMlTuning {
  AndroidMlTuning._();

  static bool get enabled => Platform.isAndroid;

  /// Enrollment: start ML sooner than iOS AVFoundation settle.
  static const Duration enrollmentSettleDelay = Duration(milliseconds: 220);

  /// Enrollment: faster detect cadence than iOS (iOS stays at 130ms in page).
  static const Duration enrollmentDetectInterval = Duration(milliseconds: 72);

  /// Enrollment preview delay before image stream.
  static const Duration enrollmentPreviewDelay = Duration(milliseconds: 180);

  /// Kiosk detect cadence — see [CameraRuntime.kioskDetectEveryNFrames].
  static const int kioskDetectEveryNFrames = 1;

  /// Kiosk embed cache — reuse vector briefly between frames.
  static const Duration kioskEmbedCacheTtl = Duration(milliseconds: 1500);

  /// Ring UI catch-up speed on Android enrollment.
  static const double enrollmentRingSmoothStep = 0.22;

  /// Kiosk cosine match (Android NV21 — slightly below iOS 0.84 until align is perfect).
  static const double kioskMatchThreshold = 0.80;

  static const double kioskMatchThresholdLocked = 0.78;

  static const double kioskAnchorMin = 0.76;

  /// When searching align modes, require separation between 1st and 2nd employee.
  static const double kioskAlignSearchMinMargin = 0.06;

  /// Only reuse a cached embed when the last match at cache time was this strong.
  static const double kioskMinCacheMatchScore = 0.60;

  /// Single-frame accept (high confidence + clear margin).
  static const double kioskInstantConfirmScore = 0.82;

  static const double kioskInstantConfirmMargin = 0.12;

  /// Min crop sharpness for kiosk embed (aligned with enrollment Android).
  static const double kioskMinCropSharpness = 14;

  /// Enrollment crop sharpness (Android).
  static const double enrollmentMinCropSharpness = 15;

  /// Unknown popup: consecutive weak frames required (iOS uses 1).
  static const int kioskUnknownStreakWeak = 4;

  static const int kioskUnknownStreakMid = 3;

  static const int kioskUnknownStreakNear = 2;
}
