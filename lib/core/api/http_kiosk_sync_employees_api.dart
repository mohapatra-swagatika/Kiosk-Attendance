import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:attendance_kiosk_app/core/api/employee_snapshot_parser.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_employee_snapshot_api.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_pair_api_urls.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_sync_employees_api.dart';
import 'package:attendance_kiosk_app/core/api/registration_api_exception.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_http_envelope.dart';

/// `POST /api/v1/kiosk/devices/{deviceId}/sync-employees`
class HttpKioskSyncEmployeesApi implements KioskSyncEmployeesApi {
  const HttpKioskSyncEmployeesApi({http.Client? client}) : _client = client;

  final http.Client? _client;

  static const Duration _timeout = Duration(seconds: 120);

  @override
  Future<EmployeeSnapshotData> syncEmployees({
    required String apiHost,
    required String deviceId,
    required String deviceToken,
  }) async {
    final host = KioskPairApiUrls.toApiHost(apiHost);
    final id = deviceId.trim();
    final token = deviceToken.trim();
    if (host.isEmpty || id.isEmpty || token.isEmpty) {
      throw const RegistrationApiException(
        'Device credentials missing — cannot sync employees.',
        isNetworkError: false,
      );
    }

    final url = Uri.parse(KioskPairApiUrls.syncEmployeesEndpoint(host, id));
    if (kDebugMode) {
      debugPrint('[EmployeeSync] POST $url');
    }

    final client = _client ?? http.Client();
    final ownsClient = _client == null;

    try {
      final response = await client
          .post(
            url,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: '{}',
          )
          .timeout(_timeout);

      if (kDebugMode) {
        debugPrint(
          '[EmployeeSync] ${response.statusCode} ${response.body.length} bytes',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RegistrationApiException(
          'Employee sync failed (${response.statusCode})',
          isNetworkError: response.statusCode >= 500,
        );
      }

      final json = KioskHttpEnvelope.decodeBody(response.body);
      KioskHttpEnvelope.ensureSuccess(json);

      return EmployeeSnapshotParser.parse(json);
    } on RegistrationApiException {
      rethrow;
    } catch (e) {
      throw RegistrationApiException(
        'Unable to sync employees. Check your connection.',
        isNetworkError: true,
      );
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}
