import 'package:attendance_kiosk_app/core/api/kiosk_employee_snapshot_api.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_sync_employees_api.dart';
import 'package:attendance_kiosk_app/core/api/registration_api_exception.dart';
import 'package:attendance_kiosk_app/core/errors/exceptions.dart';

abstract class EmployeeSyncRemoteDataSource {
  Future<EmployeeSnapshotData> fetchSyncPayload({
    required String apiHost,
    required String deviceId,
    required String deviceToken,
  });
}

class EmployeeSyncRemoteDataSourceImpl implements EmployeeSyncRemoteDataSource {
  const EmployeeSyncRemoteDataSourceImpl(this._api);

  final KioskSyncEmployeesApi _api;

  @override
  Future<EmployeeSnapshotData> fetchSyncPayload({
    required String apiHost,
    required String deviceId,
    required String deviceToken,
  }) async {
    try {
      return await _api.syncEmployees(
        apiHost: apiHost,
        deviceId: deviceId,
        deviceToken: deviceToken,
      );
    } on RegistrationApiException catch (e) {
      throw CacheException(e.message);
    }
  }
}
