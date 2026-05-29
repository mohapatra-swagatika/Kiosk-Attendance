import 'dart:io' show Platform;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Central ML Kit face detector configuration (accurate + tracking).
class MlKitFaceDetectorFactory {
  MlKitFaceDetectorFactory._();

  /// Live enrollment stream — fast mode keeps iOS preview responsive (accurate +
  /// contours on the first frame can block the UI thread for 15–20s).
  static FaceDetectorOptions enrollmentStreamOptions() => FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: true,
        enableContours: false,
        enableClassification: false,
        enableTracking: true,
        minFaceSize: 0.10,
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

  /// iOS kiosk live stream — fast mode keeps preview fluid; classification
  /// supports blink / head-pose without accurate-mode UI-thread stalls.
  static FaceDetectorOptions iosKioskStreamOptions() => FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: true,
        enableContours: false,
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.10,
      );

  static FaceDetector createEnrollment() => FaceDetector(
        options: enrollmentStreamOptions(),
      );

  static FaceDetector createKiosk() {
    if (Platform.isAndroid) {
      return FaceDetector(options: androidKioskOptions());
    }
    return FaceDetector(options: iosKioskStreamOptions());
  }
}
