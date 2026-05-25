import 'package:equatable/equatable.dart';

enum AttendanceStatus {
  checkedIn('checked_in'),
  checkedOut('checked_out');

  const AttendanceStatus(this.value);
  final String value;

  static AttendanceStatus fromValue(String v) {
    return AttendanceStatus.values.firstWhere(
      (e) => e.value == v,
      orElse: () => AttendanceStatus.checkedIn,
    );
  }
}

class AttendanceLog extends Equatable {
  const AttendanceLog({
    required this.employeeId,
    required this.employeeName,
    required this.checkInTime,
    this.checkOutTime,
    required this.date,
    required this.deviceId,
    required this.status,
    this.id,
    this.checkInPhotoPath,
    this.checkOutPhotoPath,
  });

  final String? id;
  final String employeeId;
  final String employeeName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String date;
  final String deviceId;
  final AttendanceStatus status;
  final String? checkInPhotoPath;
  final String? checkOutPhotoPath;

  AttendanceLog copyWith({
    String? id,
    DateTime? checkOutTime,
    AttendanceStatus? status,
    String? checkInPhotoPath,
    String? checkOutPhotoPath,
  }) {
    return AttendanceLog(
      id: id ?? this.id,
      employeeId: employeeId,
      employeeName: employeeName,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      date: date,
      deviceId: deviceId,
      status: status ?? this.status,
      checkInPhotoPath: checkInPhotoPath ?? this.checkInPhotoPath,
      checkOutPhotoPath: checkOutPhotoPath ?? this.checkOutPhotoPath,
    );
  }

  bool get isActiveCheckIn => status == AttendanceStatus.checkedIn && checkOutTime == null;

  @override
  List<Object?> get props => [
        id,
        employeeId,
        employeeName,
        checkInTime,
        checkOutTime,
        date,
        deviceId,
        status,
        checkInPhotoPath,
        checkOutPhotoPath,
      ];
}
