import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';
import 'package:attendance_kiosk_app/features/registration/data/models/kiosk_config_model.dart';

abstract class KioskConfigLocalDataSource {
  Future<void> save(KioskConfigModel model);
  Future<KioskConfigModel?> load();
  Future<bool> hasConfig();
}

class KioskConfigLocalDataSourceImpl implements KioskConfigLocalDataSource {
  KioskConfigLocalDataSourceImpl(this._box);

  final Box<dynamic> _box;

  @override
  Future<void> save(KioskConfigModel model) async {
    try {
      await _box.put(HiveKeys.kioskConfig, jsonEncode(model.toJson()));
    } catch (e) {
      throw CacheException('Failed to save kiosk config: $e');
    }
  }

  @override
  Future<KioskConfigModel?> load() async {
    try {
      final raw = _box.get(HiveKeys.kioskConfig);
      if (raw is! String || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return KioskConfigModel.fromJson(map);
    } catch (e) {
      throw CacheException('Failed to load kiosk config: $e');
    }
  }

  @override
  Future<bool> hasConfig() async {
    final raw = _box.get(HiveKeys.kioskConfig);
    return raw is String && raw.isNotEmpty;
  }
}
