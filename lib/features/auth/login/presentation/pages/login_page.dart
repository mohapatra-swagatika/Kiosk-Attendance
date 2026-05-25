import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_kiosk_app/app/router/route_paths.dart';
import 'package:attendance_kiosk_app/app/router/router_refresh.dart';
import 'package:attendance_kiosk_app/app/theme/app_colors.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_pair_api_urls.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/responsive/responsive_builder.dart';
import 'package:attendance_kiosk_app/core/widgets/glass_panel.dart';
import 'package:attendance_kiosk_app/features/auth/login/domain/entities/login_credentials.dart';
import 'package:attendance_kiosk_app/features/auth/login/presentation/providers/login_providers.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

/// Sign-in screen: username, password, login. Mock auth until APIs are ready.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login({bool thenGoKiosk = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final credentials = LoginCredentials(
      username: _user.text.trim(),
      password: _pass.text.trim(),
    );

    final ok = await ref.read(loginFormProvider.notifier).submit(credentials);
    if (!mounted) return;

    if (!ok) {
      final msg = ref.read(loginFormProvider).errorMessage;
      if (msg != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }

    ref.read(routerRefreshProvider).notify();
    if (thenGoKiosk) {
      context.push(RoutePaths.kiosk);
    } else {
      context.go(RoutePaths.home);
    }
  }

  Future<void> _enterKioskMode() async {
    final kiosk = ref.read(kioskModeChannelProvider);
    if (kiosk.isSupported) {
      final ok = await kiosk.enterKioskMode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? LoginStrings.kioskStarted : LoginStrings.kioskStartFailed,
          ),
        ),
      );
    } else if (Platform.isIOS) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(LoginStrings.kioskIosGuidedAccess)),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(LoginStrings.kioskAndroidOnly)),
      );
    }
  }

  Future<void> _exitKioskMode() async {
    final kiosk = ref.read(kioskModeChannelProvider);
    if (!kiosk.isSupported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(LoginStrings.kioskExitAndroidOnly)),
      );
      return;
    }
    final ok = await kiosk.exitKioskMode();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? LoginStrings.kioskExited : LoginStrings.kioskExitFailed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(loginFormProvider);
    final configAsync = ref.watch(kioskConfigProvider);
    final registeredDomain = KioskPairApiUrls.subdomainFromStored(
      configAsync.valueOrNull?.domain ?? '',
    );
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.35),
              scheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: SafeArea(
          child: ResponsiveBuilder(
            builder: (context, breakpoint, constraints) {
              final isTablet = breakpoint != AppBreakpointSize.compact;
              final maxFormWidth = switch (breakpoint) {
                AppBreakpointSize.compact => 440.0,
                AppBreakpointSize.medium => 520.0,
                AppBreakpointSize.expanded => 560.0,
              };
              final horizontalPadding = switch (breakpoint) {
                AppBreakpointSize.compact => 20.0,
                AppBreakpointSize.medium => 32.0,
                AppBreakpointSize.expanded => 48.0,
              };

              final form = _LoginFormCard(
                formKey: _formKey,
                domain: registeredDomain,
                domainLoading: configAsync.isLoading,
                username: _user,
                password: _pass,
                isSubmitting: formState.isSubmitting,
                onSubmit: _login,
                maxWidth: maxFormWidth,
                onStartKioskMode: () => _login(thenGoKiosk: true),
                onEnterKiosk: _enterKioskMode,
                onExitKiosk: _exitKioskMode,
              );

              // Same centered form layout on mobile and tablet (hero panel disabled).
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: isTablet ? 24 : 16,
                  ),
                  child: form,
                ),
              );

              // Tablet side-by-side hero + form (disabled — use unified layout above).
              // return Center(
              //   child: SingleChildScrollView(
              //     padding: EdgeInsets.symmetric(
              //       horizontal: horizontalPadding,
              //       vertical: 24,
              //     ),
              //     child: ConstrainedBox(
              //       constraints: BoxConstraints(
              //         maxWidth: breakpoint == AppBreakpointSize.expanded
              //             ? 1000
              //             : 880,
              //       ),
              //       child: Row(
              //         crossAxisAlignment: CrossAxisAlignment.start,
              //         children: [
              //           Expanded(
              //             flex: breakpoint == AppBreakpointSize.expanded ? 5 : 4,
              //             child: _LoginHeroPanel(breakpoint: breakpoint),
              //           ),
              //           SizedBox(
              //             width: breakpoint == AppBreakpointSize.expanded ? 40 : 28,
              //           ),
              //           Expanded(flex: 6, child: form),
              //         ],
              //       ),
              //     ),
              //   ),
              // );
            },
          ),
        ),
      ),
    );
  }
}

// class _LoginHeroPanel extends StatelessWidget {
//   const _LoginHeroPanel({required this.breakpoint});
//
//   final AppBreakpointSize breakpoint;
//
//   @override
//   Widget build(BuildContext context) {
//     final textTheme = Theme.of(context).textTheme;
//     final scheme = Theme.of(context).colorScheme;
//     final titleStyle = switch (breakpoint) {
//       AppBreakpointSize.medium => textTheme.headlineMedium,
//       AppBreakpointSize.expanded => textTheme.headlineLarge,
//       _ => textTheme.headlineSmall,
//     };
//
//     return GlassPanel(
//       padding: EdgeInsets.all(switch (breakpoint) {
//         AppBreakpointSize.expanded => 32,
//         _ => 24,
//       }),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(Icons.lock_person_rounded, size: 40, color: scheme.primary),
//           const SizedBox(height: 20),
//           Text(
//             LoginStrings.heroTitle,
//             style: titleStyle?.copyWith(fontWeight: FontWeight.w600),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             LoginStrings.heroBody,
//             style: textTheme.bodyLarge?.copyWith(height: 1.45),
//           ),
//           const SizedBox(height: 20),
//           Wrap(
//             spacing: 10,
//             runSpacing: 10,
//             children: const [
//               _InfoChip(icon: Icons.tablet_mac, label: LoginStrings.chipTablet),
//               _InfoChip(icon: Icons.cloud_queue, label: LoginStrings.chipApiReady),
//               _InfoChip(icon: Icons.shield_outlined, label: LoginStrings.chipLocalSession),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _InfoChip extends StatelessWidget {
//   const _InfoChip({required this.icon, required this.label});
//
//   final IconData icon;
//   final String label;
//
//   @override
//   Widget build(BuildContext context) {
//     return Chip(
//       avatar: Icon(icon, size: 18),
//       label: Text(label),
//       visualDensity: VisualDensity.compact,
//       materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//     );
//   }
// }

class _LoginFormCard extends StatefulWidget {
  const _LoginFormCard({
    required this.formKey,
    required this.domain,
    required this.domainLoading,
    required this.username,
    required this.password,
    required this.isSubmitting,
    required this.onSubmit,
    required this.maxWidth,
    required this.onStartKioskMode,
    required this.onEnterKiosk,
    required this.onExitKiosk,
  });

  final GlobalKey<FormState> formKey;
  final String domain;
  final bool domainLoading;
  final TextEditingController username;
  final TextEditingController password;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final double maxWidth;
  final VoidCallback onStartKioskMode;
  final Future<void> Function() onEnterKiosk;
  final Future<void> Function() onExitKiosk;

  @override
  State<_LoginFormCard> createState() => _LoginFormCardState();
}

class _LoginFormCardState extends State<_LoginFormCard> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: GlassPanel(
        padding: const EdgeInsets.all(26),
        child: Form(
          key: widget.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                LoginStrings.formTitle,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                LoginStrings.formSubtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: ValueKey('login-domain-${widget.domain}-${widget.domainLoading}'),
                initialValue: widget.domainLoading ? AppStrings.loadingEllipsis : widget.domain,
                readOnly: true,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: LoginStrings.domainLabel,
                  hintText: LoginStrings.domainHint,
                  prefixIcon: Icon(Icons.domain),
                  suffixText: RegistrationStrings.domainSuffix,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: widget.username,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: LoginStrings.usernameLabel,
                  hintText: LoginStrings.usernameHint,
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? LoginStrings.usernameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: widget.password,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => widget.onSubmit(),
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: LoginStrings.passwordLabel,
                  hintText: LoginStrings.passwordHint,
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? LoginStrings.showPassword
                        : LoginStrings.hidePassword,
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? LoginStrings.passwordRequired
                    : null,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: widget.isSubmitting ? null : widget.onSubmit,
                icon: widget.isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(widget.isSubmitting ? LoginStrings.submitting : LoginStrings.submit),
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Text(
                LoginStrings.kioskSectionTitle,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                LoginStrings.kioskSectionSubtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  foregroundColor: AppColors.primary,
                ),
                onPressed: widget.isSubmitting ? null : widget.onStartKioskMode,
                icon: const Icon(Icons.fullscreen),
                label: const Text(LoginStrings.startKioskMode),
              ),
              const SizedBox(height: 10),

              // Row(
              //   children: [
              //     Expanded(
              //       child: OutlinedButton.icon(
              //         onPressed: isSubmitting ? null : () => onEnterKiosk(),
              //         icon: const Icon(
              //           Icons.screen_lock_portrait_outlined,
              //           size: 20,
              //         ),
              //         label: const Text('Pin device'),
              //       ),
              //     ),
              //     const SizedBox(width: 10),
              //     Expanded(
              //       child: OutlinedButton.icon(
              //         onPressed: isSubmitting ? null : () => onExitKiosk(),
              //         icon: const Icon(Icons.close_fullscreen, size: 20),
              //         label: const Text('Unpin'),
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
