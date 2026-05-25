import 'package:attendance_kiosk_app/core/api/registration_api.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_config.dart';

/// Simulates online registration until backend APIs are available.
class MockRegistrationApi implements RegistrationApi {
  const MockRegistrationApi();

  @override
  Future<RegistrationApiResult> registerDevice(KioskConfig config) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (config.code.trim().isEmpty) {
      return const RegistrationApiResult(
        success: false,
        message: 'Organization code is required',
      );
    }
    final pin = config.adminPin?.trim().isNotEmpty == true
        ? config.adminPin!.trim()
        : _pinFromCode(config.code);
    final now = DateTime.now().toUtc();
    return RegistrationApiResult(
      success: true,
      message: 'Device registered successfully',
      adminPin: pin,
      adminName: config.adminName ?? 'Kiosk Administrator',
      adminEmail: config.adminEmail ?? 'admin@${config.domain}',
      logoUrl: null,
      brandingImageUrl: null,
      deviceId: 'mock-${config.code.trim()}',
      deviceIdentifier: 'kiosk_mock_${config.code.trim()}',
      deviceToken: 'DKT-MOCK-${config.code.trim()}',
      machineName: config.machineName,
      description: config.description,
      registeredAt: now,
    );
  }

  static String _pinFromCode(String code) {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) return digits.substring(digits.length - 4);
    return '1000';
  }
}
