import 'package:attendance_kiosk_app/features/attendance/domain/entities/attendance_log.dart';

class AttendanceLogModel {
  const AttendanceLogModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.checkInTime,
    this.checkOutTime,
    required this.date,
    required this.deviceId,
    required this.status,
    this.checkInPhotoPath,
    this.checkOutPhotoPath,
  });

  factory AttendanceLogModel.fromEntity(AttendanceLog e) => AttendanceLogModel(
        id: e.id ?? '${e.employeeId}_${e.checkInTime.millisecondsSinceEpoch}',
        employeeId: e.employeeId,
        employeeName: e.employeeName,
        checkInTime: e.checkInTime.toIso8601String(),
        checkOutTime: e.checkOutTime?.toIso8601String(),
        date: e.date,
        deviceId: e.deviceId,
        status: e.status.value,
        checkInPhotoPath: e.checkInPhotoPath,
        checkOutPhotoPath: e.checkOutPhotoPath,
      );

  factory AttendanceLogModel.fromJson(Map<String, dynamic> json) {
    return AttendanceLogModel(
      id: json['id'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      employeeName: json['employeeName'] as String? ?? '',
      checkInTime: json['checkInTime'] as String? ?? '',
      checkOutTime: json['checkOutTime'] as String?,
      date: json['date'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      status: json['status'] as String? ?? 'checked_in',
      checkInPhotoPath: json['checkInPhotoPath'] as String?,
      checkOutPhotoPath: json['checkOutPhotoPath'] as String?,
    );
  }

  final String id;
  final String employeeId;
  final String employeeName;
  final String checkInTime;
  final String? checkOutTime;
  final String date;
  final String deviceId;
  final String status;
  final String? checkInPhotoPath;
  final String? checkOutPhotoPath;

  AttendanceLog toEntity() => AttendanceLog(
        id: id,
        employeeId: employeeId,
        employeeName: employeeName,
        checkInTime: DateTime.parse(checkInTime),
        checkOutTime: checkOutTime != null ? DateTime.parse(checkOutTime!) : null,
        date: date,
        deviceId: deviceId,
        status: AttendanceStatus.fromValue(status),
        checkInPhotoPath: checkInPhotoPath,
        checkOutPhotoPath: checkOutPhotoPath,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'checkInTime': checkInTime,
        'checkOutTime': checkOutTime,
        'date': date,
        'deviceId': deviceId,
        'status': status,
        if (checkInPhotoPath != null) 'checkInPhotoPath': checkInPhotoPath,
        if (checkOutPhotoPath != null) 'checkOutPhotoPath': checkOutPhotoPath,
      };
}
