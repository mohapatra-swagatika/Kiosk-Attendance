/// `POST /api/v1/kiosk/devices/{deviceId}/employees/{employeeId}/face-data`
abstract class KioskFaceDataApi {
  Future<void> uploadFaceData({
    required String apiHost,
    required String deviceId,
    required String deviceToken,
    required String employeeId,
    required Map<String, dynamic> faceDataJson,
  });
}
