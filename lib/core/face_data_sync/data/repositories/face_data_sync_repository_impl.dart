import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import 'package:attendance_kiosk_app/core/api/kiosk_device_credentials.dart';
import 'package:attendance_kiosk_app/core/api/registration_api_exception.dart';
import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/data/api/kiosk_face_data_api.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/data/datasources/face_data_queue_local_data_source.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/data/datasources/face_data_sync_metadata_local_data_source.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/data/face_data_payload_codec.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/domain/entities/queued_face_data.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/domain/repositories/face_data_sync_repository.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/kiosk_event_sync_status.dart';
import 'package:attendance_kiosk_app/core/network/network_connectivity.dart';
import 'package:attendance_kiosk_app/features/registration/data/datasources/kiosk_config_local_data_source.dart';

class FaceDataSyncRepositoryImpl implements FaceDataSyncRepository {
  FaceDataSyncRepositoryImpl(
    this._queue,
    this._kioskConfig,
    this._faceDataApi,
    this._connectivity,
    this._metadata,
  );

  final FaceDataQueueLocalDataSource _queue;
  final KioskConfigLocalDataSource _kioskConfig;
  final KioskFaceDataApi _faceDataApi;
  final NetworkConnectivity _connectivity;
  final FaceDataSyncMetadataLocalDataSource _metadata;

  static const _uuid = Uuid();
  static const _maxAttempts = 5;

  bool _syncInProgress = false;

  @override
  Future<Either<Failure, bool>> enqueueAndSync({
    required String employeeId,
    required Map<String, dynamic> faceDataJson,
  }) async {
    try {
      final enqueued = await _enqueue(
        employeeId: employeeId,
        faceDataJson: faceDataJson,
      );
      final isClear = FaceDataPayloadCodec.isClearPayload(faceDataJson);
      if (enqueued || isClear) {
        await syncPending(ignoreConnectivity: true);
      }
      return Right(enqueued);
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
          debugPrint('[FaceDataSync] Sync skipped — no connectivity reported');
        }
        return const Right(0);
      }

      final configModel = await _kioskConfig.load();
      final config = configModel?.toEntity();
      final creds = KioskDeviceCredentials.fromConfig(config);
      final deviceId = config?.deviceId?.trim() ?? '';
      if (!creds.isValid || deviceId.isEmpty) {
        if (kDebugMode) {
          debugPrint('[FaceDataSync] Sync skipped — device not paired');
        }
        return const Right(0);
      }

      await _recoverStaleSyncing();

      var syncedTotal = 0;
      while (true) {
        final next = await _nextItem();
        if (next == null) break;

        final ok = await _uploadOne(
          item: next,
          apiHost: creds.apiHost,
          deviceId: deviceId,
          deviceToken: creds.deviceToken,
        );
        if (!ok) break;
        syncedTotal++;
      }

      if (syncedTotal > 0) {
        await _metadata.write(
          FaceDataSyncMetadata(lastSyncAt: DateTime.now(), lastSyncError: null),
        );
      }
      return Right(syncedTotal);
    } on CacheException catch (e) {
      await _metadata.write(FaceDataSyncMetadata(lastSyncError: e.message));
      return Left(CacheFailure(e.message));
    } catch (e) {
      await _metadata.write(FaceDataSyncMetadata(lastSyncError: e.toString()));
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
      final meta = await _metadata.read();
      return Right(meta.lastSyncAt);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> enqueueClearAndSync({
    required String employeeId,
  }) =>
      enqueueAndSync(
        employeeId: employeeId,
        faceDataJson: Map<String, dynamic>.from(FaceDataPayloadCodec.clearedFaceData),
      );

  @override
  Future<Either<Failure, void>> removePendingForEmployee(String employeeId) async {
    try {
      final id = employeeId.trim();
      final all = await _queue.readAll();
      final remaining = all
          .where(
            (e) =>
                e.employeeId != id ||
                e.status == KioskEventSyncStatus.syncing,
          )
          .toList();
      if (remaining.length != all.length) {
        await _queue.writeAll(remaining);
      }
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  Future<bool> _enqueue({
    required String employeeId,
    required Map<String, dynamic> faceDataJson,
  }) async {
    final empId = employeeId.trim();
    final hash = FaceDataPayloadCodec.contentHash(faceDataJson);
    final all = await _queue.readAll();

    final isClear = FaceDataPayloadCodec.isClearPayload(faceDataJson);
    final duplicate = all.any(
      (e) =>
          e.employeeId == empId &&
          e.contentHash == hash &&
          (e.status == KioskEventSyncStatus.pending ||
              e.status == KioskEventSyncStatus.syncing ||
              e.status == KioskEventSyncStatus.synced),
    );
    if (duplicate) {
      if (kDebugMode) {
        debugPrint('[FaceDataSync] Duplicate suppressed for $empId');
      }
      return false;
    }

    // Replacing a pending enroll with a clear must not be treated as duplicate.
    if (isClear) {
      final pendingEnrollIndex = all.indexWhere(
        (e) =>
            e.employeeId == empId &&
            !FaceDataPayloadCodec.isClearPayload(e.faceDataJson) &&
            (e.status == KioskEventSyncStatus.pending ||
                e.status == KioskEventSyncStatus.failed),
      );
      if (pendingEnrollIndex >= 0) {
        all[pendingEnrollIndex] = all[pendingEnrollIndex].copyWith(
          status: KioskEventSyncStatus.pending,
          faceDataJson: faceDataJson,
          contentHash: hash,
          clearLastError: true,
        );
        await _queue.writeAll(all);
        if (kDebugMode) {
          debugPrint('[FaceDataSync] Replaced pending enroll with clear for $empId');
        }
        return true;
      }
    }

    final failedIndex = all.indexWhere(
      (e) =>
          e.employeeId == empId &&
          e.status == KioskEventSyncStatus.failed,
    );
    if (failedIndex >= 0) {
      all[failedIndex] = all[failedIndex].copyWith(
        status: KioskEventSyncStatus.pending,
        faceDataJson: faceDataJson,
        contentHash: hash,
        clearLastError: true,
      );
      await _queue.writeAll(all);
      if (kDebugMode) {
        debugPrint('[FaceDataSync] Re-queued failed upload for $empId');
      }
      return true;
    }

    final pendingSameEmployee = all.indexWhere(
      (e) =>
          e.employeeId == empId &&
          (e.status == KioskEventSyncStatus.pending ||
              e.status == KioskEventSyncStatus.syncing),
    );
    if (pendingSameEmployee >= 0) {
      all[pendingSameEmployee] = all[pendingSameEmployee].copyWith(
        faceDataJson: faceDataJson,
        contentHash: hash,
        status: KioskEventSyncStatus.pending,
        clearLastError: true,
      );
      await _queue.writeAll(all);
      if (kDebugMode) {
        debugPrint('[FaceDataSync] Updated pending upload for $empId');
      }
      return true;
    }

    all.add(
      QueuedFaceData(
        queueId: _uuid.v4(),
        employeeId: empId,
        contentHash: hash,
        faceDataJson: Map<String, dynamic>.from(faceDataJson),
        createdAt: DateTime.now(),
      ),
    );
    await _queue.writeAll(all);
    if (kDebugMode) {
      debugPrint(
        isClear
            ? '[FaceDataSync] Queued face data clear for $empId'
            : '[FaceDataSync] Queued face data for $empId',
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

  Future<QueuedFaceData?> _nextItem() async {
    final all = await _queue.readAll();
    final eligible = all
        .where(
          (e) => e.status.isEligibleForSync && e.attempts < _maxAttempts,
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return eligible.isEmpty ? null : eligible.first;
  }

  Future<bool> _uploadOne({
    required QueuedFaceData item,
    required String apiHost,
    required String deviceId,
    required String deviceToken,
  }) async {
    final all = await _queue.readAll();
    final marked = all.map((e) {
      if (e.queueId == item.queueId) {
        return e.copyWith(status: KioskEventSyncStatus.syncing, clearLastError: true);
      }
      return e;
    }).toList();
    await _queue.writeAll(marked);

    try {
      await _faceDataApi.uploadFaceData(
        apiHost: apiHost,
        deviceId: deviceId,
        deviceToken: deviceToken,
        employeeId: item.employeeId,
        faceDataJson: item.faceDataJson,
      );

      final after = await _queue.readAll();
      final remaining =
          after.where((e) => e.queueId != item.queueId).toList();
      await _queue.writeAll(remaining);
      if (kDebugMode) {
        debugPrint('[FaceDataSync] Uploaded face data for ${item.employeeId}');
      }
      return true;
    } on RegistrationApiException catch (e) {
      await _markFailed(item, e.message);
      return false;
    } catch (e) {
      await _markFailed(item, e.toString());
      return false;
    }
  }

  Future<void> _markFailed(QueuedFaceData item, String message) async {
    final all = await _queue.readAll();
    final updated = all.map((e) {
      if (e.queueId != item.queueId) return e;
      return e.copyWith(
        status: KioskEventSyncStatus.failed,
        attempts: e.attempts + 1,
        lastError: message,
      );
    }).toList();
    await _queue.writeAll(updated);
    if (kDebugMode) {
      debugPrint('[FaceDataSync] Upload failed for ${item.employeeId}: $message');
    }
  }
}
