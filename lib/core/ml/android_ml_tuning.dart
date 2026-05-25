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

  /// Kiosk: detect every frame (iOS kiosk scheduler uses every 2nd).
  static const int kioskDetectEveryNFrames = 1;

  /// Kiosk embed cache — reuse vector briefly between frames.
  static const Duration kioskEmbedCacheTtl = Duration(milliseconds: 620);

  /// Ring UI catch-up speed on Android enrollment.
  static const double enrollmentRingSmoothStep = 0.22;
}
