import 'package:flutter/widgets.dart';

import 'adw_colors.dart';
import 'adw_typography.dart';

/// Theme appearance mode for Libadwaitter.
///
/// Provides decoupled theme brightness management independent of Material's `ThemeMode`.
enum AdwThemeMode {
  /// Follows the host operating system dark/light preference.
  system,

  /// Enforces Libadwaita light stylesheet.
  light,

  /// Enforces Libadwaita dark stylesheet.
  dark,
}

/// Semantic color scheme defining GNOME Libadwaita tokens.
class AdwColorScheme {
  final bool isDark;
  final bool isHighContrast;
  final Color windowBackground;
  final Color windowForeground;
  final Color secondaryForeground;
  final Color viewBackground;
  final Color viewForeground;
  final Color cardBackground;
  final Color cardForeground;
  final Color headerBarBackground;
  final Color headerBarForeground;
  final Color dialogBackground;
  final Color dialogForeground;
  final Color popoverBackground;
  final Color popoverForeground;
  final Color borderColor;
  final Color dividerColor;
  final Color accentColor;
  final Color accentForeground;
  final Color destructiveColor;
  final Color destructiveForeground;
  final Color successColor;
  final Color warningColor;
  final Color hoverColor;
  final Color activeColor;
  final Color sidebarBackground;
  final Color sidebarBorder;

  /// Ergonomic alias for [windowForeground].
  Color get foreground => windowForeground;

  /// Ergonomic alias for [hoverColor].
  Color get hoverBackground => hoverColor;

  /// Background color for standard push buttons and segmented controls.
  Color get buttonBackground => isDark
      ? const Color(0x1FDDDDDD)
      : const Color(0x0F000000);

  /// Background color for selected items in a navigation sidebar (`.navigation-sidebar row:selected`).
  ///
  /// Evaluates to exact `#424246` in dark mode over [sidebarBackground] (`#2E2E32`).
  Color get sidebarSelectedBackground => isDark
      ? const Color(0x19FFFFFF)
      : const Color(0x14000000);

  /// Backdrop sidebar background color (`@define-color sidebar_backdrop_color`)
  /// used when the parent window is unfocused.
  Color get sidebarBackdropBackground => isDark
      ? const Color(0xFF28282C)
      : const Color(0xFFF3F3F5);

  /// Flat `AdwSplitButton` hovered-half background (`#404043` dark, `#DFDFE0` light high-contrast).
  Color get splitButtonFlatHoverColor => isDark
      ? const Color(0xFF404043)
      : (isHighContrast ? const Color(0xFFDFDFE0) : hoverColor);

  /// Flat `AdwSplitButton` non-hovered sibling half background (`#323235` dark, `#ECECED` light high-contrast).
  Color get splitButtonFlatSiblingColor => isDark
      ? const Color(0xFF323235)
      : (isHighContrast ? const Color(0xFFECECED) : const Color(0x05000000));

  /// Flat `AdwSplitButton` high-contrast border for the non-hovered sibling half (`#545456` dark).
  Color get splitButtonFlatSiblingBorderColor =>
      isDark ? const Color(0xFF545456) : borderColor.withValues(alpha: 0.65);

  /// High-contrast inner divider color for `AdwSplitButton` (`#D3D3D3` dark, `#4C4C50` light).
  Color get splitButtonDividerHighContrastColor =>
      isDark ? const Color(0xFFD3D3D3) : const Color(0xFF4C4C50);

  /// Track background color for non-flat `AdwToggleGroup`
  /// (`#38383B` dark, `#47474B` dark high-contrast, `#E6E6E7` light).
  Color get toggleGroupTrackColor => isDark
      ? (isHighContrast ? const Color(0xFF47474B) : const Color(0xFF38383B))
      : const Color(0xFFE6E6E7);

  /// High-contrast border color for the `AdwAboutDialog` version pill (`#5681BB`).
  Color get versionPillBorderColor => const Color(0xFF5681BB);

  /// Focused input ring color (`#74B4FF` in high-contrast mode).
  Color get focusBorderColor => isHighContrast
      ? const Color(0xFF74B4FF)
      : accentColor.withValues(alpha: 0.50);

  /// Focused ring color for `AdwSpinRow`
  /// (dark: `#4F77AC` / HC `#86C6FF`; light: `#73A1D1` / HC `#3680CB`).
  Color get spinRowFocusBorderColor => isDark
      ? (isHighContrast ? const Color(0xFF86C6FF) : const Color(0xFF4F77AC))
      : (isHighContrast ? const Color(0xFF3680CB) : const Color(0xFF73A1D1));

  /// High-contrast border color for destructive actions (`#CA6C69` in dark mode).
  Color get destructiveBorderColor =>
      isDark ? const Color(0xFFCA6C69) : destructiveColor;

  /// OFF-state track background color for `AdwSwitch`
  /// (`#515155` dark, `#707073` dark high-contrast, `#E0E0E1` light, `#C2C2C3` light high-contrast).
  Color get switchOffTrackColor => isDark
      ? (isHighContrast ? const Color(0xFF707073) : const Color(0xFF515155))
      : (isHighContrast ? const Color(0xFFC2C2C3) : const Color(0xFFE0E0E1));

  /// OFF-state track hover color for `AdwSwitch` (`#A9A9AB` in light high-contrast).
  Color get switchOffTrackHoverColor => isDark
      ? Color.lerp(switchOffTrackColor, const Color(0xFFFFFFFF), 0.08)!
      : (isHighContrast
          ? const Color(0xFFA9A9AB)
          : Color.lerp(switchOffTrackColor, const Color(0xFF000000), 0.08)!);

  /// OFF-state circle (`○`) color for `AdwSwitch` when `show-status-shapes` is enabled.
  Color get switchShapeOffColor => isHighContrast
      ? (isDark ? const Color(0xFFE8E8E9) : const Color(0xFF2D2D32))
      : (isDark ? const Color(0xB3FFFFFF) : const Color(0xFF2D2D32));

  /// Outer hairline border around floating CSD windows (`window.csd`).
  Color get windowOutline =>
      isDark ? const Color(0x80000000) : const Color(0x00000000);

  /// Subtle 1px inner edge highlight on floating CSD windows (`~8%` white in dark mode,
  /// or `borderColor` in high-contrast mode, painted cleanly on top of clipped content).
  Color get windowInnerBorder => isHighContrast
      ? borderColor
      : (isDark ? const Color(0x14FFFFFF) : const Color(0x00000000));

  /// Dimmed icon color used by `AdwStatusPage` and `AdwPreferencesPage` headers.
  Color get statusIconColor => isDark
      ? (isHighContrast ? const Color(0xFFE8E8E9) : const Color(0xFF9B9B9D))
      : (isHighContrast ? const Color(0xFF46464A) : const Color(0xFF8C8C90));

  /// Idle background for `AdwButtonRow` cards.
  Color get buttonRowBackground => isDark
      ? const Color(0xFF333337)
      : const Color(0xFFFFFFFF);

  /// Hover background for standard `AdwButtonRow` cards.
  Color get buttonRowHoverBackground => isDark
      ? Color.alphaBlend(hoverColor, buttonRowBackground)
      : const Color(0xFFF9F9F9);

  /// Foreground text/icon color for destructive `AdwButtonRow`.
  Color get destructiveRowForeground => isDark
      ? const Color(0xFFFF938C)
      : destructiveColor;

  /// Hover background for destructive `AdwButtonRow` cards.
  Color get destructiveRowHoverBackground => isDark
      ? const Color(0xFF3A3539)
      : const Color(0xFFFDF7F7);

  /// Standalone foreground color for `.success` labels and entries (`--success-color`).
  Color get standaloneSuccessColor =>
      isDark ? const Color(0xFF78EABE) : const Color(0xFF1B8553);

  /// Standalone foreground color for `.warning` labels and entries (`--warning-color`).
  Color get standaloneWarningColor =>
      isDark ? const Color(0xFFF8E45C) : const Color(0xFF9C6E03);

  /// Standalone foreground color for `.error` / `.destructive-action` (`--error-color`).
  Color get standaloneErrorColor =>
      isDark ? const Color(0xFFFF7B63) : const Color(0xFFC30000);

  /// Idle background for `.destructive-action` buttons (`AdwButton.destructive`).
  Color get destructiveButtonBackground => isDark
      ? standaloneErrorColor.withValues(alpha: 0.15)
      : const Color(0xFFF2D5D6);

  /// Hover background for `.destructive-action` buttons (`AdwButton.destructive`).
  Color get destructiveButtonHoverBackground => isDark
      ? standaloneErrorColor.withValues(alpha: 0.20)
      : const Color(0xFFEFC8C9);

  /// Pressed/active background for `.destructive-action` buttons (`AdwButton.destructive`).
  Color get destructiveButtonActiveBackground => isDark
      ? standaloneErrorColor.withValues(alpha: 0.35)
      : const Color(0xFFE6A9AC);

  /// On-screen display (`.osd`) foreground color (`rgba(255, 255, 255, 0.90)`).
  Color get osdForeground => const Color(0xE6FFFFFF);

  /// On-screen display (`.osd`) base surface color (`rgba(0, 0, 0, 0.70)` -> `#4B4B4C` over `#FAFAFB`).
  Color get osdBackground => const Color(0xB3000000);

  /// On-screen display (`.osd`) hover surface color.
  Color get osdHoverBackground => const Color(0xA6262626);

  /// On-screen display (`.osd`) active/pressed surface color.
  Color get osdActiveBackground => const Color(0xB33F3F3F);

  /// Modal dimming scrim opacity (`0.40` dark, `0.16` light -> `#D6D6D8` over white).
  double get dimmingAlpha => isDark ? 0.40 : 0.16;

  /// Modal dimming scrim color (`--dimming-color`).
  Color get dimmingColor => Color.fromRGBO(0, 0, 6, dimmingAlpha);

  /// Background color for `AdwBanner` (`#D4D4D6` in light mode, `#333337` in dark mode).
  Color get bannerBackground =>
      isDark ? const Color(0xFF333337) : const Color(0xFFD4D4D6);

  /// Backdrop (unfocused window) background color for `AdwBanner` (`#E7E7E9` in light mode).
  Color get bannerBackdropBackground =>
      isDark ? const Color(0xFF2B2B2F) : const Color(0xFFE7E7E9);

  /// Standard button idle background inside `AdwBanner` (`#C3C3C6` in light mode).
  Color get bannerButtonBackground =>
      isDark ? const Color(0x26FFFFFF) : const Color(0xFFC3C3C6);

  /// Standard button hover background inside `AdwBanner`.
  Color get bannerButtonHoverBackground =>
      isDark ? const Color(0x33FFFFFF) : const Color(0xFFB7B7BA);

  /// Standard button active/pressed background inside `AdwBanner`.
  Color get bannerButtonActiveBackground =>
      isDark ? const Color(0x4DFFFFFF) : const Color(0xFFA6A6AA);

  const AdwColorScheme({
    required this.isDark,
    this.isHighContrast = false,
    required this.windowBackground,
    required this.windowForeground,
    required this.secondaryForeground,
    required this.viewBackground,
    required this.viewForeground,
    required this.cardBackground,
    required this.cardForeground,
    required this.headerBarBackground,
    required this.headerBarForeground,
    required this.dialogBackground,
    required this.dialogForeground,
    required this.popoverBackground,
    required this.popoverForeground,
    required this.borderColor,
    required this.dividerColor,
    required this.accentColor,
    required this.accentForeground,
    required this.destructiveColor,
    required this.destructiveForeground,
    required this.successColor,
    required this.warningColor,
    required this.hoverColor,
    required this.activeColor,
    required this.sidebarBackground,
    required this.sidebarBorder,
  });

  /// Official Libadwaita Light Color Scheme.
  factory AdwColorScheme.light({
    AdwAccentColor accent = AdwAccentColor.blue,
    Color? accentColorOverride,
  }) {
    final effectiveAccent = accentColorOverride ?? accent.color;
    final accentFg = effectiveAccent.computeLuminance() > 0.55
        ? const Color(0xCC000006)
        : const Color(0xFFFFFFFF);
    return AdwColorScheme(
      isDark: false,
      windowBackground: const Color(0xFFFAFAFB),
      windowForeground: const Color(0xCC000006),
      secondaryForeground: const Color(0x8A000006),
      viewBackground: const Color(0xFFFFFFFF),
      viewForeground: const Color(0xCC000006),
      cardBackground: const Color(0xFFFFFFFF),
      cardForeground: const Color(0xCC000006),
      headerBarBackground: const Color(0xFFFFFFFF),
      headerBarForeground: const Color(0xCC000006),
      dialogBackground: const Color(0xFFFAFAFB),
      dialogForeground: const Color(0xCC000006),
      popoverBackground: const Color(0xFFFFFFFF),
      popoverForeground: const Color(0xCC000006),
      borderColor: const Color(0x26000000), // ~15% opacity
      dividerColor: const Color(0x1A000000), // ~10% opacity
      accentColor: effectiveAccent,
      accentForeground: accentFg,
      destructiveColor: AdwColors.red3,
      destructiveForeground: const Color(0xFFFFFFFF),
      successColor: AdwColors.green4,
      warningColor: AdwColors.yellow5,
      hoverColor: const Color(0x06000000), // ~2.4% (#F9F9F9 over #FFFFFF)
      activeColor: const Color(0x1F000000), // ~12%
      sidebarBackground: const Color(0xFFEBEBED),
      // Exact upstream Libadwaita light sidebar border (#DADADC)
      sidebarBorder: const Color(0xFFDADADC),
    );
  }

  /// Official Libadwaita Dark Color Scheme.
  factory AdwColorScheme.dark({
    AdwAccentColor accent = AdwAccentColor.blue,
    Color? accentColorOverride,
  }) {
    final effectiveAccent = accentColorOverride ?? accent.color;
    final accentFg = effectiveAccent.computeLuminance() > 0.55
        ? const Color(0xCC000006)
        : const Color(0xFFFFFFFF);
    return AdwColorScheme(
      isDark: true,
      windowBackground: const Color(0xFF222226),
      windowForeground: const Color(0xFFFFFFFF),
      secondaryForeground: const Color(0xB3FFFFFF),
      viewBackground: const Color(0xFF1D1D20),
      viewForeground: const Color(0xFFFFFFFF),
      cardBackground: const Color(0xFF333337),
      cardForeground: const Color(0xFFFFFFFF),
      headerBarBackground: const Color(0xFF2E2E32),
      headerBarForeground: const Color(0xFFFFFFFF),
      dialogBackground: const Color(0xFF36363A),
      dialogForeground: const Color(0xFFFFFFFF),
      popoverBackground: const Color(0xFF36363A),
      popoverForeground: const Color(0xFFFFFFFF),
      borderColor: const Color(0x26FFFFFF), // ~15% opacity
      dividerColor: const Color(0x1AFFFFFF), // ~10% opacity
      accentColor: effectiveAccent,
      accentForeground: accentFg,
      destructiveColor: AdwColors.red4,
      destructiveForeground: const Color(0xFFFFFFFF),
      successColor: AdwColors.green5,
      warningColor: const Color(0xFFCD9309),
      hoverColor: const Color(0x08FFFFFF), // ~3% (#39393D over #333337)
      activeColor: const Color(0x1FFFFFFF), // ~12%
      sidebarBackground: const Color(0xFF2E2E32),
      // RGB(0 0 6 / 36%) over #2E2E32 -> #1D1D22
      sidebarBorder: const Color(0x5C000006),
    );
  }

  /// Returns a high-contrast variant matching Libadwaita `_high_contrast.scss`
  /// (50% border opacity, stronger dividers, and higher secondary text contrast).
  ///
  /// On Android 14+, [level] supports two elevated tiers:
  /// - `0.5` (medium): softer visible borders & dividers.
  /// - `1.0` (high): full Libadwaita High Contrast borders & dividers.
  ///
  /// When [highTextContrast] is `true` (Android-only), foreground and secondary
  /// text colors are boosted to maximum legibility.
  AdwColorScheme withHighContrast({
    double level = 1.0,
    bool highTextContrast = false,
  }) {
    final bool hasBorderContrast = level >= 0.25;
    final bool isFullContrast = level >= 0.75;

    final Color effectiveBorder = !hasBorderContrast
        ? borderColor
        : isFullContrast
            ? (isDark ? const Color(0x80FFFFFF) : const Color(0xFF89898C))
            : (isDark ? const Color(0x4DFFFFFF) : const Color(0xFFB0B0B4));

    final Color effectiveDivider = !hasBorderContrast
        ? dividerColor
        : isFullContrast
            ? (isDark ? const Color(0x66FFFFFF) : const Color(0xFF89898C))
            : (isDark ? const Color(0x3DFFFFFF) : const Color(0xFFB8B8BC));

    final Color effectivePrimaryFg = highTextContrast
        ? (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000))
        : windowForeground;

    final Color effectiveSecondaryFg = highTextContrast
        ? (isDark ? const Color(0xF2FFFFFF) : const Color(0xE6000000))
        : hasBorderContrast
            ? (isDark ? const Color(0xE6FFFFFF) : const Color(0xD9000000))
            : secondaryForeground;

    return AdwColorScheme(
      isDark: isDark,
      isHighContrast: hasBorderContrast,
      windowBackground: windowBackground,
      windowForeground: effectivePrimaryFg,
      secondaryForeground: effectiveSecondaryFg,
      viewBackground: viewBackground,
      viewForeground: highTextContrast ? effectivePrimaryFg : viewForeground,
      cardBackground: cardBackground,
      cardForeground: highTextContrast ? effectivePrimaryFg : cardForeground,
      headerBarBackground: headerBarBackground,
      headerBarForeground:
          highTextContrast ? effectivePrimaryFg : headerBarForeground,
      dialogBackground: dialogBackground,
      dialogForeground: highTextContrast ? effectivePrimaryFg : dialogForeground,
      popoverBackground: popoverBackground,
      popoverForeground:
          highTextContrast ? effectivePrimaryFg : popoverForeground,
      borderColor: effectiveBorder,
      dividerColor: effectiveDivider,
      accentColor: accentColor,
      accentForeground: accentForeground,
      destructiveColor: destructiveColor,
      destructiveForeground: destructiveForeground,
      successColor: successColor,
      warningColor: warningColor,
      hoverColor: hasBorderContrast
          ? (isDark ? const Color(0x08FFFFFF) : const Color(0x06000000))
          : hoverColor,
      activeColor: hasBorderContrast
          ? (isDark ? const Color(0x33FFFFFF) : const Color(0x26000000))
          : activeColor,
      sidebarBackground: sidebarBackground,
      sidebarBorder: hasBorderContrast ? effectiveBorder : sidebarBorder,
    );
  }
}

/// Libadwaita theme data container (colors, typography, global layout settings).
class AdwThemeData {
  final AdwColorScheme colors;
  final AdwTypography typography;

  const AdwThemeData({
    required this.colors,
    required this.typography,
  });

  AdwThemeData withHighContrast({
    double level = 1.0,
    bool highTextContrast = false,
  }) {
    final hcColors = colors.withHighContrast(
      level: level,
      highTextContrast: highTextContrast,
    );
    return AdwThemeData(
      colors: hcColors,
      typography: AdwTypography.fromColors(
        foreground: hcColors.windowForeground,
        secondaryForeground: hcColors.secondaryForeground,
      ),
    );
  }

  factory AdwThemeData.light({
    AdwAccentColor accent = AdwAccentColor.blue,
    Color? accentColorOverride,
  }) {
    final colors = AdwColorScheme.light(
      accent: accent,
      accentColorOverride: accentColorOverride,
    );
    final typography = AdwTypography.fromColors(
      foreground: colors.windowForeground,
      secondaryForeground: colors.secondaryForeground,
    );
    return AdwThemeData(colors: colors, typography: typography);
  }

  factory AdwThemeData.dark({
    AdwAccentColor accent = AdwAccentColor.blue,
    Color? accentColorOverride,
  }) {
    final colors = AdwColorScheme.dark(
      accent: accent,
      accentColorOverride: accentColorOverride,
    );
    final typography = AdwTypography.fromColors(
      foreground: colors.windowForeground,
      secondaryForeground: colors.secondaryForeground,
    );
    return AdwThemeData(colors: colors, typography: typography);
  }

  /// Returns a copy of this theme data with a mutated [accent] color.
  AdwThemeData withAccent(AdwAccentColor accent) {
    if (colors.isDark) {
      return AdwThemeData.dark(accent: accent);
    } else {
      return AdwThemeData.light(accent: accent);
    }
  }

  /// Returns a copy of this theme data with a custom [accentColor].
  AdwThemeData withAccentColor(Color accentColor) {
    if (colors.isDark) {
      return AdwThemeData.dark(accentColorOverride: accentColor);
    } else {
      return AdwThemeData.light(accentColorOverride: accentColor);
    }
  }
}

/// Inherited widget for propagating and accessing [AdwThemeData] in the widget tree.
class AdwTheme extends InheritedTheme {
  final AdwThemeData data;

  const AdwTheme({
    super.key,
    required this.data,
    required super.child,
  });

  /// Retrieves the current [AdwThemeData] from the closest ancestor, asserting if none exists.
  static AdwThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<AdwTheme>();
    assert(
      theme != null,
      'No AdwTheme found in context. Ensure your app is wrapped with AdwApplication or AdwTheme.',
    );
    return theme!.data;
  }

  /// Safely retrieves the current [AdwThemeData] or null if absent.
  static AdwThemeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdwTheme>()?.data;
  }

  @override
  bool updateShouldNotify(covariant AdwTheme oldWidget) {
    return data != oldWidget.data;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return AdwTheme(data: data, child: child);
  }
}

