import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/api/kiosk_pair_api_urls.dart';
import 'package:attendance_kiosk_app/core/api/registration_api.dart';
import 'package:attendance_kiosk_app/core/api/registration_api_exception.dart';
import 'package:attendance_kiosk_app/core/branding/branding_asset_cache.dart';
import 'package:attendance_kiosk_app/core/device/device_id_service.dart';
import 'package:attendance_kiosk_app/core/config/attendance_mode.dart';
import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/features/employees/data/employee_snapshot_store.dart';
import 'package:attendance_kiosk_app/features/registration/data/datasources/kiosk_config_local_data_source.dart';
import 'package:attendance_kiosk_app/features/registration/data/models/kiosk_config_model.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_config.dart';
import 'package:attendance_kiosk_app/features/registration/domain/repositories/kiosk_config_repository.dart';

class KioskConfigRepositoryImpl implements KioskConfigRepository {
  KioskConfigRepositoryImpl(
    this._local,
    this._registrationApi, {
    BrandingAssetCache? brandingCache,
    DeviceIdService? deviceIdService,
    EmployeeSnapshotStore? employeeSnapshotStore,
  })  : _brandingCache = brandingCache ?? const BrandingAssetCache(),
        _deviceIdService = deviceIdService,
        _employeeSnapshotStore = employeeSnapshotStore;

  final KioskConfigLocalDataSource _local;
  final RegistrationApi _registrationApi;
  final BrandingAssetCache _brandingCache;
  final DeviceIdService? _deviceIdService;
  final EmployeeSnapshotStore? _employeeSnapshotStore;

  @override
  Future<Either<Failure, void>> save(KioskConfig config) async {
    try {
      final remote = await _registrationApi.registerDevice(config);
      if (!remote.success) {
        return Left(ValidationFailure(remote.message ?? 'Registration failed'));
      }

      final apiHost = KioskPairApiUrls.toApiHost(config.domain);
      final apiBaseUrl =
          remote.apiBaseUrl ?? (apiHost.isNotEmpty ? 'https://$apiHost' : null);
      final organization = remote.organization;
      final orgCode = _nonEmpty(organization?.subdomain) ?? config.code;
      final logoUrl = KioskPairApiUrls.resolveAssetUrl(remote.logoUrl, apiBaseUrl);

      final branding = await _brandingCache.persist(
        logoUrl: logoUrl,
        brandingImageUrl: null,
        orgCode: orgCode,
      );

      final registeredAtIso = remote.registeredAt?.toUtc().toIso8601String();
      final toStore = KioskConfig(
        code: orgCode,
        domain: apiHost.isNotEmpty ? apiHost : config.domain,
        machineName: _nonEmpty(remote.machineName) ?? config.machineName,
        description: _nonEmpty(remote.description) ?? config.description,
        adminName: remote.adminName ?? config.adminName,
        adminEmail: remote.adminEmail ?? config.adminEmail,
        adminPin: remote.adminPin ?? config.adminPin,
        logoPath: branding.logoPath,
        brandingImagePath: null,
        logoUrl: logoUrl,
        brandingImageUrl: null,
        organization: organization,
        attendanceMode: config.attendanceMode,
        deviceId: remote.deviceId,
        deviceIdentifier: remote.deviceIdentifier,
        deviceToken: remote.deviceToken,
        apiBaseUrl: apiBaseUrl,
        registeredAtIso: registeredAtIso,
      );

      final repaired = await _brandingCache.ensureLocalAssets(toStore);
      await _local.save(KioskConfigModel.fromEntity(repaired));

      final pairedDeviceId = remote.deviceId;
      if (pairedDeviceId != null && pairedDeviceId.isNotEmpty) {
        await _deviceIdService?.applyPairedDeviceId(pairedDeviceId);
      }

      final snapshotStore = _employeeSnapshotStore;
      if (snapshotStore != null) {
        try {
          final snapshotResult = await snapshotStore.fetchAndStoreForConfig(repaired);
          snapshotResult.fold(
            (failure) {
              if (kDebugMode) {
                debugPrint('[KioskPair] Employee snapshot: ${failure.message}');
              }
            },
            (count) {
              if (kDebugMode) {
                debugPrint('[KioskPair] Employee snapshot stored ($count employees)');
              }
            },
          );
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('[KioskPair] Employee snapshot error (pair still saved): $e\n$st');
          }
        }
      }

      return const Right(null);
    } on RegistrationApiException catch (e) {
      return Left(
        e.isNetworkError ? NetworkFailure(e.message) : ValidationFailure(e.message),
      );
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(NetworkFailure('Registration failed: $e'));
    }
  }

  static String? _nonEmpty(String? value) {
    final v = value?.trim();
    return v != null && v.isNotEmpty ? v : null;
  }

  @override
  Future<Either<Failure, KioskConfig?>> load() async {
    try {
      final model = await _local.load();
      if (model == null) return const Right(null);
      final entity = model.toEntity();
      final repaired = await _brandingCache.ensureLocalAssets(entity);
      if (repaired.logoPath != entity.logoPath ||
          repaired.brandingImagePath != entity.brandingImagePath) {
        await _local.save(KioskConfigModel.fromEntity(repaired));
      }
      return Right(repaired);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateAttendanceMode(AttendanceMode mode) async {
    try {
      final current = await _local.load();
      if (current == null) {
        return const Left(CacheFailure('Device is not registered'));
      }
      final entity = current.toEntity().copyWith(attendanceMode: mode);
      await _local.save(KioskConfigModel.fromEntity(entity));
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> hasConfig() async {
    try {
      return Right(await _local.hasConfig());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
