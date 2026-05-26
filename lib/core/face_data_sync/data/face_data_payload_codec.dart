import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Canonical encoding + hashing for face profile upload payloads.
abstract final class FaceDataPayloadCodec {
  /// Server payload to remove stored face data (`POST` face-data API).
  static const Map<String, dynamic> clearedFaceData = {};

  static bool isClearPayload(Map<String, dynamic> faceDataJson) =>
      faceDataJson.isEmpty;

  static Map<String, dynamic> requestBody(Map<String, dynamic> faceDataJson) => {
        'faceDataJson': faceDataJson,
      };

  static String contentHash(Map<String, dynamic> faceDataJson) {
    final canonical = jsonEncode(_canonicalize(faceDataJson));
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {
        for (final key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is List) {
      return value.map(_canonicalize).toList();
    }
    return value;
  }
}
