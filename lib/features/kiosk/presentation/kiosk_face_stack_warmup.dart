import 'package:attendance_kiosk_app/app/bootstrap.dart' show appFaceEmbedder;
import 'package:attendance_kiosk_app/core/camera/camera_session_helper.dart';
import 'package:attendance_kiosk_app/core/firebase/firebase_readiness.dart';
import 'package:attendance_kiosk_app/core/ui/ui_yield.dart';

/// Pre-warms kiosk face stack (Firebase, camera list, TFLite) off the critical
/// path — call after registration or when entering kiosk mode.
class KioskFaceStackWarmup {
  KioskFaceStackWarmup._();

  static final KioskFaceStackWarmup instance = KioskFaceStackWarmup._();

  bool _scheduled = false;
  Future<void>? _firebase;
  Future<bool>? _tflite;

  bool get isScheduled => _scheduled;

  void schedule() {
    if (_scheduled) return;
    _scheduled = true;
    FirebaseReadiness.instance.scheduleInit();
    _firebase = FirebaseReadiness.instance.whenReady();
    CameraSessionHelper.warmUpCameraList();
    _tflite = _warmTflite();
  }

  Future<bool> _warmTflite() async {
    await yieldToUi();
    if (appFaceEmbedder.isReady) {
      await appFaceEmbedder.warmUpInference();
      return true;
    }
    final ok = await appFaceEmbedder.initialize();
    if (ok) {
      await appFaceEmbedder.warmUpInference();
    }
    return ok;
  }

  Future<void> ensureFirebase() async {
    schedule();
    await (_firebase ?? FirebaseReadiness.instance.whenReady());
  }

  Future<bool> ensureTflite() async {
    schedule();
    return await (_tflite ?? _warmTflite());
  }
}
