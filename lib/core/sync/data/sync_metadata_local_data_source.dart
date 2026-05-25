import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';

class SyncMetadata {
  const SyncMetadata({this.lastSyncAt, this.lastSyncError});

  final DateTime? lastSyncAt;
  final String? lastSyncError;
}

abstract class SyncMetadataLocalDataSource {
  Future<SyncMetadata> read();
  Future<void> write(SyncMetadata metadata);
}

class SyncMetadataLocalDataSourceImpl implements SyncMetadataLocalDataSource {
  SyncMetadataLocalDataSourceImpl(this._box);

  final Box<dynamic> _box;

  @override
  Future<SyncMetadata> read() async {
    try {
      final raw = _box.get(HiveKeys.syncMetadata);
      if (raw is! String || raw.isEmpty) return const SyncMetadata();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SyncMetadata(
        lastSyncAt: DateTime.tryParse(map['lastSyncAt'] as String? ?? ''),
        lastSyncError: map['lastSyncError'] as String?,
      );
    } catch (e) {
      throw CacheException('Failed to read sync metadata: $e');
    }
  }

  @override
  Future<void> write(SyncMetadata metadata) async {
    try {
      await _box.put(
        HiveKeys.syncMetadata,
        jsonEncode({
          'lastSyncAt': metadata.lastSyncAt?.toIso8601String(),
          'lastSyncError': metadata.lastSyncError,
        }),
      );
    } catch (e) {
      throw CacheException('Failed to write sync metadata: $e');
    }
  }
}
