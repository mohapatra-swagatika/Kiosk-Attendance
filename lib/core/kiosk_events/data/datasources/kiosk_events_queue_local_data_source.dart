import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/domain/entities/kiosk_queued_event.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/kiosk_event_sync_status.dart';
import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';

abstract class KioskEventsQueueLocalDataSource {
  Future<List<KioskQueuedEvent>> readAll();
  Future<void> writeAll(List<KioskQueuedEvent> events);
}

class KioskEventsQueueLocalDataSourceImpl implements KioskEventsQueueLocalDataSource {
  KioskEventsQueueLocalDataSourceImpl(this._box);

  final Box<dynamic> _box;

  @override
  Future<List<KioskQueuedEvent>> readAll() async {
    try {
      final raw = _box.get(HiveKeys.kioskEventsQueue);
      if (raw is! String || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => _fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw CacheException('Failed to read kiosk events queue: $e');
    }
  }

  @override
  Future<void> writeAll(List<KioskQueuedEvent> events) async {
    try {
      await _box.put(
        HiveKeys.kioskEventsQueue,
        jsonEncode(events.map(_toJson).toList()),
      );
    } catch (e) {
      throw CacheException('Failed to write kiosk events queue: $e');
    }
  }

  static Map<String, dynamic> _toJson(KioskQueuedEvent event) => {
        'eventId': event.eventId,
        'attendanceLogId': event.attendanceLogId,
        'employeeId': event.employeeId,
        'eventType': event.eventType,
        'authMethod': event.authMethod,
        'eventTimeDevice': event.eventTimeDevice.toUtc().toIso8601String(),
        'createdAt': event.createdAt.toUtc().toIso8601String(),
        'photoPath': event.photoPath,
        'status': event.status.value,
        'attempts': event.attempts,
        'lastError': event.lastError,
      };

  static KioskQueuedEvent _fromJson(Map<String, dynamic> json) => KioskQueuedEvent(
        eventId: json['eventId'] as String? ?? '',
        attendanceLogId: json['attendanceLogId'] as String? ?? '',
        employeeId: json['employeeId'] as String? ?? '',
        eventType: json['eventType'] as String? ?? '',
        authMethod: json['authMethod'] as String? ?? '',
        eventTimeDevice: DateTime.tryParse(json['eventTimeDevice'] as String? ?? '') ??
            DateTime.now(),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        photoPath: json['photoPath'] as String?,
        status: KioskEventSyncStatus.fromValue(json['status'] as String?),
        attempts: json['attempts'] as int? ?? 0,
        lastError: json['lastError'] as String?,
      );
}
