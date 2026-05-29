import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:attendance_kiosk_app/app/bootstrap.dart' show appFaceEmbedder;
import 'package:attendance_kiosk_app/core/ml/camera_frame_clone.dart';
import 'package:attendance_kiosk_app/core/ml/face_detection_port.dart';
import 'package:attendance_kiosk_app/core/ml/face_frame_analysis.dart';
import 'package:attendance_kiosk_app/core/ml/face_ml_serial.dart';
import 'package:attendance_kiosk_app/core/ml/face_quality_assessor.dart';
import 'package:attendance_kiosk_app/core/ml/mlkit_face_detection_service.dart';
import 'package:attendance_kiosk_app/core/ml/mlkit_face_detector_factory.dart';

/// ML Kit detection (accurate + tracking) + MobileFaceNet embeddings for kiosk.
class KioskFaceAnalyzer {
  KioskFaceAnalyzer() {
    _detector = MlKitFaceDetectorFactory.createKiosk();
  }

  late final FaceDetector _detector;
  bool _closed = false;
  bool _modelPrimed = false;
  bool _embedPathWarmed = false;

  bool get isModelPrimed => _modelPrimed;
  bool get isEmbedPathWarmed => _embedPathWarmed;

  /// Call after [TfliteFaceEmbedder.warmUpImagePipeline] so live scan skips embed JIT.
  void markEmbedPathWarmed() => _embedPathWarmed = true;

  /// One-time ML Kit load on a preview frame ([runKioskPrime], not [runKiosk]).
  Future<void> primeFromClone(CameraFrameClone clone) async {
    if (_closed || _modelPrimed) return;
    await FaceMlDetectSerial.runKioskPrime(() async {
      if (_closed) return;
      await _detector.processImage(_inputFromClone(clone));
    });
    _modelPrimed = true;
  }

  /// Warms detect + embed on a frame that already has a face (under a UI overlay).
  Future<void> warmRecognitionPath({
    required CameraFrameClone clone,
    required Face face,
  }) async {
    if (_closed || _embedPathWarmed) return;
    await embedWhenReady(clone: clone, face: face);
    _embedPathWarmed = true;
  }

  Future<FaceFrameAnalysis> detect({
    required CameraImage image,
    required CameraDescription description,
    required DeviceOrientation orientation,
  }) async {
    final clone = CameraFrameClone.fromCameraImage(
      image: image,
      description: description,
      orientation: orientation,
    );
    if (clone == null) {
      return const FaceFrameAnalysis(
        faceCount: 0,
        message: 'Unsupported camera frame',
      );
    }
    return detectClone(clone);
  }

  Future<FaceFrameAnalysis> detectClone(CameraFrameClone clone) {
    return FaceMlDetectSerial.runKiosk(() async {
      try {
        return await _detectCloneInner(clone);
      } on TimeoutException {
        return const FaceFrameAnalysis(
          faceCount: 0,
          message: 'Hold still — scanning',
        );
      }
    });
  }

  Future<FaceFrameAnalysis> _detectCloneInner(CameraFrameClone clone) async {
    if (_closed) {
      return const FaceFrameAnalysis(faceCount: 0, message: 'Analyzer closed');
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const FaceFrameAnalysis(
        faceCount: 0,
        message: 'Face scan only on Android/iOS',
      );
    }

    final faces = await _detector.processImage(_inputFromClone(clone));
    final dims = mlKitReportedDims(clone.frame);
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
  }

  Future<KioskEmbedResult> embedWhenReady({
    required CameraFrameClone clone,
    required Face face,
  }) {
    return FaceMlEmbedSerial.runKiosk(() async {
      try {
        return await _embedInner(clone, face);
      } on TimeoutException {
        return KioskEmbedResult.fail('Hold still — verifying');
      }
    });
  }

  Future<KioskEmbedResult> _embedInner(
    CameraFrameClone clone,
    Face face,
  ) async {
    if (_closed) return KioskEmbedResult.fail('Analyzer closed');
    if (!appFaceEmbedder.isReady) {
      return KioskEmbedResult.fail('Face model not loaded');
    }

    final frame = clone.frame;
    final dims = mlKitReportedDims(frame);
    final pre = FaceQualityAssessor.preScreenKiosk(
      face: face,
      frameWidth: dims.width,
      frameHeight: dims.height,
    );
    if (!pre.passed) {
      return KioskEmbedResult.fail(pre.message ?? '');
    }

    final capture = await appFaceEmbedder.embedFromLiveFrame(
      frame: frame,
      description: clone.description,
      face: face,
    );
    if (capture == null) {
      return KioskEmbedResult.fail('Hold still — face not clear enough');
    }

    return KioskEmbedResult.ok(capture.embedding);
  }

  InputImage _inputFromClone(CameraFrameClone clone) {
    final frame = clone.frame;
    return InputImage.fromBytes(
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
  }

  Future<void> dispose() {
    return FaceMlDetectSerial.run(() async {
      if (_closed) return;
      _closed = true;
      await _detector.close();
    });
  }
}

class KioskEmbedResult {
  const KioskEmbedResult._({required this.ok, this.embedding, this.message});

  factory KioskEmbedResult.ok(List<double> embedding) =>
      KioskEmbedResult._(ok: true, embedding: embedding);

  factory KioskEmbedResult.fail(String message) =>
      KioskEmbedResult._(ok: false, message: message);

  final bool ok;
  final List<double>? embedding;
  final String? message;
}
