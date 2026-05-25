import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';
import 'package:attendance_kiosk_app/core/sync/domain/sync_queue_item.dart';
import 'package:attendance_kiosk_app/core/sync/sync_status.dart';

abstract class SyncQueueLocalDataSource {
  Future<List<SyncQueueItem>> readAll();
  Future<void> writeAll(List<SyncQueueItem> items);
  Future<void> enqueue(SyncQueueItem item);
}

class SyncQueueLocalDataSourceImpl implements SyncQueueLocalDataSource {
  SyncQueueLocalDataSourceImpl(this._box);

  final Box<dynamic> _box;

  @override
  Future<List<SyncQueueItem>> readAll() async {
    try {
      final raw = _box.get(HiveKeys.syncQueue);
      if (raw is! String || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => _fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw CacheException('Failed to read sync queue: $e');
    }
  }

  @override
  Future<void> writeAll(List<SyncQueueItem> items) async {
    try {
      await _box.put(
        HiveKeys.syncQueue,
        jsonEncode(items.map(_toJson).toList()),
      );
    } catch (e) {
      throw CacheException('Failed to write sync queue: $e');
    }
  }

  @override
  Future<void> enqueue(SyncQueueItem item) async {
    final all = await readAll();
    all.add(item);
    await writeAll(all);
  }

  static Map<String, dynamic> _toJson(SyncQueueItem item) => {
        'id': item.id,
        'type': item.type,
        'payload': item.payload,
        'createdAt': item.createdAt.toIso8601String(),
        'status': item.status.value,
        'attempts': item.attempts,
      };

  static SyncQueueItem _fromJson(Map<String, dynamic> json) => SyncQueueItem(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        status: SyncStatus.fromValue(json['status'] as String?),
        attempts: json['attempts'] as int? ?? 0,
      );
}
