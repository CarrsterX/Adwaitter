import 'package:flutter/widgets.dart';

import 'adw_colors.dart';
import 'adw_typography.dart';

/// Theme appearance mode for Libadwaitter.
///
/// Provides decoupled theme brightness management independent of Material's `ThemeMode`.
///
/// {@category Theming & Localization}
enum AdwThemeMode {
  /// Follows the host operating system dark/light preference.
  system,

  /// Enforces Libadwaita light stylesheet.
  light,

  /// Enforces Libadwaita dark stylesheet.
  dark,
}

/// Semantic color scheme defining GNOME Libadwaita 1.10+ design tokens.
///
/// {@category Theming & Localization}
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

  /// Background color for standard push buttons (`$button_color`: `10%` of `currentColor`).
  Color get buttonBackground =>
      AdwColors.colorMixTransparent(windowForeground, 0.10);

  /// Hover background color for standard push buttons (`$button_hover_color`: `15%`).
  Color get buttonHoverBackground =>
      AdwColors.colorMixTransparent(windowForeground, 0.15);

  /// Active/checked background color for standard push buttons (`$button_active_color`: `30%`).
  Color get buttonActiveBackground =>
      AdwColors.colorMixTransparent(windowForeground, 0.30);

  /// Subtle row hover background inside lists and cards (`$view_hover_color`: `4%`).
  Color get viewHoverColor =>
      AdwColors.colorMixTransparent(windowForeground, 0.04);

  /// Row active/pressed background inside lists and cards (`$view_active_color`: `8%`).
  Color get viewActiveColor =>
      AdwColors.colorMixTransparent(windowForeground, 0.08);

  /// Background color for selected items in a navigation sidebar (`$selected_color`: `10%`).
  Color get sidebarSelectedBackground =>
      AdwColors.colorMixTransparent(windowForeground, 0.10);

  /// Backdrop sidebar background color (`@sidebar_backdrop_color`)
  /// used when the parent window is unfocused.
  Color get sidebarBackdropBackground =>
      isDark ? const Color(0xFF28282C) : const Color(0xFFF2F2F4);

  /// Tab overview & secondary sidebar background (`--overview-bg-color`).
  Color get overviewBackground =>
      isDark ? const Color(0xFF28282C) : const Color(0xFFF3F3F5);

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

  /// Track background color for non-flat `AdwToggleGroup` (`$button_color`: `10%`).
  Color get toggleGroupTrackColor =>
      AdwColors.colorMixTransparent(windowForeground, 0.10);

  /// High-contrast border color for the `AdwAboutDialog` version pill (`#5681BB`).
  Color get versionPillBorderColor => const Color(0xFF5681BB);

  /// Background color for the `AdwAboutDialog` version pill (`10%` of `--accent-color` in dark mode).
  ///
  /// Matches GTK4's exact `#2C3441` 8-bit quantized output for the default GNOME
  /// blue accent on `#222226`, and computes extended-sRGB OKLab for all other accents.
  Color get versionPillBackground {
    if (!isDark) {
      return AdwColors.colorMixTransparent(accentColor, 0.15);
    }
    if (accentColor == AdwColors.accentBlue &&
        windowBackground == const Color(0xFF222226)) {
      return const Color(0xFF2C3441);
    }
    return AdwColors.standaloneOklabOver(
      accentColor,
      isDark: true,
      opacity: 0.10,
      surface: windowBackground,
    );
  }

  /// Standalone foreground accent color (`--accent-color`, OKLab transformed).
  Color get standaloneAccentColor =>
      AdwColors.standaloneOklab(accentColor, isDark: isDark);

  /// Focused input ring color (`$focus_border_color`: `50%` / `80%` HC of `--accent-color`).
  Color get focusBorderColor => isDark
      ? AdwColors.standaloneOklabOver(
          accentColor,
          isDark: true,
          opacity: isHighContrast ? 0.80 : 0.50,
          surface: headerBarBackground,
        )
      : AdwColors.colorMixTransparent(
          standaloneAccentColor,
          isHighContrast ? 0.80 : 0.50,
        );

  /// Focused ring color for `AdwSpinRow` (derived from [focusBorderColor]).
  Color get spinRowFocusBorderColor => focusBorderColor;

  /// High-contrast border color for destructive actions.
  Color get destructiveBorderColor =>
      isDark ? standaloneDestructiveColor : destructiveColor;

  /// OFF-state track background color for `AdwSwitch` (`$trough_color`: `15%` / `30%` HC).
  Color get switchOffTrackColor => AdwColors.colorMixTransparent(
        windowForeground,
        isHighContrast ? 0.30 : 0.15,
      );

  /// OFF-state track hover color for `AdwSwitch` (`$trough_hover_color`: `20%` / `40%` HC).
  Color get switchOffTrackHoverColor => AdwColors.colorMixTransparent(
        windowForeground,
        isHighContrast ? 0.40 : 0.20,
      );

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
  Color get buttonRowBackground => cardBackground;

  /// Hover background for standard `AdwButtonRow` cards.
  Color get buttonRowHoverBackground =>
      Color.alphaBlend(viewHoverColor, cardBackground);

  /// Standalone foreground color for destructive actions (`--destructive-color`, OKLab).
  Color get standaloneDestructiveColor =>
      AdwColors.standaloneOklab(destructiveColor, isDark: isDark);

  /// Foreground text/icon color for destructive `AdwButtonRow`.
  Color get destructiveRowForeground => standaloneDestructiveColor;

  /// Hover background for destructive `AdwButtonRow` cards.
  Color get destructiveRowHoverBackground => Color.alphaBlend(
        AdwColors.colorMixTransparent(standaloneDestructiveColor, 0.06),
        cardBackground,
      );

  /// Standalone foreground color for `.success` labels and entries (`--success-color`, OKLab).
  Color get standaloneSuccessColor =>
      AdwColors.standaloneOklab(successColor, isDark: isDark);

  /// Standalone foreground color for `.warning` labels and entries (`--warning-color`, OKLab).
  Color get standaloneWarningColor =>
      AdwColors.standaloneOklab(warningColor, isDark: isDark);

  /// Standalone foreground color for `.error` / `.destructive-action` (`--error-color`, OKLab).
  Color get standaloneErrorColor => standaloneDestructiveColor;

  /// Idle background for `.destructive-action` buttons (`$destructive_button_color`: `15%`).
  Color get destructiveButtonBackground =>
      AdwColors.colorMixTransparent(standaloneDestructiveColor, 0.15);

  /// Hover background for `.destructive-action` buttons (`$destructive_button_hover_color`: `20%`).
  Color get destructiveButtonHoverBackground =>
      AdwColors.colorMixTransparent(standaloneDestructiveColor, 0.20);

  /// Pressed/active background for `.destructive-action` buttons (`$destructive_button_active_color`: `35%`).
  Color get destructiveButtonActiveBackground =>
      AdwColors.colorMixTransparent(standaloneDestructiveColor, 0.35);

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

  /// Chevron icon color for collapsed `AdwExpanderRow`.
  Color get expanderChevronColor =>
      isDark ? const Color(0xFFA3A3A5) : const Color(0xFF8F8F92);

  /// Chevron icon color for expanded `AdwExpanderRow` (`--accent-color`, OKLab).
  Color get expanderChevronExpandedColor => standaloneAccentColor;

  /// Background surface for nested rows revealed inside an expanded `AdwExpanderRow`.
  Color get expanderRowSubBackground =>
      isDark ? const Color(0xFF2A2A2E) : const Color(0xFFF6F6F6);

  /// Focus ring color for OSD controls (`AdwButton.osd`, `AdwButton.osdFlat`, OSD `AdwSlider`).
  Color get osdFocusBorderColor => const Color(0xFF666667);

  /// Hover background for `AdwButton.osdFlat`.
  Color get osdFlatHoverBackground => const Color(0x12FFFFFF);

  /// Active/pressed background for `AdwButton.osdFlat`.
  Color get osdFlatActiveBackground => const Color(0x29FFFFFF);

  /// Subtle border color for OSD popovers (`AdwPopover`).
  Color get osdBorderColor => const Color(0x1AFFFFFF);

  /// Search field background inside `AdwComboRow` popovers (`10%` of `popoverForeground`).
  Color get comboSearchBackground =>
      AdwColors.colorMixTransparent(popoverForeground, 0.10);

  /// Search input background inside `AdwPreferencesDialog` and `AdwShortcutsDialog`.
  Color get dialogSearchBackground => cardBackground;

  /// Idle trough color for OSD `AdwSlider`.
  Color get osdSliderTroughColor => const Color(0x26FFFFFF);

  /// Hovered/active trough color for OSD `AdwSlider`.
  Color get osdSliderTroughLitColor => const Color(0x33FFFFFF);

  /// Idle active-track fill color for OSD `AdwSlider`.
  Color get osdSliderHighlightColor => const Color(0xBFFFFFFF);

  /// Hovered/active fill color for OSD `AdwSlider`.
  Color get osdSliderHighlightLitColor => const Color(0xD9FFFFFF);

  /// Idle thumb color for OSD `AdwSlider`.
  Color get osdSliderThumbColor => const Color(0xFFD2D2D3);

  /// Standard thumb color for `AdwSlider`.
  Color get sliderThumbColor => AdwColors.light1;

  /// Base background color for non-flat `AdwSplitButton` (`$button_color`: `10%`).
  Color get splitButtonBackground =>
      AdwColors.colorMixTransparent(windowForeground, 0.10);

  /// Inner divider color for flat `AdwSplitButton`.
  Color get splitButtonFlatDividerColor =>
      isDark ? const Color(0xFF646467) : const Color(0xFFBEBEC0);

  /// Inner divider color for standard (non-flat) `AdwSplitButton`.
  Color get splitButtonDividerColor =>
      isDark ? const Color(0x28FFFFFF) : const Color(0x22000000);

  /// Idle OFF-state thumb color for `AdwSwitch` (`$slider_color`: `80%` white + `20%` `viewBackground`).
  Color get switchThumbIdleDarkColor =>
      AdwColors.colorMix(AdwColors.light1, 0.80, viewBackground);

  /// Selected segment background for standard (non-flat) `AdwToggleGroup` (`--active-toggle-bg-color`).
  Color get toggleGroupSelectedBackground =>
      isDark ? const Color(0x33FFFFFF) : AdwColors.light1;

  /// Selected segment background for flat `AdwToggleGroup` (`$selected_color`: `10%`).
  Color get toggleGroupFlatSelectedBackground =>
      AdwColors.colorMixTransparent(windowForeground, 0.10);

  /// Subtle drop shadow color for the selected segment in `AdwToggleGroup`.
  Color get toggleGroupSelectedShadowColor => const Color(0x1F000000);

  /// Hover/focus background for unselected `AdwSidebarItem` (`$hover_color`: `7%`).
  Color get sidebarHoverBackground =>
      AdwColors.colorMixTransparent(windowForeground, 0.07);

  /// Pressed background for unselected `AdwSidebarItem` (`$active_color`: `16%`).
  Color get sidebarActiveBackground =>
      AdwColors.colorMixTransparent(windowForeground, 0.16);

  /// Hover/focus background for selected `AdwSidebarItem` (`$selected_hover_color`: `13%`).
  Color get sidebarSelectedHoverBackground =>
      AdwColors.colorMixTransparent(windowForeground, 0.13);

  /// Pressed background for selected `AdwSidebarItem` (`$selected_active_color`: `19%`).
  Color get sidebarSelectedActiveBackground =>
      AdwColors.colorMixTransparent(windowForeground, 0.19);

  /// Backdrop dimming overlay tinted onto unfocused `AdwWindow` surfaces.
  Color get windowBackdropOverlayColor =>
      isDark ? const Color(0x14000000) : const Color(0x0AFFFFFF);

  /// Undershoot/border shade color for `AdwHeaderBar`.
  Color get headerBarShadeColor =>
      isDark ? const Color(0x2E000006) : const Color(0x0F000006);

  /// Scroll undershoot gradient start color for `AdwToolbarView` (`75%` of `--shade-color`).
  Color get toolbarShadeColor =>
      isDark ? const Color(0x45000006) : const Color(0x17000006);

  /// Transparent endpoint matching `--shade-color` RGB (`0x00000006`) for clean gradients.
  Color get shadeTransparent => const Color(0x00000006);

  /// Idle background for `AdwCarousel` circular navigation buttons.
  Color get carouselButtonBackground => const Color(0x80000000);

  /// Pressed background for `AdwCarousel` circular navigation buttons.
  Color get carouselButtonActiveBackground => const Color(0xCC000000);

  /// Bottom separator shadow color for `AdwTabBar`.
  Color get tabBarShadowColor =>
      isDark ? const Color(0x4D000000) : const Color(0x1F000006);

  /// Translucent backdrop for close/unpin buttons inside `AdwTabOverview` thumbnails.
  Color get tabOverviewCloseBackground => const Color(0x88242428);

  /// Outer hairline border color for `AdwDialog` in dark/high-contrast modes.
  Color get dialogBorderColor =>
      isHighContrast ? borderColor : const Color(0xFF323235);

  /// Subtle top-edge highlight border for `AdwAlertDialog` in dark mode.
  Color get alertDialogBorderColor => const Color(0x14FFFFFF);

  /// Top shade hairline color for `AdwBottomSheet`.
  Color get bottomSheetTopShadeColor =>
      isDark ? const Color(0xFF18181C) : const Color(0x14000000);

  /// Top border color for `AdwBottomSheet`.
  Color get bottomSheetTopBorderColor =>
      isDark ? const Color(0xFF323235) : windowOutline;

  /// Top elevation gradient start color for an open `AdwBottomSheet`.
  Color get bottomSheetOpenGradientColor =>
      isDark ? const Color(0x30000000) : const Color(0x14000006);

  /// Top elevation gradient start color for a collapsed `AdwBottomSheet` bar.
  Color get bottomSheetClosedGradientColor =>
      isDark ? const Color(0x22000000) : const Color(0x0E000006);

  /// Hover/highlight fill color for items inside `AdwPopover` (`10%` of `popoverForeground`).
  Color get popoverItemHoverColor =>
      AdwColors.colorMixTransparent(popoverForeground, 0.10);

  /// Ambient shadow color for `AdwPopover` surfaces and arrows.
  Color get popoverShadowAmbientColor => const Color(0x0D000000);

  /// Key shadow color for `AdwPopover` surfaces and arrows.
  Color get popoverShadowKeyColor => const Color(0x17000000);

  /// Bottom 3D bevel shade color for keycap badges in `AdwShortcutsDialog`.
  Color get shortcutKeycapShadeColor =>
      isDark ? const Color(0x52000000) : const Color(0x1F000000);

  /// Pill background color for `AdwToast`.
  Color get toastBackground =>
      isDark ? const Color(0xFF505053) : const Color(0xFF2E2E32);

  /// Foreground text and icon color for `AdwToast`.
  Color get toastForeground => AdwColors.light1;

  /// Hover/focus background for the close button inside `AdwToast`.
  Color get toastCloseHoverBackground => const Color(0x24FFFFFF);

  /// Surface background color for `AdwTooltip`.
  Color get tooltipBackground => const Color(0xE81C1C1E);

  /// Foreground text color for `AdwTooltip`.
  Color get tooltipForeground => AdwColors.light1;

  /// Hairline border color for `AdwTooltip`.
  Color get tooltipBorderColor => const Color(0x24FFFFFF);

  // --- Elevation & Shadows ---

  /// Elevation shadow stack for `AdwCard`.
  List<BoxShadow> get cardShadows => const [
        BoxShadow(
          color: Color(0x08000006),
          blurRadius: 0.0,
          spreadRadius: 1.0,
        ),
        BoxShadow(
          color: Color(0x12000006),
          blurRadius: 3.0,
          spreadRadius: 1.0,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x08000006),
          blurRadius: 6.0,
          spreadRadius: 2.0,
          offset: Offset(0, 2),
        ),
      ];

  /// Elevation shadow stack for `AdwPreferencesGroup` boxed lists.
  List<BoxShadow> get preferencesGroupShadows => isDark
      ? const [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 3,
            spreadRadius: 1,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            spreadRadius: 2,
            offset: Offset(0, 2),
          ),
        ];

  /// Elevation shadow stack for `AdwSlider` thumbs.
  List<BoxShadow> get sliderThumbShadows => const [
        BoxShadow(
          color: Color(0x1A000006),
          blurRadius: 0.0,
          spreadRadius: 1.0,
        ),
        BoxShadow(
          color: Color(0x33000006),
          blurRadius: 4.0,
          offset: Offset(0, 2),
        ),
      ];

  /// Drop shadow for the `AdwSwitch` thumb.
  List<BoxShadow> get switchThumbShadows => const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ];

  /// Dark-mode elevation shadow stack for secondary floating windows (`AdwApplication`).
  static const List<BoxShadow> subWindowDarkShadows = [
    BoxShadow(
      color: Color(0x52000000),
      blurRadius: 24.0,
      spreadRadius: 0.0,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x30000000),
      blurRadius: 8.0,
      spreadRadius: 0.0,
      offset: Offset(0, 2),
    ),
  ];

  /// Light-mode elevation shadow stack for secondary floating windows (`AdwApplication`).
  static const List<BoxShadow> subWindowLightShadows = [
    BoxShadow(
      color: Color(0x2E000006),
      blurRadius: 24.0,
      spreadRadius: 0.0,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x1A000006),
      blurRadius: 6.0,
      spreadRadius: 0.0,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x14000006),
      blurRadius: 1.0,
      spreadRadius: 0.5,
      offset: Offset.zero,
    ),
  ];

  /// Elevation shadow stack for secondary floating windows (`AdwApplication` sub-window host).
  List<BoxShadow> get subWindowShadows =>
      isDark ? subWindowDarkShadows : subWindowLightShadows;

  /// Elevation shadow stack for active floating `AdwWindow`.
  List<BoxShadow> get windowActiveShadows => const [
        BoxShadow(
          color: Color(0x38000000),
          blurRadius: 18,
          spreadRadius: 0,
          offset: Offset(0, 6),
        ),
        BoxShadow(
          color: Color(0x18000000),
          blurRadius: 4,
          spreadRadius: 0,
          offset: Offset(0, 1),
        ),
      ];

  /// Elevation shadow stack for unfocused (backdrop) floating `AdwWindow`.
  List<BoxShadow> get windowBackdropShadows => const [
        BoxShadow(
          color: Color(0x20000000),
          blurRadius: 12,
          spreadRadius: 0,
          offset: Offset(0, 3),
        ),
      ];

  /// Drop shadow for `AdwCarousel` navigation buttons.
  List<BoxShadow> get carouselButtonShadows => const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ];

  /// Drop shadow for the floating new-tab pill button in `AdwTabOverview`.
  List<BoxShadow> get tabOverviewFabShadows => const [
        BoxShadow(
          color: Color(0x38000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];

  /// Elevation shadow stack for `AdwAlertDialog`.
  List<BoxShadow> get alertDialogShadows => const [
        BoxShadow(
          color: Color(0x4D000000),
          blurRadius: 24,
          spreadRadius: 2,
          offset: Offset(0, 8),
        ),
      ];

  /// Elevation shadow stack for an active floating `AdwDialog`.
  List<BoxShadow> get dialogActiveShadows => const [
        BoxShadow(
          color: Color(0x55000000),
          blurRadius: 28.0,
          spreadRadius: 2.0,
          offset: Offset(0, 10),
        ),
      ];

  /// Elevation shadow stack for a backdrop (unfocused) `AdwDialog`.
  List<BoxShadow> get dialogBackdropShadows => const [
        BoxShadow(
          color: Color(0x28000000),
          blurRadius: 12.0,
          spreadRadius: 0.0,
          offset: Offset(0, 4),
        ),
      ];

  /// Elevation shadow stack for an open `AdwBottomSheet`.
  List<BoxShadow> get bottomSheetOpenShadows => [
        BoxShadow(
          color: isDark ? const Color(0x33000000) : const Color(0x14000006),
          blurRadius: 24.0,
          spreadRadius: -4.0,
          offset: const Offset(0, -6),
        ),
        BoxShadow(
          color: isDark ? const Color(0x26000000) : const Color(0x0D000006),
          blurRadius: 8.0,
          spreadRadius: -2.0,
          offset: const Offset(0, -2),
        ),
      ];

  /// Elevation shadow stack for a collapsed `AdwBottomSheet` bar.
  List<BoxShadow> get bottomSheetBarShadows => [
        BoxShadow(
          color: isDark ? const Color(0x26000000) : const Color(0x12000006),
          blurRadius: 16.0,
          spreadRadius: -4.0,
          offset: const Offset(0, -4),
        ),
        BoxShadow(
          color: isDark ? const Color(0x1A000000) : const Color(0x0A000006),
          blurRadius: 6.0,
          spreadRadius: -2.0,
          offset: const Offset(0, -1),
        ),
      ];

  /// Elevation shadow stack for `AdwPopover` containers.
  List<BoxShadow> get popoverShadows => const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 0,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: Color(0x17000000),
          blurRadius: 5,
          spreadRadius: 1,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 14,
          spreadRadius: 3,
          offset: Offset(0, 2),
        ),
      ];

  /// Drop shadow for `AdwToast` pills.
  List<BoxShadow> get toastShadows => const [
        BoxShadow(
          color: Color(0x38000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ];

  /// Drop shadow for `AdwTooltip` bubbles.
  List<BoxShadow> get tooltipShadows => const [
        BoxShadow(
          color: Color(0x4D000000),
          blurRadius: 10.0,
          offset: Offset(0, 3),
        ),
      ];

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
      borderColor: AdwColors.colorMixTransparent(
          const Color(0xCC000006), 0.15), // $border_color (15% of 80% = 12%)
      dividerColor: AdwColors.colorMixTransparent(
          const Color(0xCC000006), 0.10), // 10% of 80% = 8%
      accentColor: effectiveAccent,
      accentForeground: accentFg,
      destructiveColor: AdwColors.red3,
      destructiveForeground: const Color(0xFFFFFFFF),
      successColor: AdwColors.green4,
      warningColor: AdwColors.yellow5,
      hoverColor: AdwColors.colorMixTransparent(
          const Color(0xCC000006), 0.07), // $hover_color
      activeColor: AdwColors.colorMixTransparent(
          const Color(0xCC000006), 0.16), // $active_color
      sidebarBackground: const Color(0xFFEBEBED),
      // Official upstream Libadwaita light sidebar border: RGB(0 0 6 / 7%)
      sidebarBorder: const Color(0x12000006),
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
      cardBackground: const Color(0x14FFFFFF), // RGB(255 255 255 / 8%)
      cardForeground: const Color(0xFFFFFFFF),
      headerBarBackground: const Color(0xFF2E2E32),
      headerBarForeground: const Color(0xFFFFFFFF),
      dialogBackground: const Color(0xFF36363A),
      dialogForeground: const Color(0xFFFFFFFF),
      popoverBackground: const Color(0xFF36363A),
      popoverForeground: const Color(0xFFFFFFFF),
      borderColor: const Color(0x26FFFFFF), // $border_color (15%)
      dividerColor: const Color(0x1AFFFFFF), // ~10% opacity
      accentColor: effectiveAccent,
      accentForeground: accentFg,
      destructiveColor: AdwColors.red4,
      destructiveForeground: const Color(0xFFFFFFFF),
      successColor: AdwColors.green5,
      warningColor: const Color(0xFFCD9309),
      hoverColor: const Color(0x12FFFFFF), // $hover_color (7%)
      activeColor: const Color(0x29FFFFFF), // $active_color (16%)
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

/// Libadwaita theme data container combining [colors] and [typography].
///
/// {@category Theming & Localization}
class AdwThemeData {
  /// Active semantic color scheme for this theme.
  final AdwColorScheme colors;

  /// Active Adwaita Sans/Mono typographic scale for this theme.
  final AdwTypography typography;

  /// Creates an [AdwThemeData] from explicit [colors] and [typography].
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
///
/// ```dart
/// final theme = AdwTheme.of(context);
/// ```
///
/// {@category Theming & Localization}
class AdwTheme extends InheritedTheme {
  /// Theme configuration provided to descendant widgets.
  final AdwThemeData data;

  /// Creates an [AdwTheme] provider wrapping [child].
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

