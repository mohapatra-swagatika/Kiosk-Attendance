import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';
import 'package:attendance_kiosk_app/features/auth/login/data/models/session_model.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/entities/app_session.dart';

abstract class SessionLocalDataSource {
  Future<void> saveSession(AppSession session);
  Future<void> clearSession();
  Future<bool> isLoggedIn();
  Future<AppSession?> currentSession();
}

class SessionLocalDataSourceImpl implements SessionLocalDataSource {
  SessionLocalDataSourceImpl(this._box);

  final Box<dynamic> _box;

  static final _key = HiveKeys.session;

  @override
  Future<void> saveSession(AppSession session) async {
    try {
      final payload = SessionModel.fromSession(session);
      await _box.put(_key, jsonEncode(payload.toJson()));
    } catch (e) {
      throw CacheException('Failed to save session: $e');
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      await _box.delete(_key);
    } catch (e) {
      throw CacheException('Failed to clear session: $e');
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    final session = await currentSession();
    return session?.loggedIn == true;
  }

  @override
  Future<AppSession?> currentSession() async {
    final raw = _box.get(_key);
    if (raw is! String || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SessionModel.fromJson(map).toEntity();
    } catch (_) {
      return null;
    }
  }
}
