import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

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
    ref.read(routerRefreshProvider).notify();
    context.go(RoutePaths.kiosk);
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting =
        ref.watch(registrationFormProvider.select((s) => s.isSubmitting));
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
                AppBreakpointSize.compact => 520.0,
                AppBreakpointSize.medium => 720.0,
                AppBreakpointSize.expanded => 880.0,
              };
              final horizontalPadding = switch (breakpoint) {
                AppBreakpointSize.compact => 20.0,
                AppBreakpointSize.medium => 32.0,
                AppBreakpointSize.expanded => 48.0,
              };

              final form = _RegistrationFormCard(
                formKey: _formKey,
                code: _code,
                domain: _domain,
                machine: _machine,
                description: _description,
                isSubmitting: isSubmitting,
                canSubmitListenable: _canSubmit,
                onSubmit: _submit,
                maxWidth: maxFormWidth,
                twoColumnFields: isTablet,
                descriptionMaxLines: isTablet ? 4 : 3,
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

class _RegistrationFormCard extends StatelessWidget {
  const _RegistrationFormCard({
    required this.formKey,
    required this.code,
    required this.domain,
    required this.machine,
    required this.description,
    required this.isSubmitting,
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
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final ValueListenable<bool> canSubmitListenable;

  final double maxWidth;
  final bool twoColumnFields;
  final int descriptionMaxLines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget codeField() => TextFormField(
      controller: code,
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

    Widget domainField() => TextFormField(
      controller: domain,
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

    Widget machineField() => TextFormField(
      controller: machine,
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

    Widget descriptionField() => TextFormField(
      controller: description,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => onSubmit(),
      maxLines: descriptionMaxLines,
      minLines: twoColumnFields ? 3 : 2,
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

    final fieldGap = twoColumnFields ? 16.0 : 12.0;

    Widget submitButton(bool canSubmit) {
      final registerEnabled = canSubmit && !isSubmitting;
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
            icon: isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.app_registration_rounded),
            label: Text(
              isSubmitting ? RegistrationStrings.submitting : RegistrationStrings.submit,
            ),
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
        icon: isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.app_registration_rounded),
        label: Text(
          isSubmitting ? RegistrationStrings.submitting : RegistrationStrings.submit,
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GlassPanel(
        padding: EdgeInsets.all(twoColumnFields ? 28 : 22),
        // Avoid BackdropFilter blur here: on iOS first-launch + keyboard focus can
        // stutter/hang when large blurred surfaces need re-rasterization.
        blurSigma: 0,
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              SizedBox(height: twoColumnFields ? 28 : 20),
              if (twoColumnFields)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: codeField()),
                    SizedBox(width: fieldGap),
                    Expanded(child: domainField()),
                  ],
                )
              else ...[
                codeField(),
                SizedBox(height: fieldGap),
                domainField(),
              ],
              SizedBox(height: fieldGap),
              machineField(),
              SizedBox(height: fieldGap),
              descriptionField(),
              SizedBox(height: twoColumnFields ? 28 : 22),
              ValueListenableBuilder<bool>(
                valueListenable: canSubmitListenable,
                builder: (context, can, _) => submitButton(can),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
