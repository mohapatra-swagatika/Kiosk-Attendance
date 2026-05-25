import 'dart:ui' show Size;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:attendance_kiosk_app/core/ml/face_detection_port.dart';

/// Production adapter for Google ML Kit face detection.
class MlKitFaceDetectionAdapter implements FaceDetectionPort {
  FaceDetector? _detector;

  FaceDetector _createDetector() {
    return FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: true,
        enableContours: true,
        enableClassification: false,
        enableTracking: true,
      ),
    );
  }

  @override
  Future<void> ensureInitialized() async {
    _detector ??= _createDetector();
  }

  InputImageFormat _toInputFormat(LiveCameraImageFormat f) {
    return switch (f) {
      LiveCameraImageFormat.nv21 => InputImageFormat.nv21,
      LiveCameraImageFormat.bgra8888 => InputImageFormat.bgra8888,
    };
  }

  InputImageRotation _toRotation(int degrees) {
    final normalized = ((degrees % 360) + 360) % 360;
    return InputImageRotationValue.fromRawValue(normalized) ?? InputImageRotation.rotation0deg;
  }

  @override
  Future<List<DetectedFaceSummary>> detectLive(LiveCameraFrame frame) async {
    await ensureInitialized();
    final input = InputImage.fromBytes(
      bytes: frame.bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: _toRotation(frame.rotationDegrees),
        format: _toInputFormat(frame.format),
        bytesPerRow: frame.bytesPerRow,
      ),
    );
    final faces = await _detector!.processImage(input);
    return faces.map((f) => DetectedFaceSummary(trackingId: f.trackingId)).toList(growable: false);
  }

  @override
  Future<List<DetectedFaceSummary>> analyze(FaceAnalysisRequest request) async {
    await ensureInitialized();
    final path = request.filePath;
    if (path == null || path.isEmpty) return const [];
    final input = InputImage.fromFilePath(path);
    final faces = await _detector!.processImage(input);
    return faces.map((f) => DetectedFaceSummary(trackingId: f.trackingId)).toList(growable: false);
  }

  @override
  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}
