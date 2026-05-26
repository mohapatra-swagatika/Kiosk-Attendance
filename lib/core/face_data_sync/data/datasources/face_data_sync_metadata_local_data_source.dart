import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';

class FaceDataSyncMetadata {
  const FaceDataSyncMetadata({this.lastSyncAt, this.lastSyncError});

  final DateTime? lastSyncAt;
  final String? lastSyncError;
}

abstract class FaceDataSyncMetadataLocalDataSource {
  Future<FaceDataSyncMetadata> read();
  Future<void> write(FaceDataSyncMetadata metadata);
}

class FaceDataSyncMetadataLocalDataSourceImpl
    implements FaceDataSyncMetadataLocalDataSource {
  FaceDataSyncMetadataLocalDataSourceImpl(this._box);

  final Box<dynamic> _box;

  @override
  Future<FaceDataSyncMetadata> read() async {
    try {
      final raw = _box.get(HiveKeys.faceDataSyncMetadata);
      if (raw is! String || raw.isEmpty) return const FaceDataSyncMetadata();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return FaceDataSyncMetadata(
        lastSyncAt: DateTime.tryParse(json['lastSyncAt'] as String? ?? ''),
        lastSyncError: json['lastSyncError'] as String?,
      );
    } catch (e) {
      throw CacheException('Failed to read face data sync metadata: $e');
    }
  }

  @override
  Future<void> write(FaceDataSyncMetadata metadata) async {
    try {
      await _box.put(
        HiveKeys.faceDataSyncMetadata,
        jsonEncode({
          if (metadata.lastSyncAt != null)
            'lastSyncAt': metadata.lastSyncAt!.toUtc().toIso8601String(),
          'lastSyncError': metadata.lastSyncError,
        }),
      );
    } catch (e) {
      throw CacheException('Failed to write face data sync metadata: $e');
    }
  }
}
