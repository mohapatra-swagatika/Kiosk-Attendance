import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/api/employee_snapshot_parser.dart';
import 'package:attendance_kiosk_app/core/api/face_profile_parser.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_device_credentials.dart';
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
    final creds = KioskDeviceCredentials.fromConfig(config);
    if (deviceId.isEmpty || !creds.isValid) {
      return const Left(
        ValidationFailure('Device credentials missing — employee snapshot skipped'),
      );
    }

    try {
      final snapshot = await _snapshotApi.fetchSnapshot(
        apiHost: creds.apiHost,
        deviceId: deviceId,
        deviceToken: creds.deviceToken,
      );
      final apiBase = config.apiBaseUrl ?? 'https://${creds.apiHost}';
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
      return await applySnapshot(resolved);
    } on RegistrationApiException catch (e) {
      return Left(
        e.isNetworkError ? NetworkFailure(e.message) : ValidationFailure(e.message),
      );
    } catch (e) {
      return Left(NetworkFailure('Employee snapshot failed: $e'));
    }
  }

  Future<Either<Failure, int>> applySnapshot(EmployeeSnapshotData snapshot) async {
    final rosterIds = snapshot.employees.map((e) => e.id).toSet();

    // Store gallery under roster [Employee.id] so prune + reconcile stay consistent.
    final canonicalProfiles = <String, Map<String, dynamic>>{};
    for (final e in snapshot.employees) {
      final profile =
          EmployeeSnapshotParser.profileForEmployee(e, snapshot.faceProfiles);
      if (profile != null) canonicalProfiles[e.id] = profile;
    }

    final galleryResult = await _faces.importServerGallery(
      canonicalProfiles,
      rosterEmployeeIds: rosterIds,
    );
    if (galleryResult.isLeft()) {
      return galleryResult.map((_) => 0);
    }

    final mergedEmployees = snapshot.employees.map((e) {
      final serverProfile =
          EmployeeSnapshotParser.profileForEmployee(e, snapshot.faceProfiles);
      if (serverProfile != null) {
        return e.copyWith(
          faceRegistered: true,
          faceProfileHash: FaceProfileParser.contentHash(serverProfile),
        );
      }
      return e.copyWith(
        faceRegistered: e.faceRegistered,
        clearFaceProfileHash: !e.faceRegistered,
      );
    }).toList();

    final replaceResult = await _employees.replaceAll(mergedEmployees);
    if (replaceResult.isLeft()) return replaceResult.map((_) => 0);

    final reconcileResult = await _faces.reconcileFaceRegistrationFlags();
    if (reconcileResult.isLeft()) {
      return reconcileResult.map((_) => 0);
    }

    final faceCount = galleryResult.getOrElse((_) => 0);
    if (kDebugMode) {
      debugPrint(
        'EmployeeSnapshotStore: ${mergedEmployees.length} employees, '
        '$faceCount face profiles imported',
      );
    }
    return Right(mergedEmployees.length);
  }

}
