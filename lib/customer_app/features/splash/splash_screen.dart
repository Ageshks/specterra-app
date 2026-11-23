import 'package:flutter/material.dart';

import '../../core/brand_config.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/wave_background.dart';

/// Branded splash: emblem, tagline and animated water hills, exactly the
/// composition shown in the reference artwork.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Green field + water hills at the bottom of the artwork.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.splashGradient),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: WaveBackground(
              colors: AppColors.waveColors,
              animationDuration: const Duration(seconds: 5),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0, 0.7, curve: Curves.easeOut),
                    ),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.86, end: 1).animate(
                        CurvedAnimation(
                          parent: _controller,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                      child: const _SplashLogoCard(),
                    ),
                  ),
                  const SizedBox(height: 34),
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0.35, 1, curve: Curves.easeOut),
                    ),
                    child: Text(
                      BrandConfig.splashTagline,
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        // The lockup now sits on a white card, so the tagline
                        // reads directly against the green field and needs to
                        // invert to stay legible.
                        color: Colors.white,
                        height: 1.45,
                        shadows: const [
                          Shadow(
                            color: Color(0x55000000),
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 4),
                  const SplashPageIndicator(activeIndex: 0),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White card that carries the lockup on the splash screen.
///
/// The brand artwork is dark green, so it needs a light surface to read
/// against the green field behind it.
class _SplashLogoCard extends StatelessWidget {
  const _SplashLogoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: BrandConfig.splashLogoWidth + 48,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const BrandLockup(markSize: 56, showCaption: false),
    );
  }
}

/// Three-dot page indicator mirrored from the splash artwork.
class SplashPageIndicator extends StatelessWidget {
  const SplashPageIndicator({super.key, this.activeIndex = 0, this.count = 3});

  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: isActive ? 26 : 16,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white38,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
