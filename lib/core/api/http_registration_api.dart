import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:attendance_kiosk_app/core/api/kiosk_pair_api_urls.dart';
import 'package:attendance_kiosk_app/core/api/pair_organization_parser.dart';
import 'package:attendance_kiosk_app/core/api/registration_api.dart';
import 'package:attendance_kiosk_app/core/api/registration_api_exception.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_config.dart';

/// Pairs this device with the tenant API: `POST /api/v1/kiosk/pair`.
class HttpRegistrationApi implements RegistrationApi {
  const HttpRegistrationApi({http.Client? client}) : _client = client;

  final http.Client? _client;

  static const Duration _timeout = Duration(seconds: 30);

  @override
  Future<RegistrationApiResult> registerDevice(KioskConfig config) async {
    final host = KioskPairApiUrls.toApiHost(config.domain);
    if (host.isEmpty) {
      return const RegistrationApiResult(
        success: false,
        message: 'Domain is required',
      );
    }

    final url = Uri.parse(KioskPairApiUrls.pairEndpoint(host));
    final body = jsonEncode({
      'organization_code': config.code.trim(),
      'code': config.code.trim(),
      'domain': host,
      'machine_name': config.machineName.trim(),
      'machineName': config.machineName.trim(),
      'description': config.description.trim(),
    });

    if (kDebugMode) {
      debugPrint('[KioskPair] POST $url');
      debugPrint('[KioskPair] request body: $body');
    }

    final client = _client ?? http.Client();
    final ownsClient = _client == null;

    try {
      final response = await client
          .post(
            url,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(_timeout);

      final result = _parseResponse(response, apiHost: host);
      _logPairApiDetails(response: response, result: result);
      return result;
    } on RegistrationApiException {
      rethrow;
    } catch (e) {
      throw RegistrationApiException(
        'Unable to reach the server. Check the domain and your connection.',
        isNetworkError: true,
      );
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }

  RegistrationApiResult _parseResponse(
    http.Response response, {
    required String apiHost,
  }) {
    Map<String, dynamic>? json;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        } else if (decoded is Map) {
          json = decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw RegistrationApiException(
            'Invalid response from server.',
            isNetworkError: false,
          );
        }
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = _messageFromEnvelope(json) ??
          'Registration failed (${response.statusCode})';
      return RegistrationApiResult(success: false, message: msg);
    }

    final parsed = _parsePairEnvelope(json);
    if (!parsed.success) {
      return RegistrationApiResult(
        success: false,
        message: parsed.message ?? 'Registration was rejected',
      );
    }

    final data = parsed.data;
    final organization = PairOrganizationParser.fromPairData(data);
    final orgLogo = organization?.companyLogoUrl;
    final deviceToken = _readString(data, const ['deviceToken', 'device_token']);
    return RegistrationApiResult(
      success: true,
      message: parsed.message,
      adminPin: _readString(data, const [
        'admin_pin',
        'adminPin',
        'pin',
        'kiosk_admin_pin',
      ]),
      adminName: _readString(data, const ['admin_name', 'adminName', 'name']),
      adminEmail: _readString(data, const ['admin_email', 'adminEmail', 'email']),
      logoUrl: orgLogo ??
          _readString(data, const ['logo_url', 'logoUrl', 'logo']),
      brandingImageUrl: _readString(data, const [
        'branding_image_url',
        'brandingImageUrl',
        'banner_url',
        'branding_url',
      ]),
      organization: organization,
      deviceId: _readString(data, const ['deviceId', 'device_id']),
      deviceIdentifier: _readString(data, const [
        'deviceIdentifier',
        'device_identifier',
      ]),
      deviceToken: deviceToken,
      machineName: _readString(data, const ['machineName', 'machine_name']),
      description: _readString(data, const ['description']),
      apiBaseUrl: 'https://$apiHost',
      registeredAt: _readDateTime(data, const [
        'registeredAt',
        'registered_at',
        'pairedAt',
        'paired_at',
      ]),
    );
  }

  /// Debug-only: full pair API response + parsed fields (includes [deviceToken]).
  static void _logPairApiDetails({
    required http.Response response,
    required RegistrationApiResult result,
  }) {
    if (!kDebugMode) return;

    debugPrint('[KioskPair] ────────── pair API response ──────────');
    debugPrint('[KioskPair] HTTP ${response.statusCode} (${response.body.length} bytes)');

    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
        debugPrint('[KioskPair] raw JSON:\n$pretty');
      } catch (_) {
        debugPrint('[KioskPair] raw body: ${response.body}');
      }
    } else {
      debugPrint('[KioskPair] raw body: (empty)');
    }

    debugPrint('[KioskPair] parsed success=${result.success}');
    if (result.message != null) {
      debugPrint('[KioskPair] message: ${result.message}');
    }

    if (!result.success) {
      debugPrint('[KioskPair] ────────────────────────────────────────');
      return;
    }

    debugPrint('[KioskPair] deviceId: ${result.deviceId ?? '(null)'}');
    debugPrint('[KioskPair] deviceIdentifier: ${result.deviceIdentifier ?? '(null)'}');
    debugPrint('[KioskPair] deviceToken: ${result.deviceToken ?? '(null)'}');
    debugPrint('[KioskPair] machineName: ${result.machineName ?? '(null)'}');
    debugPrint('[KioskPair] description: ${result.description ?? '(null)'}');
    debugPrint('[KioskPair] apiBaseUrl: ${result.apiBaseUrl ?? '(null)'}');
    debugPrint('[KioskPair] registeredAt: ${result.registeredAt?.toIso8601String() ?? '(null)'}');
    debugPrint('[KioskPair] adminPin: ${result.adminPin != null ? '***' : '(null)'}');
    debugPrint('[KioskPair] adminName: ${result.adminName ?? '(null)'}');
    debugPrint('[KioskPair] adminEmail: ${result.adminEmail ?? '(null)'}');
    debugPrint('[KioskPair] logoUrl: ${result.logoUrl ?? '(null)'}');

    final org = result.organization;
    if (org == null) {
      debugPrint('[KioskPair] organization: (null)');
    } else {
      debugPrint('[KioskPair] organization.subdomain: ${org.subdomain ?? '(null)'}');
      debugPrint('[KioskPair] organization.companyName: ${org.companyName ?? '(null)'}');
      debugPrint('[KioskPair] organization.displayName: ${org.displayName ?? '(null)'}');
      debugPrint('[KioskPair] organization.companyLogoUrl: ${org.companyLogoUrl ?? '(null)'}');
    }

    debugPrint('[KioskPair] ────────────────────────────────────────');
  }

  /// ThinkSys envelope: `{ status, result: { status, message, data: { … } } }`.
  static _PairEnvelope _parsePairEnvelope(Map<String, dynamic>? json) {
    if (json == null) {
      return const _PairEnvelope(success: true, data: null);
    }

    final topOk = _readBool(json, const ['status']) ?? true;
    final result = _asMap(json['result']);
    if (result != null) {
      final resultOk = _readBool(result, const ['status']) ?? true;
      final message = _readString(result, const ['message', 'error', 'detail']);
      final data = _asMap(result['data']) ?? result;
      return _PairEnvelope(
        success: topOk && resultOk,
        message: message,
        data: data,
      );
    }

    final data = _unwrapLegacyData(json);
    final ok = _readBool(json, const ['status', 'success', 'ok', 'paired']) ?? topOk;
    return _PairEnvelope(
      success: ok,
      message: _messageFromEnvelope(json),
      data: data,
    );
  }

  static Map<String, dynamic>? _unwrapLegacyData(Map<String, dynamic>? json) {
    if (json == null) return null;
    final nested = json['data'];
    return _asMap(nested) ?? json;
  }

  static String? _messageFromEnvelope(Map<String, dynamic>? json) {
    if (json == null) return null;
    final direct = _readString(json, const ['message', 'error', 'detail', 'reason']);
    if (direct != null) return direct;
    final result = _asMap(json['result']);
    return _readString(result, const ['message', 'error', 'detail', 'reason']);
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static DateTime? _readDateTime(Map<String, dynamic>? json, List<String> keys) {
    final raw = _readString(json, keys);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
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
      if (v is String) {
        final lower = v.toLowerCase();
        if (lower == 'true') return true;
        if (lower == 'false') return false;
      }
    }
    return null;
  }
}

class _PairEnvelope {
  const _PairEnvelope({
    required this.success,
    this.message,
    this.data,
  });

  final bool success;
  final String? message;
  final Map<String, dynamic>? data;
}
