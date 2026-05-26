import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee_sync_result.dart';

abstract class EmployeeSyncMetadataLocalDataSource {
  Future<EmployeeSyncMetadata> read();
  Future<void> write(EmployeeSyncMetadata metadata);
}

class EmployeeSyncMetadataLocalDataSourceImpl
    implements EmployeeSyncMetadataLocalDataSource {
  EmployeeSyncMetadataLocalDataSourceImpl(this._box);

  final Box<dynamic> _box;

  @override
  Future<EmployeeSyncMetadata> read() async {
    try {
      final raw = _box.get(HiveKeys.employeeSyncMetadata);
      if (raw is! String || raw.isEmpty) return const EmployeeSyncMetadata();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return EmployeeSyncMetadata(
        lastSyncedAt: DateTime.tryParse(map['lastSyncedAt'] as String? ?? ''),
        lastEmployeeCount: map['lastEmployeeCount'] as int?,
        lastError: map['lastError'] as String?,
      );
    } catch (e) {
      throw CacheException('Failed to read employee sync metadata: $e');
    }
  }

  @override
  Future<void> write(EmployeeSyncMetadata metadata) async {
    try {
      await _box.put(
        HiveKeys.employeeSyncMetadata,
        jsonEncode({
          'lastSyncedAt': metadata.lastSyncedAt?.toUtc().toIso8601String(),
          'lastEmployeeCount': metadata.lastEmployeeCount,
          'lastError': metadata.lastError,
        }),
      );
    } catch (e) {
      throw CacheException('Failed to write employee sync metadata: $e');
    }
  }
}
