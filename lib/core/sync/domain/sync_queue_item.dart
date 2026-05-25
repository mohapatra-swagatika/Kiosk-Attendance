import 'package:equatable/equatable.dart';

import 'package:attendance_kiosk_app/core/sync/sync_status.dart';

/// Outbox entry flushed to the server when online (mock API for now).
class SyncQueueItem extends Equatable {
  const SyncQueueItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.status = SyncStatus.pending,
    this.attempts = 0,
  });

  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final SyncStatus status;
  final int attempts;

  SyncQueueItem copyWith({
    SyncStatus? status,
    int? attempts,
  }) {
    return SyncQueueItem(
      id: id,
      type: type,
      payload: payload,
      createdAt: createdAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
    );
  }

  @override
  List<Object?> get props => [id, type, payload, createdAt, status, attempts];
}

abstract final class SyncQueueTypes {
  static const attendanceCheckIn = 'attendance_check_in';
  static const attendanceCheckOut = 'attendance_check_out';
}
