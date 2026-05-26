import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import 'package:attendance_kiosk_app/core/api/kiosk_device_credentials.dart';
import 'package:attendance_kiosk_app/core/api/registration_api_exception.dart';
import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/data/api/kiosk_bulk_events_api.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/data/datasources/kiosk_events_queue_local_data_source.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/data/kiosk_event_selfie_encoder.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/domain/entities/kiosk_queued_event.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/domain/repositories/kiosk_events_repository.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/kiosk_event_sync_status.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/kiosk_event_types.dart';
import 'package:attendance_kiosk_app/core/network/network_connectivity.dart';
import 'package:attendance_kiosk_app/core/sync/data/sync_metadata_local_data_source.dart';
import 'package:attendance_kiosk_app/features/registration/data/datasources/kiosk_config_local_data_source.dart';

class KioskEventsRepositoryImpl implements KioskEventsRepository {
  KioskEventsRepositoryImpl(
    this._queue,
    this._kioskConfig,
    this._bulkApi,
    this._connectivity, {
    KioskEventSelfieEncoder? selfieEncoder,
    SyncMetadataLocalDataSource? syncMetadata,
  })  : _selfieEncoder = selfieEncoder ?? const KioskEventSelfieEncoder(),
        _syncMetadata = syncMetadata;

  final KioskEventsQueueLocalDataSource _queue;
  final KioskConfigLocalDataSource _kioskConfig;
  final KioskBulkEventsApi _bulkApi;
  final NetworkConnectivity _connectivity;
  final KioskEventSelfieEncoder _selfieEncoder;
  final SyncMetadataLocalDataSource? _syncMetadata;

  static const _uuid = Uuid();
  static const _maxAttempts = 5;
  static const _batchSize = 25;

  bool _syncInProgress = false;

  @override
  Future<Either<Failure, void>> recordAttendanceEvent({
    required String attendanceLogId,
    required String employeeId,
    required bool isCheckOut,
    required String authMethod,
    required DateTime eventTime,
    String? photoPath,
  }) async {
    try {
      final enqueued = await _enqueueIfNeeded(
        attendanceLogId: attendanceLogId,
        employeeId: employeeId,
        isCheckOut: isCheckOut,
        authMethod: authMethod,
        eventTime: eventTime,
        photoPath: photoPath,
      );

      if (enqueued) {
        // Always attempt upload after check-in/out (connectivity_plus can be
        // false on iOS while Wi‑Fi still works).
        await syncPending(ignoreConnectivity: true);
      }
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> syncPending({bool ignoreConnectivity = false}) async {
    if (_syncInProgress) return const Right(0);
    _syncInProgress = true;
    try {
      if (!ignoreConnectivity && !await _connectivity.hasConnection()) {
        if (kDebugMode) {
          debugPrint('[KioskEvents] Sync skipped — no connectivity reported');
        }
        return const Right(0);
      }

      final configModel = await _kioskConfig.load();
      final creds = KioskDeviceCredentials.fromConfig(configModel?.toEntity());
      if (!creds.isValid) {
        if (kDebugMode) {
          debugPrint(
            '[KioskEvents] Sync skipped — device not paired '
            '(apiHost=${creds.apiHost.isEmpty ? "missing" : creds.apiHost}, '
            'token=${creds.deviceToken.isEmpty ? "missing" : "set"})',
          );
        }
        return const Right(0);
      }
      final apiHost = creds.apiHost;
      final token = creds.deviceToken;

      await _recoverStaleSyncing();

      var syncedTotal = 0;
      while (true) {
        final batch = await _nextSyncBatch();
        if (batch.isEmpty) break;

        final synced = await _uploadBatch(
          events: batch,
          apiHost: apiHost,
          deviceToken: token,
        );
        syncedTotal += synced;
        if (synced == 0) break;
      }

      if (syncedTotal > 0) {
        await _syncMetadata?.write(
          SyncMetadata(lastSyncAt: DateTime.now(), lastSyncError: null),
        );
      }
      return Right(syncedTotal);
    } on CacheException catch (e) {
      await _syncMetadata?.write(SyncMetadata(lastSyncError: e.message));
      return Left(CacheFailure(e.message));
    } catch (e) {
      await _syncMetadata?.write(SyncMetadata(lastSyncError: e.toString()));
      return Left(CacheFailure(e.toString()));
    } finally {
      _syncInProgress = false;
    }
  }

  @override
  Future<Either<Failure, int>> pendingCount() async {
    try {
      final all = await _queue.readAll();
      final count = all
          .where(
            (e) =>
                e.status == KioskEventSyncStatus.pending ||
                e.status == KioskEventSyncStatus.failed ||
                e.status == KioskEventSyncStatus.syncing,
          )
          .length;
      return Right(count);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, DateTime?>> lastSuccessfulSyncAt() async {
    try {
      final meta = await _syncMetadata?.read();
      return Right(meta?.lastSyncAt);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  /// Returns false when a duplicate suppressed a new queue entry.
  Future<bool> _enqueueIfNeeded({
    required String attendanceLogId,
    required String employeeId,
    required bool isCheckOut,
    required String authMethod,
    required DateTime eventTime,
    String? photoPath,
  }) async {
    final eventType = isCheckOut ? KioskEventTypes.checkOut : KioskEventTypes.checkIn;
    final all = await _queue.readAll();

    final duplicate = all.any(
      (e) =>
          e.attendanceLogId == attendanceLogId &&
          e.eventType == eventType &&
          (e.status == KioskEventSyncStatus.pending ||
              e.status == KioskEventSyncStatus.syncing ||
              e.status == KioskEventSyncStatus.synced),
    );
    if (duplicate) return false;

    final retryIndex = all.indexWhere(
      (e) =>
          e.attendanceLogId == attendanceLogId &&
          e.eventType == eventType &&
          e.status == KioskEventSyncStatus.failed,
    );

    if (retryIndex >= 0) {
      final existing = all[retryIndex];
      all[retryIndex] = existing.copyWith(
        status: KioskEventSyncStatus.pending,
        photoPath: photoPath ?? existing.photoPath,
        eventTimeDevice: eventTime,
        clearLastError: true,
      );
      await _queue.writeAll(all);
      return true;
    }

    all.add(
      KioskQueuedEvent(
        eventId: _uuid.v4(),
        attendanceLogId: attendanceLogId,
        employeeId: employeeId,
        eventType: eventType,
        authMethod: authMethod,
        eventTimeDevice: eventTime,
        createdAt: DateTime.now(),
        photoPath: photoPath,
      ),
    );
    await _queue.writeAll(all);
    if (kDebugMode) {
      debugPrint(
        '[KioskEvents] Queued $eventType for employee $employeeId '
        '(log $attendanceLogId)',
      );
    }
    return true;
  }

  Future<void> _recoverStaleSyncing() async {
    final all = await _queue.readAll();
    var changed = false;
    final updated = all.map((e) {
      if (e.status == KioskEventSyncStatus.syncing) {
        changed = true;
        return e.copyWith(status: KioskEventSyncStatus.pending);
      }
      return e;
    }).toList();
    if (changed) await _queue.writeAll(updated);
  }

  Future<List<KioskQueuedEvent>> _nextSyncBatch() async {
    final all = await _queue.readAll();
    final eligible = all
        .where(
          (e) =>
              e.status.isEligibleForSync && e.attempts < _maxAttempts,
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return eligible.take(_batchSize).toList();
  }

  Future<int> _uploadBatch({
    required List<KioskQueuedEvent> events,
    required String apiHost,
    required String deviceToken,
  }) async {
    if (events.isEmpty) return 0;

    final all = await _queue.readAll();
    final eventIds = events.map((e) => e.eventId).toSet();
    final marked = all.map((e) {
      if (eventIds.contains(e.eventId)) {
        return e.copyWith(status: KioskEventSyncStatus.syncing, clearLastError: true);
      }
      return e;
    }).toList();
    await _queue.writeAll(marked);

    try {
      final uploads = <KioskBulkEventUpload>[];
      for (final event in events) {
        final selfie = await _selfieEncoder.encodeFile(event.photoPath);
        uploads.add(
          KioskBulkEventUpload(
            eventId: event.eventId,
            payloadJson: {
              'employeeId': event.employeeId,
              'eventType': event.eventType,
              'selfie': selfie,
              'authMethod': event.authMethod,
              'eventTimeDevice': event.eventTimeDevice.toUtc().toIso8601String(),
            },
          ),
        );
      }

      await _bulkApi.postBulk(
        apiHost: apiHost,
        deviceToken: deviceToken,
        events: uploads,
      );

      final afterSuccess = await _queue.readAll();
      final remaining = afterSuccess
          .where((e) => !eventIds.contains(e.eventId))
          .toList();
      await _queue.writeAll(remaining);
      return events.length;
    } on RegistrationApiException catch (e) {
      await _markBatchFailed(events, e.message, isNetwork: e.isNetworkError);
      return 0;
    } catch (e) {
      await _markBatchFailed(events, e.toString(), isNetwork: true);
      return 0;
    }
  }

  Future<void> _markBatchFailed(
    List<KioskQueuedEvent> events,
    String message, {
    required bool isNetwork,
  }) async {
    final ids = events.map((e) => e.eventId).toSet();
    final all = await _queue.readAll();
    final updated = all.map((e) {
      if (!ids.contains(e.eventId)) return e;
      final attempts = e.attempts + 1;
      return e.copyWith(
        status: KioskEventSyncStatus.failed,
        attempts: attempts,
        lastError: message,
      );
    }).toList();
    await _queue.writeAll(updated);

    if (kDebugMode) {
      debugPrint(
        '[KioskEvents] Batch failed (${events.length} events): $message',
      );
    }
  }
}
