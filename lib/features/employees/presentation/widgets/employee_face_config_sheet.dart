import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_kiosk_app/app/router/route_paths.dart';
import 'package:attendance_kiosk_app/app/theme/app_button_styles.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/face_data_sync/face_data_sync_providers.dart';
import 'package:attendance_kiosk_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:attendance_kiosk_app/features/employees/domain/entities/employee.dart';
import 'package:attendance_kiosk_app/features/employees/presentation/providers/employee_providers.dart';

Future<void> showEmployeeFaceConfigSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Employee employee,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Consumer(
        builder: (context, ref, _) {
          final hasFaceAsync = ref.watch(employeeHasFaceEmbeddingProvider(employee.id));
          final hasFace = hasFaceAsync.valueOrNull ?? false;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(FaceConfigStrings.title, style: Theme.of(sheetContext).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    FaceConfigStrings.subtitle(name: employee.name, id: employee.id),
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (hasFaceAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Text(
                      hasFace
                          ? FaceConfigStrings.alreadyRegistered
                          : FaceConfigStrings.startInstructions,
                      style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(height: 1.45),
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: AppButtonStyles.filledStyle().copyWith(
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    onPressed: hasFace || hasFaceAsync.isLoading
                        ? null
                        : () async {
                            Navigator.pop(sheetContext);
                            final ok = await context.push<bool>(
                              RoutePaths.faceRegisterPath(employee.id),
                            );
                            if (ok == true) {
                              ref.invalidate(employeesListProvider);
                              ref.invalidate(employeeByIdProvider(employee.id));
                              ref.invalidate(employeeHasFaceEmbeddingProvider(employee.id));
                            }
                          },
                    icon: const Icon(Icons.face_retouching_natural, size: 28),
                    label: const Text(FaceConfigStrings.startButton),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: AppButtonStyles.outlinedStyle().copyWith(
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    onPressed: () async {
                      final result =
                          await ref.read(faceRepositoryProvider).resetFaceRegistration(employee.id);
                      if (!sheetContext.mounted) return;
                      result.fold(
                        (f) => ScaffoldMessenger.of(sheetContext)
                            .showSnackBar(SnackBar(content: Text(f.message))),
                        (_) {
                          ref.read(faceRepositoryProvider).invalidateGalleryCache();
                          ref.invalidate(employeesListProvider);
                          ref.invalidate(employeeByIdProvider(employee.id));
                          ref.invalidate(employeeHasFaceEmbeddingProvider(employee.id));
                          ref.invalidate(faceDataSyncPendingCountProvider);
                          ref.invalidate(offlineSyncPendingCountProvider);
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text(FaceConfigStrings.resetSnackbar)),
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text(FaceConfigStrings.resetButton),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
