import 'package:flutter/material.dart';

/// SPECTERRA brand palette: emerald / olive greens with pale mint surfaces
/// and charcoal typography, derived from the supplied reference designs.
abstract final class AppColors {
  // Brand greens
  static const Color forestDeep = Color(0xFF0E3B24);
  static const Color primaryDark = Color(0xFF11512F);
  static const Color primary = Color(0xFF17693F);
  static const Color primaryLight = Color(0xFF2E8B57);
  static const Color lime = Color(0xFF7CB342);
  static const Color limeSoft = Color(0xFFAED581);
  static const Color mintSoft = Color(0xFFE8F3E6);
  static const Color mint = Color(0xFFD3E8D5);

  // Neutrals
  static const Color ink = Color(0xFF16261D);

  /// Primary body text colour. Alias of [ink] used across the widget layer.
  static const Color text = ink;
  static const Color inkSoft = Color(0xFF3D4C44);
  static const Color muted = Color(0xFF7B8C84);
  static const Color hint = Color(0xFFA9B7B1);
  static const Color border = Color(0xFFE2EBE6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5F8F6);
  static const Color backgroundAlt = Color(0xFFEDF3EF);

  // Status colors
  static const Color info = Color(0xFF1B6FC4);
  static const Color infoSoft = Color(0xFFE4F0FB);
  static const Color warning = Color(0xFFA86A08);
  static const Color warningSoft = Color(0xFFFDF1DC);
  static const Color danger = Color(0xFFC0392B);
  static const Color dangerSoft = Color(0xFFFDECEA);
  static const Color success = Color(0xFF2C7A4B);
  static const Color successSoft = Color(0xFFE4F3E9);

  /// Dark green header gradient used on the home and detail screens.
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C7A49), Color(0xFF116034), Color(0xFF0C4526)],
    stops: [0, 0.55, 1],
  );

  /// Splash screen backdrop (the green field behind the white card).
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2E8B57), Color(0xFF17693F), Color(0xFF0D4A2B)],
  );

  /// Layered "water hills" seen at the bottom of the splash artwork.
  static const List<Color> waveColors = [
    Color(0xFFE8F4D2),
    Color(0xFFCBEA9E),
    Color(0xFFA7DC79),
    Color(0xFF63B84E),
    Color(0xFF2E8B45),
    Color(0xFF14663A),
  ];

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF63B84E), Color(0xFF14663A)],
  );

  /// Soft accent used behind hero cards and illustration tiles.
  static const LinearGradient tileGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF1F8EC), Color(0xFFDCEEDD)],
  );
}
