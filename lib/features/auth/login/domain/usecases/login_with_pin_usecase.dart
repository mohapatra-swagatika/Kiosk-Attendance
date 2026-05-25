import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/usecases/usecase.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/repositories/auth_repository.dart';

class LoginWithPinParams {
  const LoginWithPinParams(this.pin);
  final String pin;
}

class LoginWithPinUseCase extends UseCase<void, LoginWithPinParams> {
  LoginWithPinUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(LoginWithPinParams params) {
    return _repository.loginWithPin(params.pin);
  }
}
