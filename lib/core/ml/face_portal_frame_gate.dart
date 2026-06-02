import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Circular portal gate in ML Kit frame coordinates (enrollment + kiosk).
abstract final class FacePortalFrameGate {
  FacePortalFrameGate._();

  /// Matches [FaceIdPortalGeometry] portal radius ≈ 42% of shorter frame side.
  static const double portalRadiusFraction = 0.42;

  static bool faceInPortal({
    required Face face,
    required int frameWidth,
    required int frameHeight,
    double radiusFraction = portalRadiusFraction,
    double centerMargin = 0.96,
  }) {
    if (frameWidth <= 0 || frameHeight <= 0) return false;

    final box = face.boundingBox;
    final frameCx = frameWidth / 2.0;
    final frameCy = frameHeight / 2.0;
    final radius =
        math.min(frameWidth, frameHeight) * radiusFraction * centerMargin;

    final dx = box.center.dx - frameCx;
    final dy = box.center.dy - frameCy;
    return math.sqrt(dx * dx + dy * dy) <= radius;
  }
}
