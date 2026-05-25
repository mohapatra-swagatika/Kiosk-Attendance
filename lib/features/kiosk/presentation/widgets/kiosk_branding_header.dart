import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_kiosk_app/features/registration/presentation/providers/registration_providers.dart';

/// Logo + branding banner from locally stored registration assets.
class KioskBrandingHeader extends ConsumerWidget {
  const KioskBrandingHeader({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(kioskConfigProvider);
    final scheme = Theme.of(context).colorScheme;

    return configAsync.when(
      loading: () => const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (config) {
        if (config == null) return const SizedBox.shrink();

        final logoPath = config.logoPath;
        final bannerPath = config.brandingImagePath;
        final logoFile = logoPath != null ? File(logoPath) : null;
        final bannerFile = bannerPath != null ? File(bannerPath) : null;
        final hasLogo = logoFile != null && logoFile.existsSync();
        final hasBanner = bannerFile != null && bannerFile.existsSync();

        if (!hasLogo && !hasBanner) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              config.domain,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

        final logoHeight = compact ? 40.0 : 52.0;
        final bannerHeight = compact ? 64.0 : 88.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, compact ? 12 : 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasBanner)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    bannerFile,
                    key: ValueKey(bannerPath),
                    height: bannerHeight,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              if (hasBanner && hasLogo) const SizedBox(height: 12),
              if (hasLogo)
                Center(
                  child: Container(
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
                    child: Image.file(
                      logoFile,
                      key: ValueKey(logoPath),
                      height: logoHeight,
                      width: logoHeight,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
