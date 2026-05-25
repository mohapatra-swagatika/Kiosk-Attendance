import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/api/kiosk_employee_snapshot_api.dart';
import 'package:attendance_kiosk_app/core/api/registration_api_exception.dart';
import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/employee_repository.dart';
import 'package:attendance_kiosk_app/features/employees/domain/utils/employee_image_url.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/face_repository.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_config.dart';

/// Persists employee snapshot (roster + face templates) after kiosk pair.
class EmployeeSnapshotStore {
  const EmployeeSnapshotStore(
    this._snapshotApi,
    this._employees,
    this._faces,
  );

  final KioskEmployeeSnapshotApi _snapshotApi;
  final EmployeeRepository _employees;
  final FaceRepository _faces;

  Future<Either<Failure, int>> fetchAndStoreForConfig(KioskConfig config) async {
    final deviceId = config.deviceId?.trim() ?? '';
    final deviceToken = config.deviceToken?.trim() ?? '';
    final apiHost = _apiHost(config);
    if (deviceId.isEmpty || deviceToken.isEmpty || apiHost.isEmpty) {
      return const Left(
        ValidationFailure('Device credentials missing — employee snapshot skipped'),
      );
    }

    try {
      final snapshot = await _snapshotApi.fetchSnapshot(
        apiHost: apiHost,
        deviceId: deviceId,
        deviceToken: deviceToken,
      );
      final apiBase = config.apiBaseUrl ?? 'https://$apiHost';
      final resolved = EmployeeSnapshotData(
        employees: snapshot.employees
            .map(
              (e) => e.copyWith(
                imageUrl: resolveEmployeeImageUrl(e.imageUrl, apiBaseUrl: apiBase),
              ),
            )
            .toList(),
        faceProfiles: snapshot.faceProfiles,
      );
      return applySnapshot(resolved);
    } on RegistrationApiException catch (e) {
      return Left(
        e.isNetworkError ? NetworkFailure(e.message) : ValidationFailure(e.message),
      );
    } catch (e) {
      return Left(NetworkFailure('Employee snapshot failed: $e'));
    }
  }

  Future<Either<Failure, int>> applySnapshot(EmployeeSnapshotData snapshot) async {
    final mergedEmployees = snapshot.employees
        .map(
          (e) => e.copyWith(
            faceRegistered: snapshot.faceProfiles.containsKey(e.id) || e.faceRegistered,
          ),
        )
        .toList();

    final replaceResult = await _employees.replaceAll(mergedEmployees);
    if (replaceResult.isLeft()) return replaceResult.map((_) => 0);

    final galleryResult = await _faces.importServerGallery(snapshot.faceProfiles);
    return galleryResult.fold(
      Left.new,
      (count) {
        if (kDebugMode) {
          debugPrint(
            'EmployeeSnapshotStore: ${mergedEmployees.length} employees, '
            '$count face profiles',
          );
        }
        return Right(mergedEmployees.length);
      },
    );
  }

  static String _apiHost(KioskConfig config) {
    final base = config.apiBaseUrl?.trim();
    if (base != null && base.isNotEmpty) {
      return base.replaceFirst(RegExp(r'^https?://'), '').split('/').first;
    }
    return config.domain.trim();
  }
}
