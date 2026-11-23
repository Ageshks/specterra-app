import 'package:flutter/widgets.dart';
import '../widgets/brand_mark.dart';

/// Single place to control the app's branding.
///
/// ## Using your own logo
///
/// 1. Drop the file into `assets/images/` (a PNG with transparency works
///    best, e.g. `assets/images/logo.png`).
/// 2. Point [logoAsset] at it.
/// 3. Hot restart — `flutter run` then `R`.
///
/// The whole `assets/images/` folder is already declared in `pubspec.yaml`,
/// so no pubspec edit is needed as long as the file lives there.
abstract final class BrandConfig {
  /// Full lockup (emblem + wordmark + caption) used on the splash screen.
  /// Set to `null` to fall back to the drawn emblem plus rendered text.
  // ignore: unnecessary_nullable_for_final_variable_declarations
  static const String? logoAsset = 'assets/images/logo.png';

  /// Emblem only, used where there is no room for a wordmark (login, signup).
  /// Set to `null` to reuse [logoAsset] or the drawn emblem.
  // ignore: unnecessary_nullable_for_final_variable_declarations
  static const String? markAsset = 'assets/images/logo_mark.png';

  /// Splash logo width in logical pixels — sized so the lockup sits on a
  /// white card that clears the 390pt viewport with room to spare.
  static const double splashLogoWidth = 264;

  /// Emblem height on the auth screens.
  static const double authMarkHeight = 116;

  /// Tagline shown on the splash screen below the lockup.
  static const String splashTagline =
      'Reliable Water Treatment\nSolutions for a Cleaner\nTomorrow';

  /// Wordmark text, used only when no logo image is configured.
  static const String wordmark = 'SPECTERRA';

  /// Sub-caption under the wordmark.
  static const String caption = 'AN ISO CERTIFIED COMPANY';

  /// True when a real logo asset is configured.
  static bool get hasLogo => logoAsset != null;
}

/// Resolves the emblem to display, preferring the uploaded asset.
///
/// Falls back to the built-in painted mark when no asset is configured, or when
/// the file is missing or corrupt, so the app always renders something.
Widget buildBrandMark({
  required double height,
  double? width,
  BorderRadius? borderRadius,
}) {
  final asset = BrandConfig.markAsset ?? BrandConfig.logoAsset;
  if (asset != null) {
    return Image.asset(
      asset,
      height: height,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) =>
          _PaintedBrandMark(size: height, borderRadius: borderRadius),
    );
  }
  return _PaintedBrandMark(size: height, borderRadius: borderRadius);
}

/// The built-in emblem, kept as a no-asset fallback.
class _PaintedBrandMark extends StatelessWidget {
  const _PaintedBrandMark({required this.size, this.borderRadius});

  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: const BrandMarkPainter(),
        child: borderRadius == null
            ? null
            : ClipRRect(borderRadius: borderRadius!, child: SizedBox.expand()),
      ),
    );
  }
}
