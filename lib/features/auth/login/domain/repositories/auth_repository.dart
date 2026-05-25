import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/entities/app_session.dart';

abstract class AuthRepository {
  Future<Either<Failure, void>> loginWithPin(String pin);

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, bool>> isLoggedIn();

  Future<Either<Failure, AppSession?>> currentSession();
}
