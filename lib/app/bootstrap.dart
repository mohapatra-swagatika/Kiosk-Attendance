import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/core/camera/camera_session_helper.dart';
import 'package:attendance_kiosk_app/core/config/app_config.dart';
import 'package:attendance_kiosk_app/core/firebase/firebase_bootstrap.dart';
import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';
import 'package:attendance_kiosk_app/core/ml/tflite_face_embedder.dart';
import 'package:attendance_kiosk_app/core/storage/hive_initializer.dart';
import 'package:attendance_kiosk_app/core/widgets/app_error_view.dart';

/// Process-wide TFLite embedder shared across the app (loaded once at startup).
final TfliteFaceEmbedder appFaceEmbedder = TfliteFaceEmbedder();

/// True after [bootstrap] completes successfully.
bool appMlBootstrapComplete = false;

/// Initializes Firebase + local storage without blocking the first frame.
///
/// ML Kit is **not** warmed up here — a dummy `processImage` call can freeze iOS
/// for 15–20s on the main thread. The first real camera frame primes the detector.
Future<String?> bootstrap({void Function(String status)? onStatus}) async {
  WidgetsFlutterBinding.ensureInitialized();
  CameraSessionHelper.warmUpCameraList();
  onStatus?.call('Connecting services…');

  try {
    await initializeFirebaseCore();
  } catch (e) {
    return 'Firebase initialization failed (required for ML Kit on iOS).\n\n'
        'Run flutterfire configure, then rebuild.\n\nError: $e';
  }

  final config = AppConfig.compile();
  if (kDebugMode) {
    debugPrint('Bootstrap: $config');
  }

  onStatus?.call('Opening local storage…');
  try {
    await HiveInitializer.init();
  } catch (e, st) {
    debugPrint('Hive init failed: $e\n$st');
    return 'Storage init failed: $e';
  }

  // Do NOT load the TFLite interpreter here.
  // Interpreter creation can block the UI thread for several seconds on iOS,
  // which makes first-launch navigation + text input feel frozen.
  //
  // The kiosk + enrollment flows will initialize [appFaceEmbedder] lazily and
  // show user-facing progress messaging while it loads.
  FaceEmbeddingCodec.setMode(FaceEmbeddingMode.tflite);
  appMlBootstrapComplete = true;

  if (kDebugMode) {
    debugPrint(
      'Bootstrap: ready — ${appFaceEmbedder.outputDim}-dim embeddings (ML Kit primes on first camera frame)',
    );
  }

  return null;
}

/// Minimal error shell when bootstrap fails before [ProviderScope].
Widget bootstrapErrorApp(String message) {
  return MaterialApp(
    home: Scaffold(body: AppErrorView(message: message)),
  );
}
