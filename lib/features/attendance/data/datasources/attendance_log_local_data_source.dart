import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';
import 'package:attendance_kiosk_app/features/attendance/data/models/attendance_log_model.dart';

abstract class AttendanceLogLocalDataSource {
  Future<List<AttendanceLogModel>> readAll();
  Future<void> writeAll(List<AttendanceLogModel> logs);
}

class AttendanceLogLocalDataSourceImpl implements AttendanceLogLocalDataSource {
  AttendanceLogLocalDataSourceImpl(this._box);

  final Box<dynamic> _box;

  @override
  Future<List<AttendanceLogModel>> readAll() async {
    try {
      final raw = _box.get(HiveKeys.attendanceLogs);
      if (raw is! String || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AttendanceLogModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw CacheException('Failed to read attendance logs: $e');
    }
  }

  @override
  Future<void> writeAll(List<AttendanceLogModel> logs) async {
    try {
      final encoded = jsonEncode(logs.map((m) => m.toJson()).toList());
      await _box.put(HiveKeys.attendanceLogs, encoded);
    } catch (e) {
      throw CacheException('Failed to write attendance logs: $e');
    }
  }
}
