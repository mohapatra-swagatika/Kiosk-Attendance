/// How the kiosk captures attendance (configured by admin in Settings).
enum AttendanceMode {
  face('face'),
  pin('pin');

  const AttendanceMode(this.storageValue);
  final String storageValue;

  static AttendanceMode fromStorage(String? value) {
    return AttendanceMode.values.firstWhere(
      (m) => m.storageValue == value,
      orElse: () => AttendanceMode.face,
    );
  }
}
