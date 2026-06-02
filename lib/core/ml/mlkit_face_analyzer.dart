import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:attendance_kiosk_app/app/bootstrap.dart' show appFaceEmbedder;
import 'package:attendance_kiosk_app/core/ml/camera_frame_clone.dart';
import 'package:attendance_kiosk_app/core/ml/face_detection_port.dart';
import 'package:attendance_kiosk_app/core/ml/face_frame_analysis.dart';
import 'package:attendance_kiosk_app/core/ml/face_ml_serial.dart';
import 'package:attendance_kiosk_app/core/ml/android_ml_tuning.dart';
import 'package:attendance_kiosk_app/core/ml/android_nv21_align.dart';
import 'package:attendance_kiosk_app/core/ml/face_recognition_trace.dart';
import 'package:attendance_kiosk_app/core/ml/face_quality_assessor.dart';
import 'package:attendance_kiosk_app/core/ml/mlkit_face_detection_service.dart';
import 'package:attendance_kiosk_app/core/ml/mlkit_face_detector_factory.dart';

/// ML Kit detection + MobileFaceNet embeddings for enrollment.
class MlKitFaceAnalyzer {
  factory MlKitFaceAnalyzer.enrollment() =>
      MlKitFaceAnalyzer._(useSharedEnrollmentDetector: true);

  factory MlKitFaceAnalyzer.registration() => MlKitFaceAnalyzer._(fast: false);

  MlKitFaceAnalyzer() : this._(useSharedEnrollmentDetector: true);

  MlKitFaceAnalyzer._({
    bool useSharedEnrollmentDetector = false,
    bool fast = true,
  }) : _useSharedEnrollmentDetector = useSharedEnrollmentDetector {
    if (!useSharedEnrollmentDetector) {
      _detector = FaceDetector(
        options: fast
            ? MlKitFaceDetectorFactory.kioskOptions()
            : MlKitFaceDetectorFactory.enrollmentStreamOptions(),
      );
    }
  }

  final bool _useSharedEnrollmentDetector;
  FaceDetector? _detector;
  bool _closed = false;

  /// Primes ML Kit on device (call once when opening enrollment).
  Future<void> warmUp() => MlKitEnrollmentFaceDetector.instance.warmUp();

  Future<FaceFrameAnalysis> analyzeClone(CameraFrameClone clone) async {
    if (_closed) {
      return const FaceFrameAnalysis(faceCount: 0, message: 'Analyzer closed');
    }

    try {
      if (_useSharedEnrollmentDetector) {
        return await MlKitEnrollmentFaceDetector.instance
            .detectLiveFrame(clone.frame);
      }
      return await FaceMlDetectSerial.runEnrollment(
        () => _analyzeLiveFrame(clone.frame),
      );
    } on TimeoutException {
      return FaceFrameAnalysis(
        faceCount: 0,
        message: 'Hold still — scanning',
        imageWidth: clone.frame.width,
        imageHeight: clone.frame.height,
      );
    }
  }

  Future<FaceFrameAnalysis> analyzeFrame({
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
    return analyzeClone(clone);
  }

  /// Runs TFLite on a background queue — does not block the next ML Kit frame.
  Future<NeuralCaptureResult> captureFromClone({
    required CameraFrameClone clone,
    required Face face,
    bool requireOpenEyes = true,
    bool enrollmentFastPath = false,
  }) async {
    if (_closed) {
      return const NeuralCaptureResult.failure('Analyzer closed');
    }

    final qaDims = mlKitReportedDims(clone.frame);
    final pre = enrollmentFastPath
        ? FaceQualityAssessor.preScreenEnrollment(
            face: face,
            frameWidth: qaDims.width,
            frameHeight: qaDims.height,
          )
        : FaceQualityAssessor.preScreen(
            face: face,
            frameWidth: qaDims.width,
            frameHeight: qaDims.height,
            requireOpenEyes: requireOpenEyes,
          );
    if (!pre.passed) {
      return NeuralCaptureResult.failure(pre.message ?? 'Face quality too low');
    }

    try {
      return await FaceMlEmbedSerial.runEnrollmentEmbed(() async {
        if (!appFaceEmbedder.isReady) {
          return const NeuralCaptureResult.failure(
            'Face recognition model not loaded',
          );
        }
        final capture = await appFaceEmbedder.embedFromLiveFrame(
          frame: clone.frame,
          description: clone.description,
          face: face,
        );
        if (capture == null) {
          return const NeuralCaptureResult.failure(
            'Adjust distance and lighting — face not clear enough',
          );
        }
        return NeuralCaptureResult.success(embedding: capture.embedding);
      });
    } on TimeoutException {
      return const NeuralCaptureResult.failure('Keep moving slowly');
    }
  }

  /// Enrollment capture — TFLite embedding + crop quality (stream uses fast ML Kit).
  Future<NeuralCaptureResult> captureForEnrollment({
    required CameraFrameClone clone,
    required Face face,
    List<List<double>> priorEmbeddings = const [],
  }) async {
    if (_closed) {
      return const NeuralCaptureResult.failure('Analyzer closed');
    }

    return _captureForEnrollmentAndroid(
      clone: clone,
      face: face,
      minCropSharpness: Platform.isIOS
          ? 16
          : AndroidMlTuning.enrollmentMinCropSharpness,
      priorEmbeddings: priorEmbeddings,
    );
  }

  Future<NeuralCaptureResult> _captureForEnrollmentAndroid({
    required CameraFrameClone clone,
    required Face face,
    double minCropSharpness = 14,
    List<List<double>> priorEmbeddings = const [],
  }) async {
    if (!_enrollmentLandmarksReadyAndroid(face, lenientPose: true)) {
      return NeuralCaptureResult.failure(
        Platform.isAndroid
            ? 'Show your full face — keep eyes or nose visible'
            : 'Show your full face — eyes and nose must be visible',
      );
    }

    final qaDims = mlKitReportedDims(clone.frame);
    final pre = FaceQualityAssessor.preScreenGuidedPoseStep(
      face: face,
      frameWidth: qaDims.width,
      frameHeight: qaDims.height,
    );
    if (!pre.passed) {
      return NeuralCaptureResult.failure(pre.message ?? 'Face quality too low');
    }

    return _runEnrollmentEmbed(
      clone: clone,
      face: face,
      minCropSharpness: minCropSharpness,
      priorEmbeddings: priorEmbeddings,
    );
  }

  Future<NeuralCaptureResult> _runEnrollmentEmbed({
    required CameraFrameClone clone,
    required Face face,
    required double? minCropSharpness,
    List<List<double>> priorEmbeddings = const [],
  }) async {
    try {
      return await FaceMlEmbedSerial.runEnrollmentEmbed(() async {
        if (!appFaceEmbedder.isReady) {
          return const NeuralCaptureResult.failure(
            'Face recognition model not loaded',
          );
        }
        final capture = Platform.isAndroid
            ? await AndroidNv21AlignCalibrator.embedEnrollment(
                frame: clone.frame,
                description: clone.description,
                face: face,
                priorEmbeddings: priorEmbeddings,
              )
            : await appFaceEmbedder.embedFromLiveFrame(
                frame: clone.frame,
                description: clone.description,
                face: face,
              );
        if (capture == null) {
          FaceRecognitionTrace.embeddingFailed(
            phase: 'enrollment',
            reason: 'aligned crop null',
          );
          return const NeuralCaptureResult.failure(
            'Hold still — lighting or focus not clear enough',
          );
        }
        FaceRecognitionTrace.embeddingGenerated(
          phase: 'enrollment',
          dim: capture.embedding.length,
        );
        final cropQ = FaceQualityAssessor.assessCrop(
          capture.crop,
          minSharpnessThreshold: minCropSharpness,
        );
        if (!cropQ.passed) {
          return NeuralCaptureResult.failure(
            cropQ.message ?? 'Hold still — image not sharp enough',
          );
        }
        return NeuralCaptureResult.success(
          embedding: capture.embedding,
          sharpness: cropQ.sharpness ?? 0,
          brightness: cropQ.brightness ?? 0,
        );
      });
    } on TimeoutException {
      return const NeuralCaptureResult.failure('Hold still — capture timed out');
    }
  }

  /// Landmarks without contours (fast ML Kit stream on iOS/Android).
  static bool _enrollmentLandmarksReadyAndroid(
    Face face, {
    bool lenientPose = false,
  }) {
    final le = face.landmarks[FaceLandmarkType.leftEye];
    final re = face.landmarks[FaceLandmarkType.rightEye];
    final nose = face.landmarks[FaceLandmarkType.noseBase];
    if (!Platform.isAndroid) {
      return le != null && re != null && nose != null;
    }
    if (lenientPose) {
      final eulerOk =
          face.headEulerAngleY != null && face.headEulerAngleX != null;
      return eulerOk || nose != null || (le != null && re != null);
    }
    return le != null && re != null;
  }

  Future<NeuralCaptureResult> captureForRecognition({
    required CameraImage image,
    required CameraDescription description,
    required Face face,
    required int imageWidth,
    required int imageHeight,
    required DeviceOrientation orientation,
    bool requireOpenEyes = true,
    bool enrollmentFastPath = false,
  }) async {
    final clone = CameraFrameClone.fromCameraImage(
      image: image,
      description: description,
      orientation: orientation,
    );
    if (clone == null) {
      return const NeuralCaptureResult.failure('Unsupported camera frame');
    }
    return captureFromClone(
      clone: clone,
      face: face,
      requireOpenEyes: requireOpenEyes,
      enrollmentFastPath: enrollmentFastPath,
    );
  }

  Future<FaceScanResult> scanForRecognition({
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
      return const FaceScanResult(message: 'Unsupported camera frame');
    }

    final analysis = await analyzeClone(clone);
    if (!analysis.hasSingleFace) {
      return FaceScanResult(message: analysis.message ?? 'Align your face');
    }

    final result = await captureFromClone(
      clone: clone,
      face: analysis.face!,
    );

    if (!result.ok) {
      return FaceScanResult(message: result.message);
    }

    return FaceScanResult(
      embedding: result.embedding,
      ready: true,
      trackingId: analysis.face!.trackingId,
      sharpness: result.sharpness,
      brightness: result.brightness,
    );
  }

  Future<FaceFrameAnalysis> _analyzeLiveFrame(LiveCameraFrame frame) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const FaceFrameAnalysis(
        faceCount: 0,
        message: 'Face scan only on Android/iOS',
      );
    }

    final detector = _detector;
    if (detector == null) {
      return const FaceFrameAnalysis(faceCount: 0, message: 'Detector unavailable');
    }

    final input = InputImage.fromBytes(
      bytes: frame.bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(frame.rotationDegrees) ??
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
        message: 'Only one person — others must step away',
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

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    if (_useSharedEnrollmentDetector) {
      return;
    }
    final detector = _detector;
    if (detector != null) {
      await FaceMlDetectSerial.run(() => detector.close());
    }
  }
}

class FaceScanResult {
  const FaceScanResult({
    this.embedding,
    this.message,
    this.ready = false,
    this.trackingId,
    this.sharpness,
    this.brightness,
  });

  final List<double>? embedding;
  final String? message;
  final bool ready;
  final int? trackingId;
  final double? sharpness;
  final double? brightness;
}

class NeuralCaptureResult {
  const NeuralCaptureResult._({
    required this.ok,
    this.embedding,
    this.message,
    this.sharpness = 0,
    this.brightness = 0,
  });

  const NeuralCaptureResult.failure(String reason)
      : this._(ok: false, message: reason);

  const NeuralCaptureResult.success({
    required List<double> embedding,
    double sharpness = 0,
    double brightness = 0,
  }) : this._(
          ok: true,
          embedding: embedding,
          sharpness: sharpness,
          brightness: brightness,
        );

  final bool ok;
  final List<double>? embedding;
  final String? message;
  final double sharpness;
  final double brightness;
}
