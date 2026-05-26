import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/api/kiosk_device_credentials.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_employee_snapshot_api.dart';
import 'package:attendance_kiosk_app/core/api/registration_api_exception.dart';
import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/features/employees/data/datasources/employee_sync_metadata_local_data_source.dart';
import 'package:attendance_kiosk_app/features/employees/data/datasources/employee_sync_remote_data_source.dart';
import 'package:attendance_kiosk_app/features/employees/data/employee_snapshot_store.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee_sync_result.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/employee_sync_repository.dart';
import 'package:attendance_kiosk_app/features/employees/domain/utils/employee_image_url.dart';
import 'package:attendance_kiosk_app/features/registration/data/datasources/kiosk_config_local_data_source.dart';
import 'package:attendance_kiosk_app/features/registration/data/models/kiosk_config_model.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_organization.dart';

class EmployeeSyncRepositoryImpl implements EmployeeSyncRepository {
  EmployeeSyncRepositoryImpl(
    this._configLocal,
    this._remote,
    this._snapshotStore,
    this._metadataLocal,
  );

  final KioskConfigLocalDataSource _configLocal;
  final EmployeeSyncRemoteDataSource _remote;
  final EmployeeSnapshotStore _snapshotStore;
  final EmployeeSyncMetadataLocalDataSource _metadataLocal;

  static const _maxAttempts = 3;
  static const _retryDelays = [
    Duration(milliseconds: 400),
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  @override
  Future<Either<Failure, EmployeeSyncMetadata>> getSyncMetadata() async {
    try {
      return Right(await _metadataLocal.read());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, EmployeeSyncResult>> syncEmployeesFromServer() async {
    try {
      final configModel = await _configLocal.load();
      final config = configModel?.toEntity();
      final deviceId = config?.deviceId?.trim() ?? '';
      final creds = KioskDeviceCredentials.fromConfig(config);
      if (deviceId.isEmpty || !creds.isValid) {
        return const Left(
          ValidationFailure(
            'Device is not paired — register the kiosk before syncing employees.',
          ),
        );
      }

      Failure? lastFailure;

      for (var attempt = 0; attempt < _maxAttempts; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(_retryDelays[attempt - 1]);
          if (kDebugMode) {
            debugPrint('[EmployeeSync] Retry ${attempt + 1}/$_maxAttempts');
          }
        }

        try {
          final payload = await _remote.fetchSyncPayload(
            apiHost: creds.apiHost,
            deviceId: deviceId,
            deviceToken: creds.deviceToken,
          );

          final apiBase = config?.apiBaseUrl ?? 'https://${creds.apiHost}';
          final resolved = EmployeeSnapshotData(
            employees: payload.employees
                .map(
                  (e) => e.copyWith(
                    imageUrl: resolveEmployeeImageUrl(
                      e.imageUrl,
                      apiBaseUrl: apiBase,
                    ),
                  ),
                )
                .toList(),
            faceProfiles: payload.faceProfiles,
            organization: payload.organization,
          );

          await Future<void>.delayed(Duration.zero);

          await _mergeOrganizationBranding(resolved.organization);

          final applyResult = await _snapshotStore.applySnapshot(resolved);
          if (applyResult.isLeft()) {
            final failure = applyResult.getLeft().toNullable()!;
            lastFailure = failure;
            if (failure is NetworkFailure && attempt < _maxAttempts - 1) {
              continue;
            }
            return Left(failure);
          }

          final count = applyResult.getOrElse((_) => 0);
          final syncedAt = DateTime.now();
          final result = EmployeeSyncResult(
            employeeCount: count,
            faceProfileCount: resolved.faceProfiles.length,
            syncedAt: syncedAt,
          );
          await _metadataLocal.write(
            EmployeeSyncMetadata(
              lastSyncedAt: syncedAt,
              lastEmployeeCount: count,
            ),
          );
          if (kDebugMode) {
            debugPrint(
              '[EmployeeSync] Stored $count employees, '
              '${result.faceProfileCount} face profiles',
            );
          }
          return Right(result);
        } on RegistrationApiException catch (e) {
          lastFailure = e.isNetworkError
              ? NetworkFailure(e.message)
              : ValidationFailure(e.message);
          if (!e.isNetworkError) return Left(lastFailure);
        } on CacheException catch (e) {
          lastFailure = CacheFailure(e.message);
          if (!_shouldRetryMessage(e.message)) return Left(lastFailure);
        } catch (e) {
          lastFailure = NetworkFailure(e.toString());
        }
      }

      final message = lastFailure?.message ?? 'Employee sync failed';
      final prior = await _metadataLocal.read();
      await _metadataLocal.write(
        EmployeeSyncMetadata(
          lastSyncedAt: prior.lastSyncedAt,
          lastEmployeeCount: prior.lastEmployeeCount,
          lastError: message,
        ),
      );
      return Left(lastFailure ?? NetworkFailure(message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  Future<void> _mergeOrganizationBranding(KioskOrganization? organization) async {
    if (organization == null) return;

    final current = await _configLocal.load();
    if (current == null) return;

    await _configLocal.save(
      KioskConfigModel.fromEntity(
        current.toEntity().copyWith(organization: organization),
      ),
    );
    if (kDebugMode) {
      debugPrint(
        '[EmployeeSync] Updated branding: ${organization.companyName ?? organization.displayName}',
      );
    }
  }

  bool _shouldRetryMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('network') ||
        lower.contains('socket');
  }
}
