import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import 'package:attendance_kiosk_app/app/app_launch_gate.dart';
import 'package:attendance_kiosk_app/app/app_startup_coordinator.dart';
import 'package:attendance_kiosk_app/app/router/router_refresh.dart';
import 'package:attendance_kiosk_app/app/router/route_paths.dart';
import 'package:attendance_kiosk_app/core/api/kiosk_pair_api_urls.dart';
import 'package:attendance_kiosk_app/core/localization/app_strings.dart';
import 'package:attendance_kiosk_app/core/responsive/responsive_builder.dart';
import 'package:attendance_kiosk_app/core/widgets/glass_panel.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_config.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_form_notifier.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

/// First-time kiosk setup: code, domain, machine name, description, register.
class RegistrationPage extends ConsumerStatefulWidget {
  const RegistrationPage({super.key});

  @override
  ConsumerState<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends ConsumerState<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _domain = TextEditingController();
  final _machine = TextEditingController();
  final _description = TextEditingController();
  final _canSubmit = ValueNotifier<bool>(false);
  late final VoidCallback _onFieldsChanged;

  @override
  void initState() {
    super.initState();
    _onFieldsChanged = () {
      final can = _code.text.trim().isNotEmpty &&
          _domain.text.trim().isNotEmpty &&
          _machine.text.trim().isNotEmpty &&
          _description.text.trim().isNotEmpty;
      if (can != _canSubmit.value) _canSubmit.value = can;
    };
    _code.addListener(_onFieldsChanged);
    _domain.addListener(_onFieldsChanged);
    _machine.addListener(_onFieldsChanged);
    _description.addListener(_onFieldsChanged);
    _onFieldsChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirectIfAlreadyRegistered());
  }

  void _redirectIfAlreadyRegistered() {
    if (!mounted) return;
    if (AppLaunchGate.isCached && AppLaunchGate.cached.hasConfig) {
      context.go(RoutePaths.kiosk);
    }
  }

  @override
  void dispose() {
    _code.removeListener(_onFieldsChanged);
    _domain.removeListener(_onFieldsChanged);
    _machine.removeListener(_onFieldsChanged);
    _description.removeListener(_onFieldsChanged);
    _code.dispose();
    _domain.dispose();
    _machine.dispose();
    _description.dispose();
    _canSubmit.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!ref.read(appStartupCoordinatorProvider).storageReady) return;

    final config = KioskConfig(
      code: _code.text.trim(),
      domain: KioskPairApiUrls.toApiHost(_domain.text.trim()),
      machineName: _machine.text.trim(),
      description: _description.text.trim(),
    );

    final ok = await ref.read(registrationFormProvider.notifier).submit(config);
    if (!mounted) return;

    if (!ok) {
      final msg = ref.read(registrationFormProvider).errorMessage;
      if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(RegistrationStrings.offlineSavedNote)),
    );

    final adminPin = ref.read(registrationFormProvider).assignedAdminPin;
    if (adminPin != null && adminPin.isNotEmpty) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text(RegistrationStrings.adminPinDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(RegistrationStrings.adminPinDialogBody),
              const SizedBox(height: 16),
              SelectableText(
                adminPin,
                style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(RegistrationStrings.adminPinContinue),
            ),
          ],
        ),
      );
    }

    if (!mounted) return;
    ref.invalidate(kioskConfigProvider);
    await ref.read(routerRefreshProvider).reloadAndNotify();
    if (!mounted) return;
    context.go(RoutePaths.kiosk);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      appStartupCoordinatorProvider.select((s) => s.storageReady),
      (prev, ready) {
        if (ready == true) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _redirectIfAlreadyRegistered(),
          );
        }
      },
    );
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // Manual scroll padding below — avoids relayout of the whole form on each
      // keyboard inset frame (resizeToAvoidBottomInset shrinks body constraints).
      resizeToAvoidBottomInset: false,
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
                AppBreakpointSize.compact => 520.0,
                AppBreakpointSize.medium => 720.0,
                AppBreakpointSize.expanded => 880.0,
              };
              final horizontalPadding = switch (breakpoint) {
                AppBreakpointSize.compact => 20.0,
                AppBreakpointSize.medium => 32.0,
                AppBreakpointSize.expanded => 48.0,
              };

              // Same centered form layout on mobile and tablet (hero panel disabled).
              return Center(
                child: RepaintBoundary(
                  child: _RegistrationFormScroll(
                    horizontalPadding: horizontalPadding,
                    verticalPadding: isTablet ? 24 : 16,
                    child: _RegistrationFormCard(
                      key: const ValueKey('registration-form-card'),
                      formKey: _formKey,
                      code: _code,
                      domain: _domain,
                      machine: _machine,
                      description: _description,
                      canSubmitListenable: _canSubmit,
                      onSubmit: _submit,
                      maxWidth: maxFormWidth,
                      twoColumnFields: isTablet,
                      descriptionMaxLines: isTablet ? 4 : 3,
                    ),
                  ),
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
              //             ? 1100
              //             : 960,
              //       ),
              //       child: Row(
              //         crossAxisAlignment: CrossAxisAlignment.start,
              //         children: [
              //           Expanded(
              //             flex: breakpoint == AppBreakpointSize.expanded ? 5 : 4,
              //             child: _RegistrationHeroPanel(breakpoint: breakpoint),
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

// class _RegistrationHeroPanel extends StatelessWidget {
//   const _RegistrationHeroPanel({required this.breakpoint});
//
//   final AppBreakpointSize breakpoint;
//
//   @override
//   Widget build(BuildContext context) {
//     final textTheme = Theme.of(context).textTheme;
//     final scheme = Theme.of(context).colorScheme;
//     final titleSize = switch (breakpoint) {
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
//           Icon(Icons.display_settings_rounded, size: 40, color: scheme.primary),
//           const SizedBox(height: 20),
//           Text(
//             RegistrationStrings.heroTitle,
//             style: titleSize?.copyWith(fontWeight: FontWeight.w600),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             RegistrationStrings.heroBody,
//             style: textTheme.bodyLarge?.copyWith(height: 1.45),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _InfoChip extends StatelessWidget {
//   const _InfoChip({required this.icon, required this.label});

//   final IconData icon;
//   final String label;

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

class _RegistrationFormCard extends StatefulWidget {
  const _RegistrationFormCard({
    super.key,
    required this.formKey,
    required this.code,
    required this.domain,
    required this.machine,
    required this.description,
    required this.canSubmitListenable,
    required this.onSubmit,
    required this.maxWidth,
    required this.twoColumnFields,
    required this.descriptionMaxLines,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController code;
  final TextEditingController domain;
  final TextEditingController machine;
  final TextEditingController description;
  final ValueListenable<bool> canSubmitListenable;
  final VoidCallback onSubmit;
  final double maxWidth;
  final bool twoColumnFields;
  final int descriptionMaxLines;

  @override
  State<_RegistrationFormCard> createState() => _RegistrationFormCardState();
}

class _RegistrationFormCardState extends State<_RegistrationFormCard> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fieldGap = widget.twoColumnFields ? 16.0 : 12.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: GlassPanel(
        padding: EdgeInsets.all(widget.twoColumnFields ? 28 : 22),
        // Avoid BackdropFilter blur here: on iOS first-launch + keyboard focus can
        // stutter/hang when large blurred surfaces need re-rasterization.
        blurSigma: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _RegistrationStorageBanner(),
            Text(
              RegistrationStrings.heroTitle,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              RegistrationStrings.heroBody,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: widget.twoColumnFields ? 28 : 20),
            RepaintBoundary(
              child: Form(
                key: widget.formKey,
                child: _RegistrationFormFields(
                  code: widget.code,
                  domain: widget.domain,
                  machine: widget.machine,
                  description: widget.description,
                  onSubmit: widget.onSubmit,
                  twoColumnFields: widget.twoColumnFields,
                  descriptionMaxLines: widget.descriptionMaxLines,
                  fieldGap: fieldGap,
                ),
              ),
            ),
            SizedBox(height: widget.twoColumnFields ? 28 : 22),
            _RegistrationSubmitButton(
              canSubmitListenable: widget.canSubmitListenable,
              onSubmit: widget.onSubmit,
              twoColumnFields: widget.twoColumnFields,
            ),
          ],
        ),
      ),
    );
  }
}

/// Text inputs only — kept separate so keyboard inset / submit state do not
/// rebuild fields while they are focused.
class _RegistrationFormFields extends StatelessWidget {
  const _RegistrationFormFields({
    required this.code,
    required this.domain,
    required this.machine,
    required this.description,
    required this.onSubmit,
    required this.twoColumnFields,
    required this.descriptionMaxLines,
    required this.fieldGap,
  });

  final TextEditingController code;
  final TextEditingController domain;
  final TextEditingController machine;
  final TextEditingController description;
  final VoidCallback onSubmit;
  final bool twoColumnFields;
  final int descriptionMaxLines;
  final double fieldGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (twoColumnFields)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _RegistrationCodeField(controller: code)),
              SizedBox(width: fieldGap),
              Expanded(child: _RegistrationDomainField(controller: domain)),
            ],
          )
        else ...[
          _RegistrationCodeField(controller: code),
          SizedBox(height: fieldGap),
          _RegistrationDomainField(controller: domain),
        ],
        SizedBox(height: fieldGap),
        _RegistrationMachineField(controller: machine),
        SizedBox(height: fieldGap),
        _RegistrationDescriptionField(
          controller: description,
          onSubmit: onSubmit,
          maxLines: descriptionMaxLines,
          minLines: twoColumnFields ? 3 : 2,
        ),
      ],
    );
  }
}

class _RegistrationCodeField extends StatelessWidget {
  const _RegistrationCodeField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: RegistrationStrings.codeLabel,
        hintText: RegistrationStrings.codeHint,
        prefixIcon: Icon(Icons.tag),
      ),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? RegistrationStrings.codeRequired
          : null,
    );
  }
}

class _RegistrationDomainField extends StatelessWidget {
  const _RegistrationDomainField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.text,
      decoration: const InputDecoration(
        labelText: RegistrationStrings.domainLabel,
        hintText: RegistrationStrings.domainHint,
        prefixIcon: Icon(Icons.domain),
        suffixText: RegistrationStrings.domainSuffix,
      ),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? RegistrationStrings.domainRequired
          : null,
    );
  }
}

class _RegistrationMachineField extends StatelessWidget {
  const _RegistrationMachineField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: RegistrationStrings.machineLabel,
        hintText: RegistrationStrings.machineHint,
        prefixIcon: Icon(Icons.precision_manufacturing_outlined),
      ),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? RegistrationStrings.machineRequired
          : null,
    );
  }
}

class _RegistrationDescriptionField extends StatelessWidget {
  const _RegistrationDescriptionField({
    required this.controller,
    required this.onSubmit,
    required this.maxLines,
    required this.minLines,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final int maxLines;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => onSubmit(),
      maxLines: maxLines,
      minLines: minLines,
      decoration: const InputDecoration(
        labelText: RegistrationStrings.descriptionLabel,
        hintText: RegistrationStrings.descriptionHint,
        alignLabelWithHint: true,
        prefixIcon: Icon(Icons.notes_outlined),
      ),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? RegistrationStrings.descriptionRequired
          : null,
    );
  }
}

/// Applies keyboard bottom inset only here so opening the keyboard does not
/// rebuild the registration form fields.
class _RegistrationFormScroll extends StatelessWidget {
  const _RegistrationFormScroll({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.child,
  });

  final double horizontalPadding;
  final double verticalPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding,
        horizontalPadding,
        verticalPadding + keyboardBottom,
      ),
      child: child,
    );
  }
}

/// Isolated from text fields so storage init does not rebuild inputs mid-focus.
class _RegistrationStorageBanner extends ConsumerWidget {
  const _RegistrationStorageBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageReady = ref.watch(
      appStartupCoordinatorProvider.select((s) => s.storageReady),
    );
    if (storageReady) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: LinearProgressIndicator(minHeight: 3),
    );
  }
}

class _RegistrationSubmitButton extends ConsumerWidget {
  const _RegistrationSubmitButton({
    required this.canSubmitListenable,
    required this.onSubmit,
    required this.twoColumnFields,
  });

  final ValueListenable<bool> canSubmitListenable;
  final VoidCallback onSubmit;
  final bool twoColumnFields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageReady = ref.watch(
      appStartupCoordinatorProvider.select((s) => s.storageReady),
    );
    final isSubmitting = ref.watch(
      registrationFormProvider.select((s) => s.isSubmitting),
    );

    Widget submitButton(bool canSubmit) {
      final registerEnabled = canSubmit && !isSubmitting && storageReady;
      final label = !storageReady
          ? RegistrationStrings.preparingStorage
          : isSubmitting
              ? RegistrationStrings.submitting
              : RegistrationStrings.submit;
      if (twoColumnFields) {
        return Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 18,
              ),
              minimumSize: const Size(200, 52),
            ),
            onPressed: registerEnabled ? onSubmit : null,
            icon: isSubmitting || !storageReady
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.app_registration_rounded),
            label: Text(label),
          ),
        );
      }
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          minimumSize: const Size(double.infinity, 52),
        ),
        onPressed: registerEnabled ? onSubmit : null,
        icon: isSubmitting || !storageReady
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.app_registration_rounded),
        label: Text(label),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: canSubmitListenable,
      builder: (context, can, _) => submitButton(can),
    );
  }
}
