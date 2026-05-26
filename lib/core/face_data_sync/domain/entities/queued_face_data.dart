import 'package:equatable/equatable.dart';

import 'package:attendance_kiosk_app/core/kiosk_events/kiosk_event_sync_status.dart';

/// Locally persisted face enrollment awaiting upload to the server.
class QueuedFaceData extends Equatable {
  const QueuedFaceData({
    required this.queueId,
    required this.employeeId,
    required this.contentHash,
    required this.faceDataJson,
    required this.createdAt,
    this.status = KioskEventSyncStatus.pending,
    this.attempts = 0,
    this.lastError,
  });

  final String queueId;
  final String employeeId;

  /// SHA-256 of canonical JSON — dedupe guard.
  final String contentHash;
  final Map<String, dynamic> faceDataJson;
  final DateTime createdAt;
  final KioskEventSyncStatus status;
  final int attempts;
  final String? lastError;

  QueuedFaceData copyWith({
    KioskEventSyncStatus? status,
    int? attempts,
    String? lastError,
    bool clearLastError = false,
    Map<String, dynamic>? faceDataJson,
    String? contentHash,
  }) {
    return QueuedFaceData(
      queueId: queueId,
      employeeId: employeeId,
      contentHash: contentHash ?? this.contentHash,
      faceDataJson: faceDataJson ?? this.faceDataJson,
      createdAt: createdAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => [
        queueId,
        employeeId,
        contentHash,
        faceDataJson,
        createdAt,
        status,
        attempts,
        lastError,
      ];
}
