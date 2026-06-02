import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:attendance_kiosk_app/core/ml/enrollment_face_picker.dart';
import 'package:attendance_kiosk_app/core/ml/face_detection_port.dart';
import 'package:attendance_kiosk_app/core/ml/face_frame_analysis.dart';
import 'package:attendance_kiosk_app/core/ml/face_ml_serial.dart';
import 'package:attendance_kiosk_app/core/ml/face_recognition_trace.dart';
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

/// Shared ML Kit face detector for enrollment (fast stream + tracking).
class MlKitEnrollmentFaceDetector {
  MlKitEnrollmentFaceDetector._() {
    _detector = MlKitFaceDetectorFactory.createEnrollment();
  }

  static final MlKitEnrollmentFaceDetector instance =
      MlKitEnrollmentFaceDetector._();

  late final FaceDetector _detector;
  bool _closed = false;
  bool _modelPrimed = false;

  bool get isModelPrimed => _modelPrimed;

  /// Loads the native ML model using a still frame **before** the live stream.
  ///
  /// Run while the UI shows "Preparing camera" so the first stream frame does
  /// not block the preview for 15–20s (iOS accurate-mode first inference).
  Future<void> primeFromFile(String path) async {
    if (_modelPrimed || _closed) return;
    final file = File(path);
    if (!await file.exists()) return;

    await FaceMlDetectSerial.runEnrollmentPrime(() async {
      if (_closed) return;
      final input = InputImage.fromFilePath(path);
      await _detector.processImage(input);
    });

    _modelPrimed = true;
    if (kDebugMode) {
      debugPrint('[MLKit] Enrollment detector primed (still frame)');
    }
  }

  /// No-op when [primeFromFile] already ran.
  Future<void> warmUp() async {
    if (_modelPrimed || _closed) return;
    if (kDebugMode) {
      debugPrint(
        '[MLKit] Enrollment detector waiting for still-frame prime',
      );
    }
  }

  Future<FaceFrameAnalysis> detectLiveFrame(LiveCameraFrame frame) {
    return FaceMlDetectSerial.runEnrollment(() => _detectUncoordinated(frame));
  }

  /// Kiosk-only: caller must wrap in [FaceMlDetectSerial.runAndroidKioskDetect]
  /// (single queue hop). Do not nest inside [runEnrollment] — that caused 340ms
  /// timeouts while native detect still ran, leaving no cached face.
  Future<FaceFrameAnalysis> detectLiveFrameForKiosk(LiveCameraFrame frame) {
    return _detectUncoordinated(frame);
  }

  Future<FaceFrameAnalysis> _detectUncoordinated(LiveCameraFrame frame) async {
    if (_closed) {
      return const FaceFrameAnalysis(faceCount: 0, message: 'Detector closed');
    }

    if (FaceRecognitionTrace.enrollmentTraceEnabled &&
        Platform.isAndroid &&
        !_modelPrimed) {
      final dims = mlKitReportedDims(frame);
      FaceRecognitionTrace.log(
        'ENROLL_FRAME',
        'fmt=${frame.format} raw=${frame.width}x${frame.height} rot=${frame.rotationDegrees} '
        'ml=${dims.width}x${dims.height} bpr=${frame.bytesPerRow}',
      );
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
    _modelPrimed = true;
    final dims = mlKitReportedDims(frame);

    if (faces.isEmpty) {
      return FaceFrameAnalysis(
        faceCount: 0,
        message: 'Align your face inside the frame',
        imageWidth: dims.width,
        imageHeight: dims.height,
      );
    }

    final picked = EnrollmentFacePicker.pick(faces);
    if (picked.face == null) {
      if (kDebugMode && Platform.isAndroid) {
        FaceRecognitionTrace.enrollmentDetect(
          rawFaceCount: picked.rawCount,
          usedFaceCount: 0,
          ignoredSpurious: 0,
          note: 'multiple_real_faces',
        );
      }
      return FaceFrameAnalysis(
        faceCount: picked.rawCount,
        message: 'Only one person at a time',
        imageWidth: dims.width,
        imageHeight: dims.height,
      );
    }

    if (kDebugMode &&
        Platform.isAndroid &&
        picked.rawCount > 1 &&
        picked.ignoredSpurious > 0) {
      FaceRecognitionTrace.enrollmentDetect(
        rawFaceCount: picked.rawCount,
        usedFaceCount: 1,
        ignoredSpurious: picked.ignoredSpurious,
        note: 'spurious_filtered',
      );
    }

    return FaceFrameAnalysis(
      faceCount: 1,
      face: picked.face,
      imageWidth: dims.width,
      imageHeight: dims.height,
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await FaceMlDetectSerial.run(() => _detector.close());
  }
}
