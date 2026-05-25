import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/usecases/usecase.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_config.dart';
import 'package:attendance_kiosk_app/features/registration/domain/repositories/kiosk_config_repository.dart';

class RegisterKioskParams {
  const RegisterKioskParams(this.config);
  final KioskConfig config;
}

class RegisterKioskUseCase extends UseCase<void, RegisterKioskParams> {
  RegisterKioskUseCase(this._repository);

  final KioskConfigRepository _repository;

  @override
  Future<Either<Failure, void>> call(RegisterKioskParams params) {
    return _repository.save(params.config);
  }
}
