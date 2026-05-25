import 'package:attendance_kiosk_app/core/config/attendance_mode.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_config.dart';

class KioskConfigModel {
  const KioskConfigModel({
    required this.code,
    required this.domain,
    required this.machineName,
    required this.description,
    this.adminName,
    this.adminEmail,
    this.adminPin,
    this.logoPath,
    this.brandingImagePath,
    this.logoUrl,
    this.brandingImageUrl,
    this.attendanceMode = AttendanceMode.face,
    this.deviceId,
    this.deviceIdentifier,
    this.deviceToken,
    this.apiBaseUrl,
    this.registeredAtIso,
  });

  factory KioskConfigModel.fromEntity(KioskConfig e) => KioskConfigModel(
        code: e.code,
        domain: e.domain,
        machineName: e.machineName,
        description: e.description,
        adminName: e.adminName,
        adminEmail: e.adminEmail,
        adminPin: e.adminPin,
        logoPath: e.logoPath,
        brandingImagePath: e.brandingImagePath,
        logoUrl: e.logoUrl,
        brandingImageUrl: e.brandingImageUrl,
        attendanceMode: e.attendanceMode,
        deviceId: e.deviceId,
        deviceIdentifier: e.deviceIdentifier,
        deviceToken: e.deviceToken,
        apiBaseUrl: e.apiBaseUrl,
        registeredAtIso: e.registeredAtIso,
      );

  factory KioskConfigModel.fromJson(Map<String, dynamic> json) {
    return KioskConfigModel(
      code: json['code'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      machineName: json['machineName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      adminName: json['adminName'] as String?,
      adminEmail: json['adminEmail'] as String?,
      adminPin: json['adminPin'] as String?,
      logoPath: json['logoPath'] as String?,
      brandingImagePath: json['brandingImagePath'] as String?,
      logoUrl: json['logoUrl'] as String?,
      brandingImageUrl: json['brandingImageUrl'] as String?,
      attendanceMode: AttendanceMode.fromStorage(json['attendanceMode'] as String?),
      deviceId: (json['deviceId'] ?? json['kioskId']) as String?,
      deviceIdentifier: json['deviceIdentifier'] as String?,
      deviceToken: json['deviceToken'] as String?,
      apiBaseUrl: json['apiBaseUrl'] as String?,
      registeredAtIso:
          (json['registeredAtIso'] ?? json['pairedAtIso']) as String?,
    );
  }

  final String code;
  final String domain;
  final String machineName;
  final String description;
  final String? adminName;
  final String? adminEmail;
  final String? adminPin;
  final String? logoPath;
  final String? brandingImagePath;
  final String? logoUrl;
  final String? brandingImageUrl;
  final AttendanceMode attendanceMode;
  final String? deviceId;
  final String? deviceIdentifier;
  final String? deviceToken;
  final String? apiBaseUrl;
  final String? registeredAtIso;

  KioskConfig toEntity() => KioskConfig(
        code: code,
        domain: domain,
        machineName: machineName,
        description: description,
        adminName: adminName,
        adminEmail: adminEmail,
        adminPin: adminPin,
        logoPath: logoPath,
        brandingImagePath: brandingImagePath,
        logoUrl: logoUrl,
        brandingImageUrl: brandingImageUrl,
        attendanceMode: attendanceMode,
        deviceId: deviceId,
        deviceIdentifier: deviceIdentifier,
        deviceToken: deviceToken,
        apiBaseUrl: apiBaseUrl,
        registeredAtIso: registeredAtIso,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'domain': domain,
        'machineName': machineName,
        'description': description,
        if (adminName != null) 'adminName': adminName,
        if (adminEmail != null) 'adminEmail': adminEmail,
        if (adminPin != null) 'adminPin': adminPin,
        if (logoPath != null) 'logoPath': logoPath,
        if (brandingImagePath != null) 'brandingImagePath': brandingImagePath,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (brandingImageUrl != null) 'brandingImageUrl': brandingImageUrl,
        'attendanceMode': attendanceMode.storageValue,
        if (deviceId != null) 'deviceId': deviceId,
        if (deviceIdentifier != null) 'deviceIdentifier': deviceIdentifier,
        if (deviceToken != null) 'deviceToken': deviceToken,
        if (apiBaseUrl != null) 'apiBaseUrl': apiBaseUrl,
        if (registeredAtIso != null) 'registeredAtIso': registeredAtIso,
      };
}
