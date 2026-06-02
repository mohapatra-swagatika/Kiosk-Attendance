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
import 'package:attendance_kiosk_app/core/ml/android_ml_tuning.dart';
import 'package:attendance_kiosk_app/core/ml/android_nv21_align.dart';
import 'package:attendance_kiosk_app/core/ml/face_recognition_trace.dart';
import 'package:attendance_kiosk_app/core/ml/mlkit_face_detection_service.dart';
import 'package:attendance_kiosk_app/core/ml/mlkit_face_detector_factory.dart';

/// ML Kit detection + MobileFaceNet embeddings for kiosk.
///
/// On Android, detection uses the same shared enrollment detector as Face ID
/// registration so landmark coordinates match stored gallery embeddings.
class KioskFaceAnalyzer {
  KioskFaceAnalyzer() {
    if (!Platform.isAndroid) {
      _kioskDetector = MlKitFaceDetectorFactory.createKiosk();
    }
  }

  FaceDetector? _kioskDetector;
  bool _closed = false;

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
    if (Platform.isAndroid) {
      return FaceMlDetectSerial.runAndroidKioskDetect(() async {
        try {
          return await MlKitEnrollmentFaceDetector.instance
              .detectLiveFrameForKiosk(clone.frame);
        } on TimeoutException {
          FaceRecognitionTrace.kioskSkip('detect_timeout');
          return const FaceFrameAnalysis(
            faceCount: 0,
            message: 'Hold still — scanning',
          );
        }
      });
    }

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
    if (!Platform.isIOS) {
      return const FaceFrameAnalysis(
        faceCount: 0,
        message: 'Face scan only on Android/iOS',
      );
    }

    final detector = _kioskDetector;
    if (detector == null) {
      return const FaceFrameAnalysis(
        faceCount: 0,
        message: 'Detector unavailable',
      );
    }

    final frame = clone.frame;
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

    final faces = await detector.processImage(input);
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
  }

  Future<KioskEmbedResult> embedWhenReady({
    required CameraFrameClone clone,
    required Face face,
    Map<String, Map<String, dynamic>> gallery = const {},
  }) {
    // TFLite must use [FaceMlEmbedSerial] — detect serial has a 340ms cap and
    // timeouts there bypass our catch, so embed logs never appeared.
    return FaceMlEmbedSerial.runKiosk(() async {
      try {
        return await _embedInner(clone, face, gallery: gallery);
      } on TimeoutException {
        return KioskEmbedResult.fail('Hold still — verifying');
      }
    });
  }

  Future<KioskEmbedResult> _embedInner(
    CameraFrameClone clone,
    Face face, {
    Map<String, Map<String, dynamic>> gallery = const {},
  }) async {
    if (_closed) return KioskEmbedResult.fail('Analyzer closed');
    if (!appFaceEmbedder.isReady) {
      return KioskEmbedResult.fail('Face model not loaded');
    }

    final frame = clone.frame;
    final dims = mlKitReportedDims(frame);
    // Android kiosk uses the enrollment ML Kit profile (classification off).
    // headEulerAngleY/X are often wrong vs a mounted kiosk — strict pose gates
    // block every embed with "Look straight at the kiosk". iOS kiosk detector
    // has classification on; keep full [preScreenKiosk] there.
    final pre = FaceQualityAssessor.preScreenKioskPortal(
      face: face,
      frameWidth: dims.width,
      frameHeight: dims.height,
    );
    if (!pre.passed) {
      final reason = pre.message?.trim();
      if (Platform.isAndroid) {
        final y = face.headEulerAngleY;
        final p = face.headEulerAngleX;
        FaceRecognitionTrace.embeddingFailed(
          phase: 'kiosk',
          reason: reason != null && reason.isNotEmpty
              ? '$reason (yaw=$y pitch=$p vis=${dims.width}x${dims.height})'
              : 'preScreen failed (yaw=$y pitch=$p)',
        );
      } else {
        FaceRecognitionTrace.embeddingFailed(
          phase: 'kiosk',
          reason: reason != null && reason.isNotEmpty
              ? reason
              : 'preScreenKiosk failed',
        );
      }
      return KioskEmbedResult.fail(reason ?? 'Face quality too low');
    }

    List<double>? embedding;
    double? sharpness;
    if (Platform.isAndroid && gallery.isNotEmpty) {
      final capture = await AndroidNv21AlignCalibrator.embedKioskCapture(
        frame: frame,
        description: clone.description,
        face: face,
        gallery: gallery,
      );
      if (capture != null) {
        final cropQ = FaceQualityAssessor.assessCrop(
          capture.crop,
          minSharpnessThreshold: AndroidMlTuning.kioskMinCropSharpness,
        );
        sharpness = cropQ.sharpness;
        if (!cropQ.passed) {
          FaceRecognitionTrace.embeddingFailed(
            phase: 'kiosk',
            reason: 'blur sharp=${cropQ.sharpness?.toStringAsFixed(1) ?? "?"}',
          );
          return KioskEmbedResult.fail('Hold still — keep your face steady');
        }
        embedding = capture.embedding;
      }
    } else if (Platform.isAndroid) {
      final modeIndex = AndroidNv21AlignCalibrator.enrollmentLockedIndex;
      final capture = await appFaceEmbedder.embedFromLiveFrame(
        frame: frame,
        description: clone.description,
        face: face,
        androidAlign: modeIndex != null
            ? AndroidNv21AlignMode.values[modeIndex]
            : AndroidNv21AlignMode.rotWithFlip,
      );
      embedding = capture?.embedding;
    } else {
      final capture = await appFaceEmbedder.embedFromLiveFrame(
        frame: frame,
        description: clone.description,
        face: face,
      );
      embedding = capture?.embedding;
    }

    if (embedding == null) {
      FaceRecognitionTrace.embeddingFailed(
        phase: 'kiosk',
        reason: 'aligned crop null',
      );
      return KioskEmbedResult.fail('Hold still — face not clear enough');
    }

    FaceRecognitionTrace.embeddingGenerated(
      phase: 'kiosk',
      dim: embedding.length,
    );
    return KioskEmbedResult.ok(embedding, cropSharpness: sharpness);
  }

  Future<void> dispose() {
    return FaceMlDetectSerial.run(() async {
      if (_closed) return;
      _closed = true;
      if (Platform.isAndroid) {
        return;
      }
      final detector = _kioskDetector;
      if (detector != null) {
        await detector.close();
      }
    });
  }
}

class KioskEmbedResult {
  const KioskEmbedResult._({
    required this.ok,
    this.embedding,
    this.message,
    this.cropSharpness,
  });

  factory KioskEmbedResult.ok(
    List<double> embedding, {
    double? cropSharpness,
  }) =>
      KioskEmbedResult._(
        ok: true,
        embedding: embedding,
        cropSharpness: cropSharpness,
      );

  factory KioskEmbedResult.fail(String message) =>
      KioskEmbedResult._(ok: false, message: message);

  final bool ok;
  final List<double>? embedding;
  final String? message;
  final double? cropSharpness;
}
