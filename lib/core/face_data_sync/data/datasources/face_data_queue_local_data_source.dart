import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/domain/entities/queued_face_data.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/kiosk_event_sync_status.dart';
import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';

abstract class FaceDataQueueLocalDataSource {
  Future<List<QueuedFaceData>> readAll();
  Future<void> writeAll(List<QueuedFaceData> items);
}

class FaceDataQueueLocalDataSourceImpl implements FaceDataQueueLocalDataSource {
  FaceDataQueueLocalDataSourceImpl(this._box);

  final Box<dynamic> _box;

  @override
  Future<List<QueuedFaceData>> readAll() async {
    try {
      final raw = _box.get(HiveKeys.faceDataSyncQueue);
      if (raw is! String || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => _fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw CacheException('Failed to read face data queue: $e');
    }
  }

  @override
  Future<void> writeAll(List<QueuedFaceData> items) async {
    try {
      await _box.put(
        HiveKeys.faceDataSyncQueue,
        jsonEncode(items.map(_toJson).toList()),
      );
    } catch (e) {
      throw CacheException('Failed to write face data queue: $e');
    }
  }

  static Map<String, dynamic> _toJson(QueuedFaceData item) => {
        'queueId': item.queueId,
        'employeeId': item.employeeId,
        'contentHash': item.contentHash,
        'faceDataJson': item.faceDataJson,
        'createdAt': item.createdAt.toUtc().toIso8601String(),
        'status': item.status.value,
        'attempts': item.attempts,
        'lastError': item.lastError,
      };

  static QueuedFaceData _fromJson(Map<String, dynamic> json) {
    final faceRaw = json['faceDataJson'];
    final faceMap = faceRaw is Map
        ? Map<String, dynamic>.from(faceRaw)
        : <String, dynamic>{};

    return QueuedFaceData(
      queueId: json['queueId'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      contentHash: json['contentHash'] as String? ?? '',
      faceDataJson: faceMap,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      status: KioskEventSyncStatus.fromValue(json['status'] as String?),
      attempts: json['attempts'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );
  }
}
