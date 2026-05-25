import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';

/// On-device gallery of enrolled face profiles (employeeId → v6 neural profile).
abstract class FaceProfileLocalDataSource {
  Future<Map<String, Map<String, dynamic>>> readGallery();
  Future<void> writeGallery(Map<String, Map<String, dynamic>> gallery);
}

class FaceProfileLocalDataSourceImpl implements FaceProfileLocalDataSource {
  FaceProfileLocalDataSourceImpl(this._box);

  final Box<dynamic> _box;

  static const _legacyKey = 'face_embeddings';

  @override
  Future<Map<String, Map<String, dynamic>>> readGallery() async {
    try {
      await _migrateLegacyIfNeeded();
      final raw = _box.get(HiveKeys.faceProfiles);
      if (raw is! String || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (id, profile) => MapEntry(
          id,
          Map<String, dynamic>.from(profile as Map),
        ),
      );
    } catch (e) {
      throw CacheException('Failed to read face profiles: $e');
    }
  }

  @override
  Future<void> writeGallery(Map<String, Map<String, dynamic>> gallery) async {
    try {
      await _box.put(HiveKeys.faceProfiles, jsonEncode(gallery));
    } catch (e) {
      throw CacheException('Failed to write face profiles: $e');
    }
  }

  Future<void> _migrateLegacyIfNeeded() async {
    if (_box.containsKey(HiveKeys.faceProfiles)) return;
    final legacy = _box.get(_legacyKey);
    if (legacy is String && legacy.isNotEmpty) {
      await _box.put(HiveKeys.faceProfiles, legacy);
      await _box.delete(_legacyKey);
    }
  }
}
