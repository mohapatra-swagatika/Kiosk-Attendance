import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/auth/user_role.dart';
import 'package:attendance_kiosk_app/core/errors/exceptions.dart';
import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/features/auth/login/data/datasources/session_local_data_source.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/entities/app_session.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/repositories/auth_repository.dart';
import 'package:attendance_kiosk_app/features/employees/data/datasources/employee_local_data_source.dart';
import 'package:attendance_kiosk_app/features/registration/data/datasources/kiosk_config_local_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._session,
    this._employees,
    this._kioskConfig,
  );

  final SessionLocalDataSource _session;
  final EmployeeLocalDataSource _employees;
  final KioskConfigLocalDataSource _kioskConfig;

  @override
  Future<Either<Failure, void>> loginWithPin(String pin) async {
    try {
      final normalized = pin.trim();
      if (normalized.length < 4) {
        return const Left(ValidationFailure('Enter a valid PIN'));
      }

      final config = await _kioskConfig.load();
      final adminPin = config?.adminPin?.trim();
      if (adminPin != null &&
          adminPin.isNotEmpty &&
          normalized == adminPin) {
        await _session.saveSession(
          AppSession(
            displayName: config?.adminName?.trim().isNotEmpty == true
                ? config!.adminName!.trim()
                : 'Administrator',
            role: UserRole.admin,
          ),
        );
        return const Right(null);
      }

      final models = await _employees.readAll();
      for (final model in models) {
        if (model.pin.trim() == normalized) {
          final employee = model.toEntity();
          await _session.saveSession(
            AppSession(
              displayName: employee.name,
              role: UserRole.employee,
              employeeId: employee.id,
            ),
          );
          return const Right(null);
        }
      }

      return const Left(ValidationFailure('Invalid PIN — employee not found'));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _session.clearSession();
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isLoggedIn() async {
    try {
      return Right(await _session.isLoggedIn());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AppSession?>> currentSession() async {
    try {
      return Right(await _session.currentSession());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }
}
