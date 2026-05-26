import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_config.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_organization.dart';

/// Remote device registration — swap [MockRegistrationApi] for a real HTTP client later.
abstract class RegistrationApi {
  Future<RegistrationApiResult> registerDevice(KioskConfig config);
}

class RegistrationApiResult {
  const RegistrationApiResult({
    required this.success,
    this.message,
    this.adminPin,
    this.adminName,
    this.adminEmail,
    this.logoUrl,
    this.brandingImageUrl,
    this.organization,
    this.deviceId,
    this.deviceIdentifier,
    this.deviceToken,
    this.machineName,
    this.description,
    this.apiBaseUrl,
    this.registeredAt,
  });

  final bool success;
  final String? message;

  /// Server-assigned admin PIN (mock returns generated pin).
  final String? adminPin;

  /// Admin profile returned by the server after device registration.
  final String? adminName;
  final String? adminEmail;

  /// Remote branding assets; cached to local paths after registration.
  final String? logoUrl;
  final String? brandingImageUrl;

  /// Pair API `data.organization` (tenant branding).
  final KioskOrganization? organization;

  /// Pair API `data.deviceId` (UUID).
  final String? deviceId;

  /// Pair API `data.deviceIdentifier` (e.g. `kiosk_…`).
  final String? deviceIdentifier;

  /// Pair API `data.deviceToken` (e.g. `DKT-…`).
  final String? deviceToken;

  /// Confirmed machine name from server (optional).
  final String? machineName;

  /// Confirmed description from server (optional).
  final String? description;

  /// Tenant API base, e.g. `https://thinksysnoida-qa.thinksys.com`.
  final String? apiBaseUrl;

  /// Pair API `data.registeredAt`.
  final DateTime? registeredAt;
}
