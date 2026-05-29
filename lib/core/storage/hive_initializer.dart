import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';

/// Opens application Hive boxes. Call once before `runApp`.
class HiveInitializer {
  HiveInitializer._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await Hive.openBox<dynamic>(HiveBoxes.app);
    _initialized = true;
    debugPrint('HiveInitializer: boxes ready');
  }
}
