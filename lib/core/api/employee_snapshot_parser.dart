import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';
import 'package:attendance_kiosk_app/core/ml/face_profile_poses.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_employee_snapshot_api.dart';
import 'package:attendance_kiosk_app/features/employees/data/models/employee_model.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee_month_shift.dart';

/// Parses ThinkSys kiosk employee-snapshot JSON into local models.
class EmployeeSnapshotParser {
  EmployeeSnapshotParser._();

  static EmployeeSnapshotData parse(Map<String, dynamic>? json) {
    final payload = _unwrapPayload(json);
    final employees = _parseEmployees(payload);
    final profiles = _parseFaceProfiles(payload);
    return EmployeeSnapshotData(employees: employees, faceProfiles: profiles);
  }

  static Map<String, dynamic>? _unwrapPayload(Map<String, dynamic>? json) {
    if (json == null) return null;

    final result = _asMap(json['result']);
    if (result != null) {
      final data = _asMap(result['data']);
      if (data != null) return data;
      return result;
    }

    final data = _asMap(json['data']);
    if (data != null) return data;

    return json;
  }

  static List<Employee> _parseEmployees(Map<String, dynamic>? payload) {
    if (payload == null) return [];

    final list = _extractEmployeeList(payload);
    final employees = <Employee>[];
    for (final item in list) {
      final map = _asMap(item);
      if (map == null) continue;
      final employee = _parseEmployee(map);
      if (employee != null) employees.add(employee);
    }
    return employees;
  }

  static List<dynamic> _extractEmployeeList(Map<String, dynamic> payload) {
    for (final key in const [
      'employees',
      'employeeList',
      'employee_list',
      'employeeDetails',
      'employee_details',
      'roster',
      'items',
      'records',
      'content',
    ]) {
      final value = payload[key];
      if (value is List) return value;
    }

    final snapshot = _asMap(payload['employeeSnapshot'] ?? payload['snapshot']);
    if (snapshot != null) {
      for (final key in const ['employees', 'employeeList', 'items']) {
        final value = snapshot[key];
        if (value is List) return value;
      }
    }

    return const [];
  }

  static Employee? _parseEmployee(Map<String, dynamic> json) {
    final id = _readString(json, const [
      'id',
      '_id',
      'employeeId',
      'employee_id',
      'userId',
      'user_id',
      'uuid',
    ]);
    if (id == null || id.isEmpty) return null;

    final nestedProfile = _profileFromEmployeeJson(json);
    final faceRegistered = _readBool(json, const [
          'faceRegistered',
          'face_registered',
          'hasFace',
          'hasFaceProfile',
          'isFaceRegistered',
        ]) ??
        nestedProfile != null;

    return Employee(
      id: id,
      name: _readName(json),
      department: _readDepartment(json['department'] ?? json['dept']),
      imageUrl: _readImageUrl(json),
      pin: _readString(json, const [
            'pin',
            'kioskPin',
            'kiosk_pin',
            'attendancePin',
            'employeePin',
          ]) ??
          EmployeeModel.pinFallbackForId(id),
      faceRegistered: faceRegistered,
      employeeCode: _readString(json, const [
        'employeeNumber',
        'employee_number',
        'employeeCode',
        'employee_code',
        'code',
        'empCode',
        'emp_code',
      ]),
      email: _readString(json, const ['email', 'workEmail', 'work_email']),
      designation: _readString(json, const [
        'designation',
        'jobTitle',
        'job_title',
        'title',
        'position',
      ]),
      phone: _readString(json, const [
        'phone',
        'mobile',
        'phoneNumber',
        'phone_number',
        'contactNumber',
      ]),
      workStatus: _readString(json, const ['status', 'workStatus', 'work_status']),
      location: _readString(json, const ['location', 'office', 'site']),
      reportingManager: _readString(json, const [
        'reportingManager',
        'reporting_manager',
        'manager',
        'managerName',
      ]),
      monthShifts: _parseMonthShifts(json['currentMonthShifts']),
    );
  }

  static List<EmployeeMonthShift>? _parseMonthShifts(Object? raw) {
    if (raw is! List) return null;
    final out = <EmployeeMonthShift>[];
    for (final item in raw) {
      final map = _asMap(item);
      if (map == null) continue;
      final date = _readString(map, const ['date']) ?? '';
      if (date.isEmpty) continue;
      final shiftIdRaw = map['shiftId'];
      final shiftId = shiftIdRaw is int
          ? shiftIdRaw
          : shiftIdRaw is num
              ? shiftIdRaw.toInt()
              : int.tryParse(shiftIdRaw?.toString() ?? '');
      out.add(
        EmployeeMonthShift(
          date: date,
          shiftName: _readString(map, const ['shiftName', 'shift_name']) ?? '',
          shiftCode: _readString(map, const ['shiftCode', 'shift_code']) ?? '',
          shiftId: shiftId,
        ),
      );
    }
    return out.isEmpty ? null : out;
  }

  static String _readName(Map<String, dynamic> json) {
    final direct = _readString(json, const [
      'name',
      'fullName',
      'full_name',
      'employeeName',
      'employee_name',
      'displayName',
      'display_name',
    ]);
    if (direct != null && direct.isNotEmpty) {
      return direct.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    final first = _readString(json, const ['firstName', 'first_name', 'givenName']);
    final last = _readString(json, const ['lastName', 'last_name', 'familyName', 'surname']);
    if (first != null || last != null) {
      return [first, last].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    }
    return '';
  }

  static String _readDepartment(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    final map = _asMap(value);
    if (map != null) {
      return _readString(map, const ['name', 'title', 'departmentName', 'label']) ?? '';
    }
    return '';
  }

  static String _readImageUrl(Map<String, dynamic> json) {
    final direct = _readString(json, const [
      'image',
      'imageUrl',
      'image_url',
      'photoUrl',
      'photo_url',
      'avatar',
      'avatarUrl',
      'profileImage',
      'profile_image',
      'profilePhoto',
      'profile_photo',
      'photo',
      'picture',
    ]);
    if (direct != null && direct.isNotEmpty) return direct;

    final media = _asMap(json['media'] ?? json['photo']);
    if (media != null) {
      return _readString(media, const ['url', 'path', 'imageUrl']) ?? '';
    }
    return '';
  }

  static Map<String, Map<String, dynamic>> _parseFaceProfiles(
    Map<String, dynamic>? payload,
  ) {
    final raw = <String, Map<String, dynamic>>{};

    if (payload != null) {
      for (final key in const [
        'faceProfiles',
        'face_profiles',
        'profiles',
        'biometricProfiles',
        'embeddings',
      ]) {
        final value = payload[key];
        if (value is Map) {
          for (final entry in value.entries) {
            final map = _asMap(entry.value);
            if (map != null) raw[entry.key.toString()] = map;
          }
        }
      }

      for (final item in _extractEmployeeList(payload)) {
        final map = _asMap(item);
        if (map == null) continue;
        final id = _readString(map, const [
          'id',
          '_id',
          'employeeId',
          'employee_id',
          'userId',
        ]);
        final profile = _profileFromEmployeeJson(map);
        if (id != null && profile != null) raw[id] = profile;
      }
    }

    final valid = <String, Map<String, dynamic>>{};
    for (final entry in raw.entries) {
      final normalized = _normalizeProfile(entry.value);
      if (normalized != null) valid[entry.key] = normalized;
    }

    return valid;
  }

  static Map<String, dynamic>? _profileFromEmployeeJson(Map<String, dynamic> json) {
    for (final key in const [
      'faceProfile',
      'face_profile',
      'biometricProfile',
      'biometric_profile',
      'profile',
      'embeddings',
    ]) {
      final profile = _normalizeProfile(json[key]);
      if (profile != null) return profile;
    }
    return null;
  }

  static Map<String, dynamic>? _normalizeProfile(Object? raw) {
    final map = _asMap(raw);
    if (map == null) return null;

    final version = map['v'];
    final v = version is int
        ? version
        : version is num
            ? version.toInt()
            : int.tryParse(version?.toString() ?? '');
    if (v != FaceEmbeddingCodec.storageVersionTflite) return null;

    final normalized = <String, dynamic>{'v': v};
    for (final pose in FaceProfilePoses.matchKeys) {
      final list = _coerceEmbeddingList(map[pose]);
      if (list != null) normalized[pose] = list;
    }

    final templates = map[FaceProfilePoses.templatesKey];
    if (templates is List && templates.isNotEmpty) {
      normalized[FaceProfilePoses.templatesKey] = templates;
    }

    final hasPose = FaceProfilePoses.required.any(normalized.containsKey);
    if (!hasPose) return null;

    return normalized;
  }

  static List<double>? _coerceEmbeddingList(Object? raw) {
    if (raw is! List || raw.isEmpty) return null;
    final out = <double>[];
    for (final v in raw) {
      if (v is num) {
        out.add(v.toDouble());
      } else {
        return null;
      }
    }
    if (out.length != FaceEmbeddingCodec.neuralEmbeddingDim) return null;
    return out;
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static String? _readString(Map<String, dynamic>? json, List<String> keys) {
    if (json == null) return null;
    for (final key in keys) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num) return v.toString();
    }
    return null;
  }

  static bool? _readBool(Map<String, dynamic>? json, List<String> keys) {
    if (json == null) return null;
    for (final key in keys) {
      final v = json[key];
      if (v is bool) return v;
      if (v is String) {
        final lower = v.toLowerCase();
        if (lower == 'true') return true;
        if (lower == 'false') return false;
      }
    }
    return null;
  }
}
