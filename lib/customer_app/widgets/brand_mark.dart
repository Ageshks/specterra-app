import 'package:flutter/material.dart';

import '../core/brand_config.dart';
import '../core/theme/app_colors.dart';

/// The brand emblem. Renders the uploaded emblem at
/// [BrandConfig.markAsset] when one is configured, otherwise draws the
/// built-in SPECTERRA diamond mark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.height = 92, this.width, this.borderRadius});

  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return buildBrandMark(
      height: height,
      width: width,
      borderRadius: borderRadius,
    );
  }
}

/// Full lockup for the splash screen.
///
/// When a logo image is configured it is shown on its own, because the artwork
/// already contains the emblem, the wordmark and the certification caption.
/// With no image configured the app falls back to the drawn emblem plus text.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.markSize = 72,
    this.color = AppColors.forestDeep,
    this.captionColor,
    this.showCaption = true,
  });

  final double markSize;
  final Color color;
  final Color? captionColor;
  final bool showCaption;

  @override
  Widget build(BuildContext context) {
    final asset = BrandConfig.logoAsset;
    if (asset != null) {
      return Image.asset(
        asset,
        width: BrandConfig.splashLogoWidth,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => _textLockup(context),
      );
    }
    return _textLockup(context);
  }

  Widget _textLockup(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildBrandMark(height: markSize),
        SizedBox(height: markSize * 0.16),
        Text(
          BrandConfig.wordmark,
          style: textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        if (showCaption) ...[
          const SizedBox(height: 6),
          Text(
            BrandConfig.caption,
            textAlign: TextAlign.center,
            style: textTheme.labelSmall?.copyWith(
              color: captionColor ?? color.withValues(alpha: 0.7),
              letterSpacing: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// Paints the built-in emblem. Kept public so [BrandConfig]'s fallback path
/// and any custom header can reuse it.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({this.color});

  /// Overrides the brand gradient with a single colour when provided.
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final unit = size.shortestSide / 100;

    Path diamond(double cx, double cy, double half, double radius) {
      return Path()
        ..addPolygon(<Offset>[
          Offset(cx, cy - half),
          Offset(cx + half, cy),
          Offset(cx, cy + half),
          Offset(cx - half, cy),
        ], true)
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: half * 1.34,
              height: half * 1.34,
            ),
            Radius.circular(radius),
          ),
        );
    }

    final Paint fill = color != null
        ? (Paint()..color = color!)
        : (Paint()
            ..shader = AppColors.brandGradient.createShader(rect)
            ..style = PaintingStyle.fill);

    // Two overlapping diamonds separated by a white gap form the "S" mark.
    canvas.drawPath(diamond(unit * 48, unit * 42, unit * 33, unit * 7), fill);
    canvas.drawPath(
      diamond(unit * 58, unit * 56, unit * 26, unit * 6),
      Paint()..color = Colors.white,
    );
    canvas.drawPath(diamond(unit * 60, unit * 58, unit * 17, unit * 5), fill);
  }

  @override
  bool shouldRepaint(covariant BrandMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
