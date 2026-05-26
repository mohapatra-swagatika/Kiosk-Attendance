import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:attendance_kiosk_app/core/face_data_sync/data/face_data_payload_codec.dart';
import 'package:attendance_kiosk_app/core/ml/face_embedding_codec.dart';
import 'package:attendance_kiosk_app/core/ml/face_profile_poses.dart';

/// Parses server `faceDataJson` / legacy face profile shapes for on-device matching.
abstract final class FaceProfileParser {
  /// Returns a normalized v7 profile map, or null if missing/invalid.
  static Map<String, dynamic>? parse(Object? raw) {
    if (raw == null) return null;

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        return parse(decoded);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[FaceProfileParser] Invalid JSON string: $e');
        }
        return null;
      }
    }

    final map = _asMap(raw);
    if (map == null) return null;

    final wrapped = map['faceDataJson'] ?? map['face_data_json'];
    if (wrapped != null && wrapped != raw) {
      final inner = parse(wrapped);
      if (inner != null) return inner;
    }

    return _normalizeProfileMap(map);
  }

  /// Reads face data from an employee JSON object (sync / snapshot roster item).
  static Map<String, dynamic>? fromEmployeeJson(Map<String, dynamic> json) {
    for (final key in const [
      'faceDataJson',
      'face_data_json',
      'faceProfile',
      'face_profile',
      'biometricProfile',
      'biometric_profile',
      'profile',
      'embeddings',
    ]) {
      final profile = parse(json[key]);
      if (profile != null) return profile;
    }
    return null;
  }

  static bool hasValidFaceData(Map<String, dynamic> json) =>
      fromEmployeeJson(json) != null;

  /// Fingerprint for change detection (stored on [Employee.faceProfileHash]).
  static String? contentHash(Map<String, dynamic> profile) =>
      FaceDataPayloadCodec.contentHash(profile);

  static Map<String, dynamic>? _normalizeProfileMap(Map<String, dynamic> map) {
    final version = map['v'];
    final v = version is int
        ? version
        : version is num
            ? version.toInt()
            : int.tryParse(version?.toString() ?? '');
    if (v != FaceEmbeddingCodec.storageVersionTflite) return null;

    final normalized = <String, dynamic>{'v': v};

    for (final pose in FaceProfilePoses.matchKeys) {
      final list = _coerceEmbeddingList(map[pose]);
      if (list != null) normalized[pose] = list;
    }

    final templates = map[FaceProfilePoses.templatesKey];
    if (templates is List && templates.isNotEmpty) {
      final bank = <List<double>>[];
      for (final item in templates) {
        final vec = _coerceEmbeddingList(item);
        if (vec != null) bank.add(vec);
      }
      if (bank.isNotEmpty) {
        normalized[FaceProfilePoses.templatesKey] = bank;
      }
    }

    for (final metaKey in const [
      'enrollmentMode',
      'samples',
      'yawSpread',
      'sawBlink',
    ]) {
      if (map.containsKey(metaKey)) {
        normalized[metaKey] = map[metaKey];
      }
    }

    if (!normalized.containsKey(FaceProfilePoses.straight)) {
      if (kDebugMode) {
        debugPrint('[FaceProfileParser] Rejected profile: missing "straight" pose');
      }
      return null;
    }

    for (final pose in FaceProfilePoses.required) {
      if (normalized.containsKey(pose)) continue;
      final straight = normalized[FaceProfilePoses.straight];
      if (straight is List) {
        normalized[pose] = List<double>.from(straight);
      }
    }

    return normalized;
  }

  static List<double>? _coerceEmbeddingList(Object? raw) {
    if (raw is! List || raw.isEmpty) return null;
    final out = <double>[];
    for (final v in raw) {
      if (v is num) {
        out.add(v.toDouble());
      } else {
        return null;
      }
    }
    if (out.length != FaceEmbeddingCodec.neuralEmbeddingDim) return null;
    return out;
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }
}
