import 'package:fpdart/fpdart.dart';

import 'package:attendance_kiosk_app/core/errors/failures.dart';
import 'package:attendance_kiosk_app/core/usecases/usecase.dart';
import 'package:attendance_kiosk_app/features/registration/domain/repositories/kiosk_config_repository.dart';

class HasKioskConfigUseCase extends UseCase<bool, NoParams> {
  HasKioskConfigUseCase(this._repository);

  final KioskConfigRepository _repository;

  @override
  Future<Either<Failure, bool>> call(NoParams params) {
    return _repository.hasConfig();
  }
}
