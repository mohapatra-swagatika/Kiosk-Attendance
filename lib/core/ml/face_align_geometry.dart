import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Serializable eye positions for face alignment (safe across [compute] isolates).
class FaceAlignGeometry {
  const FaceAlignGeometry({
    required this.leftEyeX,
    required this.leftEyeY,
    required this.rightEyeX,
    required this.rightEyeY,
  });

  final double leftEyeX;
  final double leftEyeY;
  final double rightEyeX;
  final double rightEyeY;

  static FaceAlignGeometry? fromFace(Face face) {
    final le = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final re = face.landmarks[FaceLandmarkType.rightEye]?.position;
    if (le == null || re == null) return null;
    return FaceAlignGeometry(
      leftEyeX: le.x.toDouble(),
      leftEyeY: le.y.toDouble(),
      rightEyeX: re.x.toDouble(),
      rightEyeY: re.y.toDouble(),
    );
  }
}
