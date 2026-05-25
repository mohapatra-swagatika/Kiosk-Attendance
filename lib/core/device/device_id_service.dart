import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';

/// Stable kiosk device id stored in Hive.
class DeviceIdService {
  DeviceIdService(this._box);

  final Box<dynamic> _box;
  static const _uuid = Uuid();

  Future<String> getOrCreate() async {
    final existing = _box.get(HiveKeys.deviceId);
    if (existing is String && existing.isNotEmpty) return existing;
    final id = _uuid.v4();
    await _box.put(HiveKeys.deviceId, id);
    return id;
  }

  /// After kiosk pair, use the server-assigned [deviceId] for attendance/sync.
  Future<void> applyPairedDeviceId(String deviceId) async {
    final id = deviceId.trim();
    if (id.isEmpty) return;
    await _box.put(HiveKeys.deviceId, id);
  }
}
