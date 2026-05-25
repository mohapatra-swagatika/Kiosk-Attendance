import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_kiosk_app/app/router/route_paths.dart';
import 'package:attendance_kiosk_app/app/router/router_refresh.dart';
import 'package:attendance_kiosk_app/core/auth/user_role.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_pair_api_urls.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/widgets/glass_panel.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/usecases/login_with_pin_usecase.dart';
import 'package:attendance_kiosk_app/features/auth/login/presentation/providers/login_providers.dart';
import 'package:attendance_kiosk_app/features/kiosk/presentation/widgets/kiosk_pin_pad.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

class KioskPinLoginPanel extends ConsumerStatefulWidget {
  const KioskPinLoginPanel({super.key, required this.onCancel});

  final VoidCallback onCancel;

  @override
  ConsumerState<KioskPinLoginPanel> createState() => _KioskPinLoginPanelState();
}

class _KioskPinLoginPanelState extends ConsumerState<KioskPinLoginPanel> {
  String _pin = '';
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_pin.length < 4) {
      setState(() => _error = KioskPinStrings.pinTooShort);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref.read(loginWithPinUseCaseProvider)(LoginWithPinParams(_pin));
    if (!mounted) return;

    result.fold(
      (f) => setState(() {
        _submitting = false;
        _error = f.message;
      }),
      (_) async {
        ref.invalidate(appSessionProvider);
        final session = await ref.read(appSessionProvider.future);
        ref.read(routerRefreshProvider).notify();
        if (!mounted) return;
        final role = session?.role ?? UserRole.employee;
        context.go(role == UserRole.admin ? RoutePaths.home : RoutePaths.employeeHome);
      },
    );
  }

  void _tapDigit(String d) {
    if (_submitting || _pin.length >= 6) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(kioskConfigProvider);
    final domain = KioskPairApiUrls.subdomainFromStored(configAsync.valueOrNull?.domain ?? '');
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GlassPanel(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.domain, size: 48, color: scheme.primary),
                const SizedBox(height: 12),
                Text(
                  domain.isEmpty ? AppStrings.appTitle : domain,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  RegistrationStrings.domainSuffix,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Text(
                  KioskPinStrings.title,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                Text(
                  _pin.isEmpty ? '••••' : '•' * _pin.length,
                  textAlign: TextAlign.center,
                  style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 12,
                    color: scheme.primary,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                KioskPinPad(onDigit: _tapDigit, onBackspace: _backspace),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(KioskPinStrings.submit, style: textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _submitting ? null : widget.onCancel,
                  child: Text(KioskPinStrings.backToScan),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

