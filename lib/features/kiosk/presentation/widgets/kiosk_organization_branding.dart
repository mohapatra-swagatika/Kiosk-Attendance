import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/core/api/kiosk_pair_api_urls.dart';
import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_config.dart';
import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

/// Organization logo ([companyLogoUrl]) and [companyName] from pair API branding.
class KioskOrganizationBranding extends ConsumerWidget {
  const KioskOrganizationBranding({
    super.key,
    this.compact = false,
    this.padding,
    this.centered = true,
  });

  final bool compact;
  final EdgeInsetsGeometry? padding;
  final bool centered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(kioskConfigProvider);

    return configAsync.when(
      loading: () => SizedBox(
        height: compact ? 48 : 72,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (config) {
        if (config == null) return const SizedBox.shrink();
        return _BrandingContent(
          config: config,
          compact: compact,
          padding: padding,
          centered: centered,
        );
      },
    );
  }
}

class _BrandingContent extends StatelessWidget {
  const _BrandingContent({
    required this.config,
    required this.compact,
    required this.padding,
    required this.centered,
  });

  final KioskConfig config;
  final bool compact;
  final EdgeInsetsGeometry? padding;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final companyName = config.companyNameForDisplay;
    final logo = _OrganizationLogo(config: config, compact: compact);
    final hasLogo = logo.hasImage;
    final hasCompany = companyName.isNotEmpty;

    if (!hasLogo && !hasCompany) {
      return const SizedBox.shrink();
    }

    final defaultPadding = compact
        ? const EdgeInsets.fromLTRB(16, 12, 16, 8)
        : const EdgeInsets.fromLTRB(16, 16, 16, 8);

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (hasLogo) logo,
        if (hasLogo && hasCompany) SizedBox(height: compact ? 8 : 12),
        if (hasCompany)
          Text(
            companyName,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: (compact ? textTheme.titleSmall : textTheme.titleMedium)
                ?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );

    return Padding(
      padding: padding ?? defaultPadding,
      child: centered ? column : column,
    );
  }
}

class _OrganizationLogo extends StatelessWidget {
  const _OrganizationLogo({required this.config, required this.compact});

  final KioskConfig config;
  final bool compact;

  bool get hasImage => _localFile != null || _remoteUrl != null;

  File? get _localFile {
    final path = config.logoPath;
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  String? get _remoteUrl {
    return KioskPairApiUrls.resolveAssetUrl(
      config.companyLogoUrlForDisplay,
      config.apiBaseUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = compact ? 40.0 : 56.0;
    final local = _localFile;
    final remote = _remoteUrl;

    Widget image;
    if (local != null) {
      image = Image.file(
        local,
        key: ValueKey(local.path),
        height: height,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else if (remote != null && remote.isNotEmpty) {
      image = Image.network(
        remote,
        key: ValueKey(remote),
        height: height,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: image,
    );
  }
}
