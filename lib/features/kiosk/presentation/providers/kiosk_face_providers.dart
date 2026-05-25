import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/ml/kiosk_face_analyzer.dart';

/// One analyzer per kiosk session — avoids cold-start on every page open.
final kioskFaceAnalyzerProvider = Provider<KioskFaceAnalyzer>((ref) {
  final analyzer = KioskFaceAnalyzer();
  ref.onDispose(() => analyzer.dispose());
  return analyzer;
});
