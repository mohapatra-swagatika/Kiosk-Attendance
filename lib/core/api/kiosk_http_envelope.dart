import 'dart:convert';

import 'package:attendance_kiosk_app/core/api/registration_api_exception.dart';

/// Parses ThinkSys kiosk API JSON envelopes (`status` / `result` / `data`).
abstract final class KioskHttpEnvelope {
  static Map<String, dynamic>? decodeBody(String body) {
    if (body.isEmpty) return null;
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static void ensureSuccess(Map<String, dynamic>? json) {
    final topOk = _readBool(json, const ['status', 'success']) ?? true;
    final result = _asMap(json?['result']);
    final resultOk =
        result != null ? (_readBool(result, const ['status', 'success']) ?? true) : true;
    if (!topOk || !resultOk) {
      final msg = _readString(result ?? json, const ['message', 'error', 'detail']) ??
          'Request was rejected';
      throw RegistrationApiException(msg, isNetworkError: false);
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
