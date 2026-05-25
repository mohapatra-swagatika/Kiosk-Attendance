import 'dart:io' show Platform;

import 'package:attendance_kiosk_app/core/camera/camera_runtime.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Central ML Kit face detector configuration (accurate + tracking).
class MlKitFaceDetectorFactory {
  MlKitFaceDetectorFactory._();

  /// Face ID enrollment — contours + classification for multi-angle capture (iOS).
  static FaceDetectorOptions enrollmentOptions() => FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.12,
      );

  /// Android enrollment live stream — fast mode + tracking for fluid preview.
  static FaceDetectorOptions androidEnrollmentOptions() => FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: true,
        enableContours: false,
        enableClassification: false,
        enableTracking: true,
        minFaceSize: 0.10,
      );

  /// Kiosk recognition — accurate on iOS; fast on Android for instant unlock.
  static FaceDetectorOptions kioskOptions() => FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableContours: false,
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.10,
      );

  static FaceDetectorOptions androidKioskOptions() => FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: true,
        enableContours: false,
        enableClassification: false,
        enableTracking: true,
        minFaceSize: 0.09,
      );

  static FaceDetector createEnrollment() => FaceDetector(
        options: Platform.isAndroid
            ? androidEnrollmentOptions()
            : enrollmentOptions(),
      );

  static FaceDetector createKiosk() {
    // iPad: fast mode keeps preview fluid (accurate mode can stall the UI thread).
    final useFast = Platform.isAndroid || CameraRuntime.isTabletLayout;
    return FaceDetector(
      options: useFast ? androidKioskOptions() : kioskOptions(),
    );
  }
}
