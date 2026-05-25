import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Per-frame ML Kit interpretation for registration / kiosk pipelines.
class FaceFrameAnalysis {
  const FaceFrameAnalysis({
    required this.faceCount,
    this.face,
    this.message,
    this.imageWidth = 0,
    this.imageHeight = 0,
  });

  final int faceCount;
  final Face? face;
  final String? message;
  final int imageWidth;
  final int imageHeight;

  bool get hasSingleFace => faceCount == 1 && face != null;

  double? get yaw => face?.headEulerAngleY;
  double? get pitch => face?.headEulerAngleX;
  double? get leftEyeOpen => face?.leftEyeOpenProbability;
  double? get rightEyeOpen => face?.rightEyeOpenProbability;
  int? get trackingId => face?.trackingId;

  double visibilityRatio(int width, int height) {
    if (face == null || width == 0 || height == 0) return 0;
    final area = face!.boundingBox.width * face!.boundingBox.height;
    return area / (width * height);
  }
}
