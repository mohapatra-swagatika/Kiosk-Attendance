import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/platform/kiosk_mode_channel.dart';
import 'package:attendance_kiosk_app/features/auth/login/data/datasources/session_local_data_source.dart';
import 'package:attendance_kiosk_app/features/auth/login/data/repositories/auth_repository_impl.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/entities/app_session.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/entities/login_credentials.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/repositories/auth_repository.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/usecases/login_usecase.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/usecases/login_with_pin_usecase.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/usecases/logout_usecase.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

final kioskModeChannelProvider = Provider<KioskModeChannel>((ref) => KioskModeChannel());

final sessionLocalDataSourceProvider = Provider<SessionLocalDataSource>((ref) {
  return SessionLocalDataSourceImpl(ref.watch(appBoxProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(sessionLocalDataSourceProvider),
    ref.watch(employeeLocalDataSourceProvider),
    ref.watch(kioskConfigLocalDataSourceProvider),
  );
});

final loginWithPinUseCaseProvider = Provider<LoginWithPinUseCase>((ref) {
  return LoginWithPinUseCase(ref.watch(authRepositoryProvider));
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});

final appSessionProvider = FutureProvider<AppSession?>((ref) async {
  final result = await ref.read(authRepositoryProvider).currentSession();
  return result.fold((_) => null, (session) => session);
});

const Object _loginFormUnset = Object();

class LoginFormState {
  const LoginFormState({this.isSubmitting = false, this.errorMessage});
  final bool isSubmitting;
  final String? errorMessage;

  LoginFormState copyWith({bool? isSubmitting, Object? errorMessage = _loginFormUnset}) {
    return LoginFormState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: identical(errorMessage, _loginFormUnset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class LoginFormNotifier extends Notifier<LoginFormState> {
  @override
  LoginFormState build() => const LoginFormState();

  Future<bool> submit(LoginCredentials credentials) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    final result = await ref.read(loginUseCaseProvider)(
      LoginParams(username: credentials.username, password: credentials.password),
    );
    return result.fold(
      (failure) {
        state = state.copyWith(isSubmitting: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isSubmitting: false, errorMessage: null);
        return true;
      },
    );
  }
}

final loginFormProvider = NotifierProvider<LoginFormNotifier, LoginFormState>(
  LoginFormNotifier.new,
);
