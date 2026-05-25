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
    if (Platform.isAndroid) return 1;
    return isTabletLayout ? 3 : 2;
  }

  static Duration get kioskPreviewDelay => isTabletLayout
      ? const Duration(milliseconds: 120)
      : const Duration(milliseconds: 200);

  static Duration get kioskMlSettleDelay => isTabletLayout
      ? const Duration(milliseconds: 180)
      : const Duration(milliseconds: 120);

  static Duration enrollmentMlSettleDelay() {
    if (Platform.isAndroid) {
      return const Duration(milliseconds: 220);
    }
    return isTabletLayout
        ? const Duration(milliseconds: 650)
        : const Duration(milliseconds: 900);
  }

  static Duration enrollmentPreviewDelay() {
    if (Platform.isAndroid) {
      return const Duration(milliseconds: 180);
    }
    return isTabletLayout
        ? const Duration(milliseconds: 280)
        : const Duration(milliseconds: 400);
  }

  /// Min gap between enrollment ML passes (tablet slightly slower).
  static Duration get enrollmentDetectInterval {
    if (Platform.isAndroid) {
      return const Duration(milliseconds: 72);
    }
    return isTabletLayout
        ? const Duration(milliseconds: 160)
        : const Duration(milliseconds: 130);
  }
}
