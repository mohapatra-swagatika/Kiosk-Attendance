import 'package:attendance_kiosk_app/core/api/kiosk_employee_snapshot_api.dart';

/// Remote employee roster sync for a paired kiosk device.
abstract class KioskSyncEmployeesApi {
  Future<EmployeeSnapshotData> syncEmployees({
    required String apiHost,
    required String deviceId,
    required String deviceToken,
  });
}
