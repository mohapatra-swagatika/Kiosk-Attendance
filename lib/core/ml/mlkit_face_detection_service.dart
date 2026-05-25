import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:attendance_kiosk_app/core/ml/face_detection_port.dart';
import 'package:attendance_kiosk_app/core/ml/face_frame_analysis.dart';
import 'package:attendance_kiosk_app/core/ml/face_ml_serial.dart';
import 'package:attendance_kiosk_app/core/ml/mlkit_face_detector_factory.dart';

/// ML Kit on Android rotates NV21 frames internally and returns face
/// coordinates in the **post-rotation** image space. iOS BGRA frames are not
/// rotated by ML Kit, so coordinates stay in the buffer's native space.
///
/// To keep `centerScore` / quality-assessor math in the same coordinate space
/// as the returned bounding box, we expose the rotated (W↔H swapped) dims on
/// Android only. iOS is untouched.
({int width, int height}) mlKitReportedDims(LiveCameraFrame frame) {
  final swap = Platform.isAndroid &&
      frame.format == LiveCameraImageFormat.nv21 &&
      (frame.rotationDegrees == 90 || frame.rotationDegrees == 270);
  if (swap) {
    return (width: frame.height, height: frame.width);
  }
  return (width: frame.width, height: frame.height);
}

/// Shared ML Kit face detector for enrollment (accurate + tracking + contours).
class MlKitEnrollmentFaceDetector {
  MlKitEnrollmentFaceDetector._() {
    _detector = MlKitFaceDetectorFactory.createEnrollment();
  }

  static final MlKitEnrollmentFaceDetector instance =
      MlKitEnrollmentFaceDetector._();

  late final FaceDetector _detector;
  bool _closed = false;
  bool _warmedUp = false;

  /// Marks detector ready without a dummy frame.
  ///
  /// Calling [FaceDetector.processImage] with a 2×2 buffer on iOS can block the
  /// main thread for 15–20s (watchdog "Hang detected"). The first live camera
  /// frame primes the model instead.
  Future<void> warmUp() async {
    if (_warmedUp || _closed) return;
    _warmedUp = true;
    if (kDebugMode) {
      debugPrint('[MLKit] Enrollment detector ready (lazy warm-up on first frame)');
    }
  }

  Future<FaceFrameAnalysis> detectLiveFrame(LiveCameraFrame frame) {
    return FaceMlDetectSerial.runEnrollment(() async {
      if (_closed) {
        return const FaceFrameAnalysis(faceCount: 0, message: 'Detector closed');
      }

      final input = InputImage.fromBytes(
        bytes: frame.bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation:
              InputImageRotationValue.fromRawValue(frame.rotationDegrees) ??
                  InputImageRotation.rotation0deg,
          format: frame.format == LiveCameraImageFormat.nv21
              ? InputImageFormat.nv21
              : InputImageFormat.bgra8888,
          bytesPerRow: frame.bytesPerRow,
        ),
      );

      final faces = await _detector.processImage(input);
      final dims = mlKitReportedDims(frame);

      if (faces.isEmpty) {
        return FaceFrameAnalysis(
          faceCount: 0,
          message: 'Align your face inside the frame',
          imageWidth: dims.width,
          imageHeight: dims.height,
        );
      }
      if (faces.length > 1) {
        return FaceFrameAnalysis(
          faceCount: faces.length,
          message: 'Only one person at a time',
          imageWidth: dims.width,
          imageHeight: dims.height,
        );
      }

      return FaceFrameAnalysis(
        faceCount: 1,
        face: faces.first,
        imageWidth: dims.width,
        imageHeight: dims.height,
      );
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await FaceMlDetectSerial.run(() => _detector.close());
  }
}
