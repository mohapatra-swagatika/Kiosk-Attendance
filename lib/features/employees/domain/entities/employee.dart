import 'package:equatable/equatable.dart';

import 'package:attendance_kiosk_app/features/employees/domain/entities/employee_month_shift.dart';

class Employee extends Equatable {
  const Employee({
    required this.id,
    required this.name,
    required this.department,
    required this.imageUrl,
    required this.pin,
    required this.faceRegistered,
    this.faceProfileHash,
    this.isAdmin = false,
    this.employeeCode,
    this.email,
    this.designation,
    this.phone,
    this.workStatus,
    this.location,
    this.reportingManager,
    this.monthShifts,
  });

  final String id;
  final String name;
  final String department;
  final String imageUrl;

  /// Kiosk check-in PIN (shown to operators on the Employees screen).
  final String pin;
  final bool faceRegistered;

  /// SHA-256 of synced `faceDataJson` (empty when no server face data).
  final String? faceProfileHash;

  /// When true, this employee's kiosk PIN grants admin access (from sync API).
  final bool isAdmin;

  /// HR / roster code when different from [id].
  final String? employeeCode;
  final String? email;
  final String? designation;
  final String? phone;

  /// Snapshot `status` (e.g. Working).
  final String? workStatus;
  final String? location;
  final String? reportingManager;
  final List<EmployeeMonthShift>? monthShifts;

  Employee copyWith({
    String? id,
    String? name,
    String? department,
    String? imageUrl,
    String? pin,
    bool? faceRegistered,
    String? faceProfileHash,
    bool clearFaceProfileHash = false,
    bool? isAdmin,
    String? employeeCode,
    String? email,
    String? designation,
    String? phone,
    String? workStatus,
    String? location,
    String? reportingManager,
    List<EmployeeMonthShift>? monthShifts,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      department: department ?? this.department,
      imageUrl: imageUrl ?? this.imageUrl,
      pin: pin ?? this.pin,
      faceRegistered: faceRegistered ?? this.faceRegistered,
      faceProfileHash: clearFaceProfileHash
          ? null
          : (faceProfileHash ?? this.faceProfileHash),
      isAdmin: isAdmin ?? this.isAdmin,
      employeeCode: employeeCode ?? this.employeeCode,
      email: email ?? this.email,
      designation: designation ?? this.designation,
      phone: phone ?? this.phone,
      workStatus: workStatus ?? this.workStatus,
      location: location ?? this.location,
      reportingManager: reportingManager ?? this.reportingManager,
      monthShifts: monthShifts ?? this.monthShifts,
    );
  }

  /// Today's shift from [monthShifts], if present.
  EmployeeMonthShift? get todayShift {
    final shifts = monthShifts;
    if (shifts == null || shifts.isEmpty) return null;
    final today = DateTime.now();
    final key =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    for (final s in shifts) {
      if (s.date == key) return s;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        department,
        imageUrl,
        pin,
        faceRegistered,
        faceProfileHash,
        isAdmin,
        employeeCode,
        email,
        designation,
        phone,
        workStatus,
        location,
        reportingManager,
        monthShifts,
      ];
}
