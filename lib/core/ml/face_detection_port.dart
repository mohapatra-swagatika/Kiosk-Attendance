import 'dart:typed_data';

/// Optional still-image path analysis (e.g. gallery).
class FaceAnalysisRequest {
  const FaceAnalysisRequest({this.filePath});

  final String? filePath;
}

/// Pixel layout for [LiveCameraFrame] passed from the camera pipeline.
enum LiveCameraImageFormat {
  nv21,
  bgra8888,
}

/// Normalized camera frame for ML Kit (no plugin types in the port).
class LiveCameraFrame {
  const LiveCameraFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.format,
    required this.bytesPerRow,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  /// 0, 90, 180, or 270 — must match [InputImageMetadata.rotation] on the ML side.
  final int rotationDegrees;
  final LiveCameraImageFormat format;

  /// Row stride for the primary plane (required by ML Kit metadata).
  final int bytesPerRow;
}

/// Normalized face summary for UI / domain (not tied to ML Kit types).
class DetectedFaceSummary {
  const DetectedFaceSummary({this.trackingId});

  final int? trackingId;
}

/// Abstraction over face detection for testability and backend swaps.
abstract class FaceDetectionPort {
  Future<void> ensureInitialized();

  Future<List<DetectedFaceSummary>> analyze(FaceAnalysisRequest request);

  /// Real-time path (camera frames).
  Future<List<DetectedFaceSummary>> detectLive(LiveCameraFrame frame);

  Future<void> dispose();
}
