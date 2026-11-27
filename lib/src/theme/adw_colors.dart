import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Official GNOME Libadwaita 1.10+ color palette tokens and CSS color engine.
///
/// Provides the upstream GNOME color palette (`blue1`..`dark5`), the 9 official
/// GNOME 47+ accent colors, and pure-Dart implementations of Libadwaita 1.6+'s
/// `color-mix(in srgb, ...)` ([colorMix], [colorMixTransparent]) and OKLab
/// standalone color transforms ([standaloneOklab], [standaloneOklabOver]).
///
/// {@category Theming & Localization}
abstract final class AdwColors {
  // --- Blues ---
  static const Color blue1 = Color(0xFF99C1F1);
  static const Color blue2 = Color(0xFF62A0EA);
  static const Color blue3 = Color(0xFF3584E4); // Default accent color
  static const Color blue4 = Color(0xFF1C71D8);
  static const Color blue5 = Color(0xFF1A5FB4);

  // --- Greens ---
  static const Color green1 = Color(0xFF8FF0A4);
  static const Color green2 = Color(0xFF57E389);
  static const Color green3 = Color(0xFF33D17A);
  static const Color green4 = Color(0xFF2EC27E);
  static const Color green5 = Color(0xFF26A269);

  // --- Yellows ---
  static const Color yellow1 = Color(0xFFF9F06B);
  static const Color yellow2 = Color(0xFFF8E45C);
  static const Color yellow3 = Color(0xFFF6D32D);
  static const Color yellow4 = Color(0xFFF5C211);
  static const Color yellow5 = Color(0xFFE5A50A);

  // --- Oranges ---
  static const Color orange1 = Color(0xFFFFBE6F);
  static const Color orange2 = Color(0xFFFFA348);
  static const Color orange3 = Color(0xFFFF7800);
  static const Color orange4 = Color(0xFFE66100);
  static const Color orange5 = Color(0xFFC64600);

  // --- Reds / Destructive ---
  static const Color red1 = Color(0xFFF66151);
  static const Color red2 = Color(0xFFED333B);
  static const Color red3 = Color(0xFFE01B24); // Destructive light
  static const Color red4 = Color(0xFFC01C28); // Destructive dark
  static const Color red5 = Color(0xFFA51D2D);

  // --- Purples ---
  static const Color purple1 = Color(0xFFDC8ADD);
  static const Color purple2 = Color(0xFFC061CB);
  static const Color purple3 = Color(0xFF9141AC);
  static const Color purple4 = Color(0xFF813D9C);
  static const Color purple5 = Color(0xFF613583);

  // --- Browns ---
  static const Color brown1 = Color(0xFFCDAB8F);
  static const Color brown2 = Color(0xFFB5835A);
  static const Color brown3 = Color(0xFF986A44);
  static const Color brown4 = Color(0xFF865E3C);
  static const Color brown5 = Color(0xFF63452C);

  // --- Light Scale ---
  static const Color light1 = Color(0xFFFFFFFF);
  static const Color light2 = Color(0xFFF6F5F4);
  static const Color light3 = Color(0xFFDEDDDA);
  static const Color light4 = Color(0xFFC0BFBC);
  static const Color light5 = Color(0xFF9A9996);

  // --- Dark Scale ---
  static const Color dark1 = Color(0xFF77767B);
  static const Color dark2 = Color(0xFF5E5C64);
  static const Color dark3 = Color(0xFF3D3846);
  static const Color dark4 = Color(0xFF241F31);
  static const Color dark5 = Color(0xFF000000);

  // --- Official GNOME 47+ Accent Colors (Libadwaita _colors.scss) ---
  static const Color accentBlue = Color(0xFF3584E4);
  static const Color accentTeal = Color(0xFF2190A4);
  static const Color accentGreen = Color(0xFF3A944A);
  static const Color accentYellow = Color(0xFFC88800);
  static const Color accentOrange = Color(0xFFED5B00);
  static const Color accentRed = Color(0xFFE62D42);
  static const Color accentPink = Color(0xFFD56199);
  static const Color accentPurple = Color(0xFF9141AC);
  static const Color accentSlate = Color(0xFF6F8396);

  // --- Libadwaita 1.6+ CSS Color Engine (color-mix & OKLab) ---

  /// Implements CSS `color-mix(in srgb, <color> <ratio>, transparent)`.
  ///
  /// Preserves the color's existing alpha channel by multiplying `color.a * ratio`,
  /// matching GTK4/Libadwaita light mode where `currentColor` is `rgb(0 0 6 / 80%)`.
  static Color colorMixTransparent(Color color, double ratio) {
    return color.withValues(alpha: (color.a * ratio).clamp(0.0, 1.0));
  }

  /// Implements CSS `color-mix(in srgb, <a> <ratioA>, <b>)`.
  static Color colorMix(Color a, double ratioA, Color b) {
    return Color.lerp(b, a, ratioA.clamp(0.0, 1.0))!;
  }

  /// Implements Libadwaita's `--standalone-color-oklab` transform:
  /// - Light mode: `oklab(from <bg> min(l, 0.5) a b)`
  /// - Dark / OSD mode: `oklab(from <bg> max(l, 0.85) a b)`
  static Color standaloneOklab(Color bg, {required bool isDark}) {
    final (r, g, b) = _standaloneOklabUnclampedSrgb(bg, isDark: isDark);
    return Color.from(
      alpha: bg.a,
      red: r.clamp(0.0, 1.0),
      green: g.clamp(0.0, 1.0),
      blue: b.clamp(0.0, 1.0),
    );
  }

  /// Composites `color-mix(in srgb, oklab(from <bg> ...) <opacity>, transparent)`
  /// over [surface] in extended sRGB before clamping, matching GTK4's compositor.
  ///
  /// Prevents out-of-gamut OKLab channels (e.g. dark-mode blue `B ≈ 1.22`)
  /// from clipping prematurely before alpha blending.
  static Color standaloneOklabOver(
    Color bg, {
    required bool isDark,
    required double opacity,
    required Color surface,
  }) {
    final (r, g, b) = _standaloneOklabUnclampedSrgb(bg, isDark: isDark);
    final double inv = 1.0 - opacity;
    return Color.from(
      alpha: 1.0,
      red: (r * opacity + surface.r * inv).clamp(0.0, 1.0),
      green: (g * opacity + surface.g * inv).clamp(0.0, 1.0),
      blue: (b * opacity + surface.b * inv).clamp(0.0, 1.0),
    );
  }

  static (double, double, double) _standaloneOklabUnclampedSrgb(
    Color bg, {
    required bool isDark,
  }) {
    final double r = _srgbToLinear(bg.r);
    final double g = _srgbToLinear(bg.g);
    final double b = _srgbToLinear(bg.b);

    final double l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
    final double m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
    final double s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

    final double lCbrt = _cbrt(l);
    final double mCbrt = _cbrt(m);
    final double sCbrt = _cbrt(s);

    final double okL =
        0.2104542553 * lCbrt + 0.7936177850 * mCbrt - 0.0040720468 * sCbrt;
    final double okA =
        1.9779984951 * lCbrt - 2.4285922050 * mCbrt + 0.4505937099 * sCbrt;
    final double okB =
        0.0259040371 * lCbrt + 0.7827717662 * mCbrt - 0.8086757660 * sCbrt;

    final double clampedL =
        isDark ? math.max(okL, 0.85) : math.min(okL, 0.50);

    final double l2 = clampedL + 0.3963377774 * okA + 0.2158037573 * okB;
    final double m2 = clampedL - 0.1055613458 * okA - 0.0638541728 * okB;
    final double s2 = clampedL - 0.0894841775 * okA - 1.2914855480 * okB;

    final double l3 = l2 * l2 * l2;
    final double m3 = m2 * m2 * m2;
    final double s3 = s2 * s2 * s2;

    final double linR =
        4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3;
    final double linG =
        -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3;
    final double linB =
        -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3;

    return (
      _linearToSrgbUnclamped(linR),
      _linearToSrgbUnclamped(linG),
      _linearToSrgbUnclamped(linB),
    );
  }

  static double _srgbToLinear(double c) {
    return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  static double _linearToSrgbUnclamped(double c) {
    if (c <= 0.0) return 0.0;
    return c <= 0.0031308
        ? 12.92 * c
        : 1.055 * math.pow(c, 1.0 / 2.4).toDouble() - 0.055;
  }

  static double _cbrt(double x) {
    if (x == 0.0) return 0.0;
    return x < 0.0
        ? -math.pow(-x, 1.0 / 3.0).toDouble()
        : math.pow(x, 1.0 / 3.0).toDouble();
  }

  // --- Avatar Palette & Neutral Fallback ---
  /// Official 14-color Libadwaita avatar background palette.
  static const List<Color> avatarPalette = [
    blue2,
    green2,
    yellow4,
    orange2,
    red2,
    purple2,
    purple3,
    blue3,
    green3,
    yellow5,
    orange3,
    red3,
    brown2,
    dark1,
  ];

  /// Neutral base color for an `AdwAvatar` with no text or custom image.
  static const Color avatarFallbackBase = Color(0xFF8E8E93);

  /// Neutral top gradient stop for an `AdwAvatar` with no text or custom image.
  static const Color avatarFallbackTop = Color(0xFFD4D4D8);

  /// Neutral bottom gradient stop for an `AdwAvatar` with no text or custom image.
  static const Color avatarFallbackBottom = Color(0xFF5E5E64);

  // --- Theme-independent Fallbacks ---
  /// Fallback light modal dimming scrim when no `AdwTheme` is in scope.
  static const Color fallbackDimmingLight = Color(0x29000006);

  /// Fallback dark page background when no `AdwTheme` is in scope.
  static const Color fallbackDarkWindow = Color(0xFF242424);

  /// Fallback light page background when no `AdwTheme` is in scope.
  static const Color fallbackLightWindow = Color(0xFFFAFAFA);
}

/// The 9 official accent colors introduced in GNOME 47 and Libadwaita.
///
/// {@category Theming & Localization}
enum AdwAccentColor {
  blue(AdwColors.accentBlue, 'Blue'),
  teal(AdwColors.accentTeal, 'Teal'),
  green(AdwColors.accentGreen, 'Green'),
  yellow(AdwColors.accentYellow, 'Yellow'),
  orange(AdwColors.accentOrange, 'Orange'),
  red(AdwColors.accentRed, 'Red'),
  pink(AdwColors.accentPink, 'Pink'),
  purple(AdwColors.accentPurple, 'Purple'),
  slate(AdwColors.accentSlate, 'Slate');

  final Color color;
  final String label;

  const AdwAccentColor(this.color, this.label);
}

