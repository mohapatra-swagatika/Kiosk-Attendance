import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';
import 'package:attendance_kiosk_app/features/auth/login/data/datasources/session_local_data_source.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/entities/app_session.dart';
import 'package:attendance_kiosk_app/features/registration/data/datasources/kiosk_config_local_data_source.dart';

/// Cached kiosk pairing + session flags for fast, non-blocking routing.
///
/// Preloaded during bootstrap so the first [GoRouter] redirect does not await
/// Hive on the critical path while the user is trying to focus a text field.
class AppLaunchGate {
  AppLaunchGate._();

  static GateSnapshot? _cache;
  static bool _dirty = true;
  static bool _storageReady = false;

  static bool get isStorageReady => _storageReady;

  static bool get isCached => _storageReady && _cache != null && !_dirty;

  static GateSnapshot get cached =>
      _cache ?? const GateSnapshot(hasConfig: false);

  /// Called once after [HiveInitializer.init] succeeds.
  static void markStorageReady() {
    _storageReady = true;
  }

  /// Refreshes from Hive (requires [markStorageReady] first).
  static Future<GateSnapshot> preload() async {
    if (!_storageReady) {
      return const GateSnapshot(hasConfig: false);
    }
    _cache = await _loadFromHive();
    _dirty = false;
    return _cache!;
  }

  /// Returns the cached snapshot or reloads when invalidated.
  static Future<GateSnapshot> read() async {
    if (!_storageReady) {
      return const GateSnapshot(hasConfig: false);
    }
    if (_cache != null && !_dirty) return _cache!;
    return preload();
  }

  static void invalidate() {
    _dirty = true;
  }

  static Future<GateSnapshot> _loadFromHive() async {
    final box = Hive.box<dynamic>(HiveBoxes.app);
    final hasConfig = await KioskConfigLocalDataSourceImpl(box).hasConfig();
    final session = await SessionLocalDataSourceImpl(box).currentSession();
    return GateSnapshot(hasConfig: hasConfig, session: session);
  }
}

class GateSnapshot {
  const GateSnapshot({required this.hasConfig, this.session});

  final bool hasConfig;
  final AppSession? session;

  bool get loggedIn => session?.loggedIn == true;
}
