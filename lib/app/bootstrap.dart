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

/// Initializes Firebase, storage, and TFLite without blocking the first frame.
///
/// ML Kit is **not** warmed up here — a dummy `processImage` call can freeze iOS
/// for 15–20s on the main thread. The first real camera frame primes the detector.
Future<String?> bootstrap({
  void Function(String status)? onStatus,
}) async {
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

  onStatus?.call('Loading face recognition model…');
  final tfliteReady = await appFaceEmbedder.initialize();
  if (!tfliteReady) {
    final detail = appFaceEmbedder.loadError ?? 'unknown error';
    return 'MobileFaceNet model is required for face recognition.\n\n'
        '1. Download mobile_face_net.tflite (192-dim, 112×112 input)\n'
        '2. Place it in: assets/models/mobile_face_net.tflite\n'
        '3. Run: ./scripts/download_mobilefacenet.sh\n'
        '4. Full rebuild: flutter clean && flutter run\n\n'
        'See assets/models/README.md\n\n'
        'Load error: $detail';
  }
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
    home: Scaffold(
      body: AppErrorView(message: message),
    ),
  );
}
