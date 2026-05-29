import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/app/app_launch_gate.dart';
import 'package:attendance_kiosk_app/app/app_startup_coordinator.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/kiosk_face_stack_warmup.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_config.dart';
import 'package:attendance_kiosk_app/features/registration/domain/usecases/register_kiosk_usecase.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';

const Object _unset = Object();

/// UI state for the registration flow (submitting / error).
class RegistrationFormState {
  const RegistrationFormState({
    this.isSubmitting = false,
    this.errorMessage,
    this.assignedAdminPin,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final String? assignedAdminPin;

  RegistrationFormState copyWith({
    bool? isSubmitting,
    Object? errorMessage = _unset,
    Object? assignedAdminPin = _unset,
  }) {
    return RegistrationFormState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: identical(errorMessage, _unset) ? this.errorMessage : errorMessage as String?,
      assignedAdminPin: identical(assignedAdminPin, _unset)
          ? this.assignedAdminPin
          : assignedAdminPin as String?,
    );
  }
}

class RegistrationFormNotifier extends Notifier<RegistrationFormState> {
  @override
  RegistrationFormState build() => const RegistrationFormState();

  Future<bool> submit(KioskConfig config) async {
    if (!ref.read(appStartupCoordinatorProvider).storageReady) {
      state = state.copyWith(
        errorMessage: RegistrationStrings.preparingStorage,
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null, assignedAdminPin: null);
    final useCase = ref.read(registerKioskUseCaseProvider);
    final result = await useCase(RegisterKioskParams(config));
    return await result.fold(
      (failure) async {
        state = state.copyWith(isSubmitting: false, errorMessage: failure.message);
        return false;
      },
      (_) async {
        try {
          final loadResult = await ref.read(kioskConfigRepositoryProvider).load();
          final pin = loadResult.fold((_) => null, (c) => c?.adminPin);
          await AppLaunchGate.preload();
          ref.invalidate(employeesListProvider);
          ref.invalidate(employeeByIdProvider);
          ref.invalidate(kioskConfigProvider);
          // Pre-warm kiosk face stack while admin PIN dialog is shown.
          KioskFaceStackWarmup.instance.schedule();
          await ref.read(faceRepositoryProvider).preloadGallery();
          state = state.copyWith(
            isSubmitting: false,
            errorMessage: null,
            assignedAdminPin: pin,
          );
        } catch (e, st) {
          assert(() {
            debugPrint('[Registration] Post-save refresh failed: $e\n$st');
            return true;
          }());
          state = state.copyWith(isSubmitting: false, errorMessage: null);
        }
        return true;
      },
    );
  }
}

final registrationFormProvider =
    NotifierProvider<RegistrationFormNotifier, RegistrationFormState>(
  RegistrationFormNotifier.new,
);
