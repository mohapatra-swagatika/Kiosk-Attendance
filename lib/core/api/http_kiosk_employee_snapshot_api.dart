import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:attendance_kiosk_app/core/api/employee_snapshot_parser.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_employee_snapshot_api.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_pair_api_urls.dart';
import 'package:attendance_kiosk_app/core/api/registration_api_exception.dart';

/// Fetches kiosk employee snapshot with device bearer token.
class HttpKioskEmployeeSnapshotApi implements KioskEmployeeSnapshotApi {
  const HttpKioskEmployeeSnapshotApi({http.Client? client}) : _client = client;

  final http.Client? _client;

  static const Duration _timeout = Duration(seconds: 45);

  @override
  Future<EmployeeSnapshotData> fetchSnapshot({
    required String apiHost,
    required String deviceId,
    required String deviceToken,
  }) async {
    final host = KioskPairApiUrls.toApiHost(apiHost);
    final id = deviceId.trim();
    final token = deviceToken.trim();
    if (host.isEmpty || id.isEmpty || token.isEmpty) {
      throw const RegistrationApiException(
        'Device credentials missing — cannot load employee snapshot.',
        isNetworkError: false,
      );
    }

    final url = Uri.parse(KioskPairApiUrls.employeeSnapshotEndpoint(host, id));
    if (kDebugMode) {
      debugPrint('[EmployeeSnapshot] GET $url');
    }

    final client = _client ?? http.Client();
    final ownsClient = _client == null;

    try {
      final response = await client
          .get(
            url,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (kDebugMode) {
        debugPrint(
          '[EmployeeSnapshot] ${response.statusCode} ${response.body.length} bytes',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RegistrationApiException(
          'Employee snapshot failed (${response.statusCode})',
          isNetworkError: response.statusCode >= 500,
        );
      }

      Map<String, dynamic>? json;
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        } else if (decoded is Map) {
          json = decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      }

      final topOk = _readBool(json, const ['status', 'success']) ?? true;
      final result = _asMap(json?['result']);
      final resultOk = result != null ? (_readBool(result, const ['status', 'success']) ?? true) : true;
      if (!topOk || !resultOk) {
        final msg = _readString(result ?? json, const ['message', 'error', 'detail']) ??
            'Employee snapshot was rejected';
        throw RegistrationApiException(msg, isNetworkError: false);
      }

      return EmployeeSnapshotParser.parse(json);
    } on RegistrationApiException {
      rethrow;
    } catch (e) {
      throw RegistrationApiException(
        'Unable to load employee snapshot. Check your connection.',
        isNetworkError: true,
      );
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
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
    }
    return null;
  }

  static bool? _readBool(Map<String, dynamic>? json, List<String> keys) {
    if (json == null) return null;
    for (final key in keys) {
      final v = json[key];
      if (v is bool) return v;
    }
    return null;
  }
}
