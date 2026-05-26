import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'package:attendance_kiosk_app/features/registration/domain/entities/kiosk_config.dart';

/// Persists logo and branding banner locally for reliable offline kiosk display.
class BrandingAssetCache {
  const BrandingAssetCache();

  static const String logoFileName = 'logo.png';
  static const String bannerFileName = 'banner.png';

  Future<BrandingPaths> persist({
    String? logoUrl,
    String? brandingImageUrl,
    required String orgCode,
  }) async {
    final dir = await _brandingDir();
    final logoPath = '${dir.path}/$logoFileName';
    final bannerPath = '${dir.path}/$bannerFileName';

    final logoOk = await _persistFile(
      targetPath: logoPath,
      remoteUrl: logoUrl,
      placeholder: () => _logoPlaceholder(orgCode),
    );
    final bannerOk = await _persistFile(
      targetPath: bannerPath,
      remoteUrl: brandingImageUrl,
      placeholder: () => _bannerPlaceholder(orgCode),
    );

    return BrandingPaths(
      logoPath: logoOk ? logoPath : null,
      brandingImagePath: bannerOk ? bannerPath : null,
    );
  }

  /// Verifies files on disk; re-downloads or regenerates placeholders if missing.
  Future<KioskConfig> ensureLocalAssets(KioskConfig config) async {
    final dir = await _brandingDir();
    final logoPath = '${dir.path}/$logoFileName';
    final bannerPath = '${dir.path}/$bannerFileName';

    var logoOk = await _fileUsable(logoPath);
    var bannerOk = await _fileUsable(bannerPath);

    if (!logoOk) {
      logoOk = await _persistFile(
        targetPath: logoPath,
        remoteUrl: config.logoUrl,
        placeholder: () => _logoPlaceholder(config.organizationCode),
      );
    }
    final useOrganizationBranding = config.organization != null;
    if (!useOrganizationBranding && !bannerOk) {
      bannerOk = await _persistFile(
        targetPath: bannerPath,
        remoteUrl: config.brandingImageUrl,
        placeholder: () => _bannerPlaceholder(config.organizationCode),
      );
    }

    return config.copyWith(
      logoPath: logoOk ? logoPath : config.logoPath,
      brandingImagePath: useOrganizationBranding
          ? null
          : (bannerOk ? bannerPath : config.brandingImagePath),
    );
  }

  Future<bool> _fileUsable(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      return await file.length() > 32;
    } catch (_) {
      return false;
    }
  }

  Future<Directory> _brandingDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/branding');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<bool> _persistFile({
    required String targetPath,
    required String? remoteUrl,
    required List<int> Function() placeholder,
  }) async {
    try {
      if (remoteUrl != null &&
          remoteUrl.isNotEmpty &&
          remoteUrl.startsWith('http')) {
        final client = HttpClient();
        try {
          final request = await client.getUrl(Uri.parse(remoteUrl));
          final response = await request.close();
          if (response.statusCode == 200) {
            final bytes = await response.fold<List<int>>(
              <int>[],
              (prev, chunk) => prev..addAll(chunk),
            );
            if (bytes.length > 32) {
              await File(targetPath).writeAsBytes(bytes, flush: true);
              return true;
            }
          }
        } finally {
          client.close();
        }
      }
      await File(targetPath).writeAsBytes(placeholder(), flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  List<int> _logoPlaceholder(String orgCode) {
    final initial = orgCode.trim().isNotEmpty ? orgCode.trim()[0].toUpperCase() : 'K';
    final image = img.Image(width: 120, height: 120);
    img.fill(image, color: img.ColorRgb8(30, 64, 175));
    img.drawString(
      image,
      initial,
      font: img.arial24,
      x: 44,
      y: 46,
      color: img.ColorRgb8(255, 255, 255),
    );
    return img.encodePng(image);
  }

  List<int> _bannerPlaceholder(String orgCode) {
    final label = orgCode.trim().isNotEmpty ? orgCode.trim() : 'Attendance';
    final image = img.Image(width: 480, height: 120);
    img.fill(image, color: img.ColorRgb8(15, 23, 42));
    img.drawString(
      image,
      label,
      font: img.arial24,
      x: 16,
      y: 46,
      color: img.ColorRgb8(248, 250, 252),
    );
    return img.encodePng(image);
  }
}

class BrandingPaths {
  const BrandingPaths({this.logoPath, this.brandingImagePath});

  final String? logoPath;
  final String? brandingImagePath;
}
