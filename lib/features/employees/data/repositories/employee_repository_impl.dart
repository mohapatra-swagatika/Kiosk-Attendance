import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/api/employee_api.dart';
import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/features/employees/data/datasources/employee_local_data_source.dart';
import 'package:attendance_kiosk_app/features/employees/data/models/employee_model.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/domain/repositories/employee_repository.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  EmployeeRepositoryImpl(this._local, this._employeeApi);

  final EmployeeLocalDataSource _local;
  final EmployeeApi _employeeApi;

  @override
  Future<Either<Failure, List<Employee>>> getEmployees() async {
    try {
      final models = await _local.readAll();
      return Right(models.map((m) => m.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> replaceAll(List<Employee> employees) async {
    try {
      await _local.writeAll(employees.map(EmployeeModel.fromEntity).toList());
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveEmployee(Employee employee) async {
    try {
      final models = await _local.readAll();
      final list = models.map((m) => m.toEntity()).toList();
      final i = list.indexWhere((e) => e.id == employee.id);
      if (i >= 0) {
        list[i] = employee;
      } else {
        list.add(employee);
      }
      await _local.writeAll(list.map(EmployeeModel.fromEntity).toList());
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> syncFromServer({required String domain}) async {
    try {
      final remote = await _employeeApi.fetchEmployees(domain: domain);
      final local = await _local.readAll();
      final faceById = {
        for (final m in local) m.id: m.faceRegistered,
      };
      final merged = remote
          .map(
            (e) => e.copyWith(faceRegistered: faceById[e.id] ?? e.faceRegistered),
          )
          .toList();
      await _local.writeAll(merged.map(EmployeeModel.fromEntity).toList());
      return Right(merged.length);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
