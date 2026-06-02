import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

/// Device-aware camera / ML cadence (tablet vs phone).
class CameraRuntime {
  CameraRuntime._();

  static bool? _tabletLayout;

  /// Shortest logical side ≥ 600 → iPad / large tablet layout.
  static bool get isTabletLayout {
    if (_tabletLayout != null) return _tabletLayout!;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      _tabletLayout = false;
      return false;
    }
    final view = views.first;
    final logical = view.physicalSize / view.devicePixelRatio;
    _tabletLayout = logical.shortestSide >= 600;
    return _tabletLayout!;
  }

  /// Front camera resolution — medium keeps ML fast on phones and tablets.
  static ResolutionPreset get frontCameraPreset => ResolutionPreset.medium;

  /// Kiosk ML Kit: every Nth frame runs full detect (reuse cache between).
  static int get kioskDetectEveryNFrames {
    // Match iOS cadence — every-frame detect on Android overloaded the serial ML
    // queue and produced empty/stale face analysis on mid-range devices.
    // Every frame on Android — stale cached landmarks on off-frames broke embed alignment.
    if (Platform.isAndroid) return 1;
    return isTabletLayout ? 3 : 2;
  }

  static Duration get kioskPreviewDelay => isTabletLayout
      ? const Duration(milliseconds: 120)
      : const Duration(milliseconds: 200);

  static Duration get kioskMlSettleDelay => isTabletLayout
      ? const Duration(milliseconds: 180)
      : const Duration(milliseconds: 120);

  static Duration enrollmentMlSettleDelay({bool mlKitPrimed = false}) {
    if (mlKitPrimed) {
      return Platform.isAndroid
          ? const Duration(milliseconds: 120)
          : const Duration(milliseconds: 180);
    }
    if (Platform.isAndroid) {
      return const Duration(milliseconds: 280);
    }
    return isTabletLayout
        ? const Duration(milliseconds: 400)
        : const Duration(milliseconds: 500);
  }

  static Duration enrollmentPreviewDelay() {
    if (Platform.isAndroid) {
      return const Duration(milliseconds: 100);
    }
    return isTabletLayout
        ? const Duration(milliseconds: 120)
        : const Duration(milliseconds: 160);
  }

  /// Min gap between enrollment ML passes (tablet slightly slower).
  static Duration get enrollmentDetectInterval {
    if (Platform.isAndroid) {
      return const Duration(milliseconds: 66);
    }
    return isTabletLayout
        ? const Duration(milliseconds: 160)
        : const Duration(milliseconds: 130);
  }
}
