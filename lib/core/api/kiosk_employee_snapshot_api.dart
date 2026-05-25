import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';

/// Employee roster + face templates returned by the kiosk snapshot API.
class EmployeeSnapshotData {
  const EmployeeSnapshotData({
    required this.employees,
    required this.faceProfiles,
  });

  final List<Employee> employees;

  /// `employeeId` → on-device face profile map (v7 tflite).
  final Map<String, Map<String, dynamic>> faceProfiles;
}

/// `GET /api/v1/kiosk/devices/{deviceId}/employee-snapshot`
abstract class KioskEmployeeSnapshotApi {
  Future<EmployeeSnapshotData> fetchSnapshot({
    required String apiHost,
    required String deviceId,
    required String deviceToken,
  });
}
