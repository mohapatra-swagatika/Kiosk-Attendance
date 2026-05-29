import 'package:camera/camera.dart' show CameraDescription, CameraLensDirection;
import 'package:flutter/foundation.dart';

import 'package:attendance_kiosk_app/core/ml/face_align_geometry.dart';
import 'package:attendance_kiosk_app/core/ml/face_detection_port.dart';
import 'package:attendance_kiosk_app/core/ml/face_image_pipeline.dart';

/// Input for [faceEmbedPreprocessIsolate] (must be sendable across isolates).
class FaceEmbedPreprocessInput {
  const FaceEmbedPreprocessInput({
    required this.bytes,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.bytesPerRow,
    required this.format,
    required this.sensorOrientation,
    required this.lensDirection,
    required this.mlKitWidth,
    required this.mlKitHeight,
    required this.geometry,
    required this.outputSize,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int rotationDegrees;
  final int bytesPerRow;
  final LiveCameraImageFormat format;
  final int sensorOrientation;
  final CameraLensDirection lensDirection;
  final int mlKitWidth;
  final int mlKitHeight;
  final FaceAlignGeometry geometry;
  final int outputSize;

  /// Small synthetic frame to JIT the crop path during app warm-up.
  factory FaceEmbedPreprocessInput.synthetic({int outputSize = 112}) {
    const w = 320;
    const h = 240;
    final bytes = Uint8List(w * h * 4);
    return FaceEmbedPreprocessInput(
      bytes: bytes,
      width: w,
      height: h,
      rotationDegrees: 0,
      bytesPerRow: w * 4,
      format: LiveCameraImageFormat.bgra8888,
      sensorOrientation: 270,
      lensDirection: CameraLensDirection.front,
      mlKitWidth: w,
      mlKitHeight: h,
      geometry: const FaceAlignGeometry(
        leftEyeX: w * 0.35,
        leftEyeY: h * 0.4,
        rightEyeX: w * 0.65,
        rightEyeY: h * 0.4,
      ),
      outputSize: outputSize,
    );
  }
}

/// RGB align + normalize + model input on a worker isolate (keeps camera preview fluid).
Float32List? faceEmbedPreprocessIsolate(FaceEmbedPreprocessInput input) {
  final frame = LiveCameraFrame(
    bytes: input.bytes,
    width: input.width,
    height: input.height,
    rotationDegrees: input.rotationDegrees,
    format: input.format,
    bytesPerRow: input.bytesPerRow,
  );
  final description = CameraDescription(
    name: 'embed',
    lensDirection: input.lensDirection,
    sensorOrientation: input.sensorOrientation,
  );
  final crop = FaceImagePipeline.alignedFaceCropFromLiveFrame(
    frame: frame,
    description: description,
    geometry: input.geometry,
    mlKitWidth: input.mlKitWidth,
    mlKitHeight: input.mlKitHeight,
    outputSize: input.outputSize,
  );
  if (crop == null) return null;
  return rgbImageToFloat32(crop, size: input.outputSize);
}

/// Runs [faceEmbedPreprocessIsolate] off the UI thread.
Future<Float32List?> preprocessEmbedInput(FaceEmbedPreprocessInput input) {
  return compute(faceEmbedPreprocessIsolate, input);
}
