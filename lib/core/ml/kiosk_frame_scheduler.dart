import 'package:attendance_kiosk_app/core/camera/camera_runtime.dart';
import 'package:attendance_kiosk_app/core/ml/face_frame_analysis.dart';

/// Throttles ML work: detect on selected frames, reuse last face between detects.
class KioskFrameScheduler {
  int _index = 0;
  FaceFrameAnalysis? _lastAnalysis;

  /// Phone / tablet / Android aware (reduces iPad ML overload).
  static int get detectEveryNFrames => CameraRuntime.kioskDetectEveryNFrames;

  bool get shouldRunDetection {
    _index++;
    return _index % detectEveryNFrames == 0;
  }

  void cacheAnalysis(FaceFrameAnalysis analysis) {
    _lastAnalysis = analysis;
  }

  FaceFrameAnalysis? get cachedAnalysis => _lastAnalysis;

  bool get hasCachedFace =>
      _lastAnalysis != null && _lastAnalysis!.hasSingleFace;

  void reset() {
    _index = 0;
    _lastAnalysis = null;
  }
}
