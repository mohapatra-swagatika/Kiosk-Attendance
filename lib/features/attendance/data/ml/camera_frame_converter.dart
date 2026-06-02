import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'package:attendance_kiosk_app/core/ml/face_detection_port.dart';

/// Maps [CameraImage] streams to [LiveCameraFrame] for ML Kit (Android NV21, iOS BGRA).
LiveCameraFrame? liveFrameFromCameraImage({
  required CameraImage image,
  required CameraDescription description,
  required DeviceOrientation deviceOrientation,
}) {
  if (Platform.isAndroid) {
    final rotation = rotationDegreesForInputImage(
      description: description,
      deviceOrientation: deviceOrientation,
    );
    if (image.planes.length == 1) {
      final p = image.planes.first;
      return LiveCameraFrame(
        bytes: p.bytes,
        width: image.width,
        height: image.height,
        rotationDegrees: rotation,
        format: LiveCameraImageFormat.nv21,
        bytesPerRow: p.bytesPerRow,
      );
    }
    if (image.planes.length >= 3) {
      final nv21 = yuv420888ToNv21(image);
      return LiveCameraFrame(
        bytes: nv21,
        width: image.width,
        height: image.height,
        rotationDegrees: rotation,
        format: LiveCameraImageFormat.nv21,
        // Packed NV21 from [yuv420888ToNv21] — row stride equals width.
        bytesPerRow: image.width,
      );
    }
    return null;
  }
  if (Platform.isIOS && image.planes.isNotEmpty) {
    final plane = image.planes.first;
    return LiveCameraFrame(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      rotationDegrees: description.sensorOrientation,
      format: LiveCameraImageFormat.bgra8888,
      bytesPerRow: plane.bytesPerRow,
    );
  }
  return null;
}

int rotationDegreesForInputImage({
  required CameraDescription description,
  required DeviceOrientation deviceOrientation,
}) {
  final deviceDegrees = switch (deviceOrientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };
  final sensor = description.sensorOrientation;

  // ML Kit expects the rotation needed to make the image upright.
  // Standard mapping:
  // - back camera:  (sensor - device + 360) % 360
  // - front camera: (sensor + device) % 360
  // This keeps face bounding boxes and Euler angles stable across devices.
  if (description.lensDirection == CameraLensDirection.front) {
    return (sensor + deviceDegrees) % 360;
  }
  return (sensor - deviceDegrees + 360) % 360;
}

/// Converts Android YUV_420_888 [CameraImage] to NV21 for ML Kit.
Uint8List yuv420888ToNv21(CameraImage image) {
  final width = image.width;
  final height = image.height;
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];

  final ySize = width * height;
  final uvSize = ySize ~/ 2;
  final out = Uint8List(ySize + uvSize);

  final yRowStride = yPlane.bytesPerRow;
  final yBytes = yPlane.bytes;
  var outIndex = 0;
  for (var row = 0; row < height; row++) {
    final rowStart = row * yRowStride;
    out.setRange(outIndex, outIndex + width, yBytes, rowStart);
    outIndex += width;
  }

  final chromaHeight = height ~/ 2;
  final chromaWidth = width ~/ 2;
  final uBytes = uPlane.bytes;
  final vBytes = vPlane.bytes;
  final uRowStride = uPlane.bytesPerRow;
  final vRowStride = vPlane.bytesPerRow;
  final uPixelStride = uPlane.bytesPerPixel ?? 1;
  final vPixelStride = vPlane.bytesPerPixel ?? 1;

  var uvIndex = ySize;
  for (var row = 0; row < chromaHeight; row++) {
    for (var col = 0; col < chromaWidth; col++) {
      final uIndex = row * uRowStride + col * uPixelStride;
      final vIndex = row * vRowStride + col * vPixelStride;
      out[uvIndex++] = vBytes[vIndex];
      out[uvIndex++] = uBytes[uIndex];
    }
  }

  return out;
}

bool isCameraImageSupported() => Platform.isAndroid || Platform.isIOS;
