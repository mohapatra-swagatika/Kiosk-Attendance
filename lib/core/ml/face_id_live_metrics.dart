import 'dart:ui';

import 'package:attendance_kiosk_app/core/ml/face_frame_analysis.dart';

/// Real-time face geometry for iOS Face ID–style alignment feedback.
class FaceIdLiveMetrics {
  const FaceIdLiveMetrics({
    required this.hasFace,
    required this.singleFace,
    required this.centerScore,
    required this.distanceScore,
    required this.stabilityScore,
    required this.isWellAligned,
    required this.guidance,
    this.faceOffsetNormalized,
  });

  final bool hasFace;
  final bool singleFace;
  /// 0–1 how centered the face is in frame.
  final double centerScore;
  /// 0–1 optimal distance (not too close/far).
  final double distanceScore;
  final double stabilityScore;
  final bool isWellAligned;
  final String guidance;

  /// Offset from frame center (-1..1) for dot indicator in the ring.
  final Offset? faceOffsetNormalized;

  factory FaceIdLiveMetrics.empty() => const FaceIdLiveMetrics(
        hasFace: false,
        singleFace: false,
        centerScore: 0,
        distanceScore: 0,
        stabilityScore: 0,
        isWellAligned: false,
        guidance: 'Position your face in the circle',
      );

  factory FaceIdLiveMetrics.fromAnalysis(
    FaceFrameAnalysis analysis, {
    double? lastCenterX,
    double? lastCenterY,
    int frameWidth = 0,
    int frameHeight = 0,
    double? smoothedCenterX,
    double? smoothedCenterY,
  }) {
    if (!analysis.hasSingleFace || analysis.face == null) {
      if (analysis.faceCount > 1) {
        return const FaceIdLiveMetrics(
          hasFace: true,
          singleFace: false,
          centerScore: 0,
          distanceScore: 0,
          stabilityScore: 0,
          isWellAligned: false,
          guidance: 'Only one person at a time',
        );
      }
      return FaceIdLiveMetrics.empty();
    }

    final face = analysis.face!;
    final w = analysis.imageWidth > 0 ? analysis.imageWidth : frameWidth;
    final h = analysis.imageHeight > 0 ? analysis.imageHeight : frameHeight;
    if (w == 0 || h == 0) return FaceIdLiveMetrics.empty();

    final box = face.boundingBox;
    final cx = smoothedCenterX ?? box.center.dx;
    final cy = smoothedCenterY ?? box.center.dy;
    final fw = w.toDouble();
    final fh = h.toDouble();

    final cxOff = (cx - fw / 2).abs() / (fw / 2);
    final cyOff = (cy - fh / 2).abs() / (fh / 2);
    final centerScore = (1 - (cxOff * 0.7 + cyOff * 0.7)).clamp(0.0, 1.0);

    final visibility = (box.width * box.height) / (fw * fh);
    const idealMin = 0.10;
    const idealMax = 0.42;
    double distanceScore;
    if (visibility < idealMin) {
      distanceScore = (visibility / idealMin).clamp(0.0, 1.0);
    } else if (visibility > idealMax) {
      distanceScore = ((idealMax * 1.4 - visibility) / (idealMax * 0.4)).clamp(0.0, 1.0);
    } else {
      distanceScore = 1.0;
    }

    var stabilityScore = 1.0;
    if (lastCenterX != null && lastCenterY != null) {
      final shift = ((cx - lastCenterX).abs() / fw + (cy - lastCenterY).abs() / fh) / 2;
      stabilityScore = (1 - shift * 8).clamp(0.0, 1.0);
    }

    final normX = ((cx - fw / 2) / (fw / 2)).clamp(-1.0, 1.0);
    final normY = ((cy - fh / 2) / (fh / 2)).clamp(-1.0, 1.0);

    String guidance;
    if (centerScore < 0.50) {
      guidance = normX.abs() > normY.abs()
          ? (normX > 0 ? 'Move slightly left' : 'Move slightly right')
          : (normY > 0 ? 'Move slightly up' : 'Move slightly down');
    } else if (distanceScore < 0.45) {
      guidance =
          visibility < idealMin ? 'Move a little closer' : 'Move a little farther away';
    } else if (stabilityScore < 0.55) {
      guidance = 'Hold still';
    } else {
      guidance = 'Hold still — scanning';
    }

    final isWellAligned =
        centerScore >= 0.55 && distanceScore >= 0.40 && stabilityScore >= 0.30;

    return FaceIdLiveMetrics(
      hasFace: true,
      singleFace: true,
      centerScore: centerScore,
      distanceScore: distanceScore,
      stabilityScore: stabilityScore,
      isWellAligned: isWellAligned,
      guidance: guidance,
      faceOffsetNormalized: Offset(normX, normY),
    );
  }
}
