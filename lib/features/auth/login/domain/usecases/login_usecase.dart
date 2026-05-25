import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/usecases/usecase.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/repositories/auth_repository.dart';

class LoginParams {
  const LoginParams({required this.username, required this.password});
  final String username;
  final String password;
}

/// Legacy login screen — delegates to PIN auth (password treated as PIN).
class LoginUseCase extends UseCase<void, LoginParams> {
  LoginUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(LoginParams params) {
    final pin = params.password.trim().isNotEmpty
        ? params.password.trim()
        : params.username.trim();
    return _repository.loginWithPin(pin);
  }
}
