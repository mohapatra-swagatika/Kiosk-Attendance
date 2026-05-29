import 'package:flutter/material.dart';

import 'package:attendance_kiosk_app/core/ml/tflite_face_embedder.dart';
import 'package:attendance_kiosk_app/core/widgets/app_error_view.dart';

/// Process-wide TFLite embedder shared across the app (loaded lazily in kiosk flow).
final TfliteFaceEmbedder appFaceEmbedder = TfliteFaceEmbedder();

/// True after storage bootstrap completes ([AppStartupCoordinator.runStorageBootstrap]).
bool appMlBootstrapComplete = false;

/// Minimal error shell when bootstrap fails before the main app loads.
Widget bootstrapErrorApp(String message) {
  return MaterialApp(
    home: Scaffold(body: AppErrorView(message: message)),
  );
}
