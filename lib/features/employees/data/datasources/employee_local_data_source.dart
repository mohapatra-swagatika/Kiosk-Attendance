import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/storage/hive_boxes.dart';
import 'package:attendance_kiosk_app/features/employees/data/models/employee_model.dart';

abstract class EmployeeLocalDataSource {
  Future<List<EmployeeModel>> readAll();
  Future<void> writeAll(List<EmployeeModel> models);
}

class EmployeeLocalDataSourceImpl implements EmployeeLocalDataSource {
  EmployeeLocalDataSourceImpl(this._box);

  final Box<dynamic> _box;

  @override
  Future<List<EmployeeModel>> readAll() async {
    try {
      final raw = _box.get(HiveKeys.employees);
      if (raw is! String || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final models = <EmployeeModel>[];
      for (final item in list) {
        if (item is! Map) continue;
        final map = item is Map<String, dynamic>
            ? item
            : item.map((k, v) => MapEntry(k.toString(), v));
        final id = map['id']?.toString().trim() ?? '';
        if (id.isEmpty) continue;
        models.add(EmployeeModel.fromJson(map));
      }
      return models;
    } catch (e) {
      throw CacheException('Failed to read employees: $e');
    }
  }

  @override
  Future<void> writeAll(List<EmployeeModel> models) async {
    try {
      final encoded = jsonEncode(models.map((m) => m.toJson()).toList());
      await _box.put(HiveKeys.employees, encoded);
    } catch (e) {
      throw CacheException('Failed to write employees: $e');
    }
  }
}
