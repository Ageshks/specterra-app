import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Animated layered "water hills" used on the splash and sign-in screens.
class WaveBackground extends StatefulWidget {
  const WaveBackground({
    super.key,
    this.colors = AppColors.waveColors,
    this.amplitudeFactor = 1,
    this.animationDuration = const Duration(seconds: 6),
    this.animate = true,
  });

  final List<Color> colors;
  final double amplitudeFactor;
  final Duration animationDuration;
  final bool animate;

  @override
  State<WaveBackground> createState() => _WaveBackgroundState();
}

class _WaveBackgroundState extends State<WaveBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.animationDuration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _WavePainter(
            colors: widget.colors,
            amplitudeFactor: widget.amplitudeFactor,
            phase: _controller.value,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.colors,
    required this.amplitudeFactor,
    required this.phase,
  });

  final List<Color> colors;
  final double amplitudeFactor;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    for (var i = 0; i < colors.length; i++) {
      final progress = i / math.max(1, colors.length - 1);
      final amplitude =
          size.height * (0.05 + 0.022 * (i % 3)) * amplitudeFactor;
      final baseY = size.height * (0.40 + 0.115 * progress);
      canvas.drawPath(
        _wavePath(
          size: size,
          baseY: baseY,
          amplitude: amplitude,
          offset: i * 0.85,
        ),
        Paint()..color = colors[i],
      );
    }
  }

  Path _wavePath({
    required Size size,
    required double baseY,
    required double amplitude,
    required double offset,
  }) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, baseY);

    const segments = 3;
    final step = size.width / segments;
    for (var i = 0; i < segments; i++) {
      final startX = step * i;
      final peak =
          baseY -
          amplitude *
              (0.5 + 0.5 * math.sin(phase * 2 * math.pi + offset + i * 0.8));
      path.cubicTo(
        startX + step * 0.35,
        peak,
        startX + step * 0.65,
        peak,
        startX + step,
        baseY,
      );
    }

    path
      ..lineTo(size.width, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.colors != colors;
}
