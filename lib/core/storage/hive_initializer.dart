import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';

/// Opens application Hive boxes. Safe to call from [main] and await anywhere.
class HiveInitializer {
  HiveInitializer._();

  static bool _initialized = false;
  static Future<void>? _initFuture;

  /// Starts or awaits the one-time Hive open (idempotent).
  static Future<void> init() {
    return _initFuture ??= _initImpl();
  }

  static bool get isInitialized => _initialized;

  static Future<void> _initImpl() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await Future<void>.delayed(Duration.zero);
    await Hive.openBox<dynamic>(HiveBoxes.app);
    _initialized = true;
    debugPrint('HiveInitializer: boxes ready');
  }
}
