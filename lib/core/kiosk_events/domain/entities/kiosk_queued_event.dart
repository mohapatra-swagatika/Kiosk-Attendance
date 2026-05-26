import 'package:equatable/equatable.dart';

import 'package:attendance_kiosk_app/core/kiosk_events/kiosk_event_sync_status.dart';

/// Locally persisted kiosk attendance event awaiting bulk upload.
class KioskQueuedEvent extends Equatable {
  const KioskQueuedEvent({
    required this.eventId,
    required this.attendanceLogId,
    required this.employeeId,
    required this.eventType,
    required this.authMethod,
    required this.eventTimeDevice,
    required this.createdAt,
    this.photoPath,
    this.status = KioskEventSyncStatus.pending,
    this.attempts = 0,
    this.lastError,
  });

  final String eventId;
  final String attendanceLogId;
  final String employeeId;
  final String eventType;
  final String authMethod;
  final DateTime eventTimeDevice;
  final DateTime createdAt;
  final String? photoPath;
  final KioskEventSyncStatus status;
  final int attempts;
  final String? lastError;

  KioskQueuedEvent copyWith({
    KioskEventSyncStatus? status,
    int? attempts,
    String? lastError,
    bool clearLastError = false,
    String? photoPath,
    DateTime? eventTimeDevice,
  }) {
    return KioskQueuedEvent(
      eventId: eventId,
      attendanceLogId: attendanceLogId,
      employeeId: employeeId,
      eventType: eventType,
      authMethod: authMethod,
      eventTimeDevice: eventTimeDevice ?? this.eventTimeDevice,
      createdAt: createdAt,
      photoPath: photoPath ?? this.photoPath,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => [
        eventId,
        attendanceLogId,
        employeeId,
        eventType,
        authMethod,
        eventTimeDevice,
        createdAt,
        photoPath,
        status,
        attempts,
        lastError,
      ];
}
