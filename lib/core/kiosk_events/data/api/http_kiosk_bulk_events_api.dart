import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:attendance_kiosk_app/core/api/kiosk_pair_api_urls.dart';
import 'package:attendance_kiosk_app/core/api/registration_api_exception.dart';
import 'package:attendance_kiosk_app/core/kiosk_events/data/api/kiosk_bulk_events_api.dart';

class HttpKioskBulkEventsApi implements KioskBulkEventsApi {
  const HttpKioskBulkEventsApi({http.Client? client}) : _client = client;

  final http.Client? _client;

  static const Duration _timeout = Duration(seconds: 60);

  @override
  Future<void> postBulk({
    required String apiHost,
    required String deviceToken,
    required List<KioskBulkEventUpload> events,
  }) async {
    if (events.isEmpty) return;

    final host = KioskPairApiUrls.toApiHost(apiHost);
    final token = deviceToken.trim();
    if (host.isEmpty || token.isEmpty) {
      throw const RegistrationApiException(
        'Device credentials missing — cannot upload kiosk events.',
        isNetworkError: false,
      );
    }

    final url = Uri.parse(KioskPairApiUrls.bulkEventsEndpoint(host));
    final body = jsonEncode({
      'events': events
          .map(
            (e) => {
              'eventId': e.eventId,
              'payloadJson': e.payloadJson,
            },
          )
          .toList(),
    });

    if (kDebugMode) {
      debugPrint('[KioskEvents] POST $url (${events.length} events)');
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
            body: body,
          )
          .timeout(_timeout);

      if (kDebugMode) {
        debugPrint('[KioskEvents] ${response.statusCode} ${response.body.length} bytes');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RegistrationApiException(
          'Kiosk events upload failed (${response.statusCode})',
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
      final resultOk =
          result != null ? (_readBool(result, const ['status', 'success']) ?? true) : true;
      if (!topOk || !resultOk) {
        final msg = _readString(result ?? json, const ['message', 'error', 'detail']) ??
            'Kiosk events were rejected';
        throw RegistrationApiException(msg, isNetworkError: false);
      }
    } on RegistrationApiException {
      rethrow;
    } catch (e) {
      throw RegistrationApiException(
        'Unable to upload kiosk events. Check your connection.',
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
