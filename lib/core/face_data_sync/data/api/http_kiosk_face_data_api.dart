import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:attendance_kiosk_app/core/api/kiosk_pair_api_urls.dart';
import 'package:attendance_kiosk_app/core/api/registration_api_exception.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/data/api/kiosk_face_data_api.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/data/face_data_payload_codec.dart';

class HttpKioskFaceDataApi implements KioskFaceDataApi {
  const HttpKioskFaceDataApi({http.Client? client}) : _client = client;

  final http.Client? _client;

  static const Duration _timeout = Duration(seconds: 120);

  @override
  Future<void> uploadFaceData({
    required String apiHost,
    required String deviceId,
    required String deviceToken,
    required String employeeId,
    required Map<String, dynamic> faceDataJson,
  }) async {
    final host = KioskPairApiUrls.toApiHost(apiHost);
    final token = deviceToken.trim();
    final devId = deviceId.trim();
    final empId = employeeId.trim();
    if (host.isEmpty || token.isEmpty || devId.isEmpty || empId.isEmpty) {
      throw const RegistrationApiException(
        'Device credentials missing — cannot upload face data.',
        isNetworkError: false,
      );
    }

    final url = Uri.parse(
      KioskPairApiUrls.faceDataEndpoint(host, devId, empId),
    );
    final body = jsonEncode(FaceDataPayloadCodec.requestBody(faceDataJson));

    if (kDebugMode) {
      debugPrint(
        '[FaceDataSync] POST $url (${body.length} bytes)',
      );
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
        debugPrint('[FaceDataSync] ${response.statusCode} ${response.body.length} bytes');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RegistrationApiException(
          'Face data upload failed (${response.statusCode})',
          isNetworkError: response.statusCode >= 500,
        );
      }
    } on RegistrationApiException {
      rethrow;
    } catch (e) {
      throw RegistrationApiException(
        'Face data upload failed: $e',
        isNetworkError: true,
      );
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}
