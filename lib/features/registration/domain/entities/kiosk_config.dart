import 'package:equatable/equatable.dart';

import 'package:attendance_kiosk_app/core/config/attendance_mode.dart';

class KioskConfig extends Equatable {
  const KioskConfig({
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

  final String code;
  final String domain;
  final String machineName;
  final String description;
  final String? adminName;
  final String? adminEmail;

  /// Admin kiosk PIN (stored locally after mock online registration).
  final String? adminPin;

  /// Local file paths for branding assets (from registration API, cached on device).
  final String? logoPath;
  final String? brandingImagePath;

  /// Remote URLs — used to re-fetch branding if local files are missing.
  final String? logoUrl;
  final String? brandingImageUrl;
  final AttendanceMode attendanceMode;

  /// Pair API `deviceId` — used for sync and attendance.
  final String? deviceId;

  /// Pair API `deviceIdentifier` (human-readable kiosk id).
  final String? deviceIdentifier;

  /// Pair API `deviceToken` — auth for future API calls.
  final String? deviceToken;

  /// Tenant API root after successful pair.
  final String? apiBaseUrl;

  /// Pair API `registeredAt` (UTC ISO-8601).
  final String? registeredAtIso;

  KioskConfig copyWith({
    String? code,
    String? domain,
    String? machineName,
    String? description,
    String? adminName,
    String? adminEmail,
    String? adminPin,
    String? logoPath,
    String? brandingImagePath,
    String? logoUrl,
    String? brandingImageUrl,
    AttendanceMode? attendanceMode,
    String? deviceId,
    String? deviceIdentifier,
    String? deviceToken,
    String? apiBaseUrl,
    String? registeredAtIso,
  }) {
    return KioskConfig(
      code: code ?? this.code,
      domain: domain ?? this.domain,
      machineName: machineName ?? this.machineName,
      description: description ?? this.description,
      adminName: adminName ?? this.adminName,
      adminEmail: adminEmail ?? this.adminEmail,
      adminPin: adminPin ?? this.adminPin,
      logoPath: logoPath ?? this.logoPath,
      brandingImagePath: brandingImagePath ?? this.brandingImagePath,
      logoUrl: logoUrl ?? this.logoUrl,
      brandingImageUrl: brandingImageUrl ?? this.brandingImageUrl,
      attendanceMode: attendanceMode ?? this.attendanceMode,
      deviceId: deviceId ?? this.deviceId,
      deviceIdentifier: deviceIdentifier ?? this.deviceIdentifier,
      deviceToken: deviceToken ?? this.deviceToken,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      registeredAtIso: registeredAtIso ?? this.registeredAtIso,
    );
  }

  @override
  List<Object?> get props => [
        code,
        domain,
        machineName,
        description,
        adminName,
        adminEmail,
        adminPin,
        logoPath,
        brandingImagePath,
        logoUrl,
        brandingImageUrl,
        attendanceMode,
        deviceId,
        deviceIdentifier,
        deviceToken,
        apiBaseUrl,
        registeredAtIso,
      ];
}
