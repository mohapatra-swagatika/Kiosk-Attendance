import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee_month_shift.dart';

class EmployeeModel {
  const EmployeeModel({
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

  factory EmployeeModel.fromEntity(Employee e) => EmployeeModel(
        id: e.id,
        name: e.name,
        department: e.department,
        imageUrl: e.imageUrl,
        pin: e.pin,
        faceRegistered: e.faceRegistered,
        faceProfileHash: e.faceProfileHash,
        isAdmin: e.isAdmin,
        employeeCode: e.employeeCode,
        email: e.email,
        designation: e.designation,
        phone: e.phone,
        workStatus: e.workStatus,
        location: e.location,
        reportingManager: e.reportingManager,
        monthShifts: e.monthShifts,
      );

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    return EmployeeModel(
      id: id,
      name: json['name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      pin: _pinFromJson(json),
      faceRegistered: json['faceRegistered'] as bool? ?? false,
      faceProfileHash: json['faceProfileHash'] as String?,
      isAdmin: json['isAdmin'] as bool? ?? false,
      employeeCode: json['employeeCode'] as String?,
      email: json['email'] as String?,
      designation: json['designation'] as String?,
      phone: json['phone'] as String?,
      workStatus: json['workStatus'] as String?,
      location: json['location'] as String?,
      reportingManager: json['reportingManager'] as String?,
      monthShifts: _shiftsFromJson(json['monthShifts']),
    );
  }

  static String _pinFromJson(Map<String, dynamic> json) {
    for (final key in const [
      'pin',
      'kioskPin',
      'kiosk_pin',
      'attendancePin',
      'employeePin',
    ]) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num) return v.toString().trim();
    }
    return '';
  }

  static List<EmployeeMonthShift>? _shiftsFromJson(Object? raw) {
    if (raw is! List) return null;
    final out = <EmployeeMonthShift>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.map((k, v) => MapEntry(k.toString(), v));
      final date = map['date']?.toString() ?? '';
      if (date.isEmpty) continue;
      out.add(
        EmployeeMonthShift(
          date: date,
          shiftName: map['shiftName']?.toString() ?? '',
          shiftCode: map['shiftCode']?.toString() ?? '',
          shiftId: map['shiftId'] is int ? map['shiftId'] as int : int.tryParse('${map['shiftId']}'),
        ),
      );
    }
    return out.isEmpty ? null : out;
  }

  static List<Map<String, dynamic>>? _shiftsToJson(List<EmployeeMonthShift>? shifts) {
    if (shifts == null || shifts.isEmpty) return null;
    return shifts
        .map(
          (s) => {
            'date': s.date,
            'shiftName': s.shiftName,
            'shiftCode': s.shiftCode,
            if (s.shiftId != null) 'shiftId': s.shiftId,
          },
        )
        .toList();
  }

  final String id;
  final String name;
  final String department;
  final String imageUrl;
  final String pin;
  final bool faceRegistered;
  final String? faceProfileHash;
  final bool isAdmin;
  final String? employeeCode;
  final String? email;
  final String? designation;
  final String? phone;
  final String? workStatus;
  final String? location;
  final String? reportingManager;
  final List<EmployeeMonthShift>? monthShifts;

  Employee toEntity() => Employee(
        id: id,
        name: name,
        department: department,
        imageUrl: imageUrl,
        pin: pin,
        faceRegistered: faceRegistered,
        faceProfileHash: faceProfileHash,
        isAdmin: isAdmin,
        employeeCode: employeeCode,
        email: email,
        designation: designation,
        phone: phone,
        workStatus: workStatus,
        location: location,
        reportingManager: reportingManager,
        monthShifts: monthShifts,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'department': department,
        'imageUrl': imageUrl,
        'pin': pin,
        'faceRegistered': faceRegistered,
        if (faceProfileHash != null) 'faceProfileHash': faceProfileHash,
        'isAdmin': isAdmin,
        if (employeeCode != null) 'employeeCode': employeeCode,
        if (email != null) 'email': email,
        if (designation != null) 'designation': designation,
        if (phone != null) 'phone': phone,
        if (workStatus != null) 'workStatus': workStatus,
        if (location != null) 'location': location,
        if (reportingManager != null) 'reportingManager': reportingManager,
        if (monthShifts != null) 'monthShifts': _shiftsToJson(monthShifts),
      };
}
