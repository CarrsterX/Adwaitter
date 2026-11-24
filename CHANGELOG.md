## 1.0.0-alpha.8

* Full Web and WebAssembly (WASM) compatibility: isolated `dart:io` and `dart:ffi` behind conditional imports and replaced direct `Platform` checks with `kIsWeb` / `defaultTargetPlatform`.
* Updated `AdwWindow` and `AdwHeaderBar` to treat Web as a full-viewport surface (square corners, no CSD shadows, no window control buttons).
* Added minimal package example (`example/lib/main.dart`) and `flutter_web_plugins` support for Web plugin registration.

## 1.0.0-alpha.7

* Full Web and WebAssembly (WASM) compatibility: isolated `dart:io` and `dart:ffi` behind conditional imports (`adw_style_platform_*`, `adw_sub_window_platform_*`) and replaced direct `Platform` checks with `kIsWeb` / `defaultTargetPlatform`.
* Updated `AdwWindow` and `AdwHeaderBar` to treat Web as a full-viewport surface (square corners, no CSD shadows, no window control buttons).
* Added `flutter_web_plugins` dependency and updated `AdwaitterDartPlugin.registerWith([Object? registrar])` for Web plugin registration.

## 1.0.0-alpha.2

* Added 1:1 Libadwaita touch and desktop text selection (`AdwTextSelectionControls`, `AdwEditableText`, `AdwInputBounds`): teardrop `cursor-handle`s, horizontal 5-item OSD `popover.touch-selection` bar with non-interactive scroll indicator, vertical `GtkPopoverMenu` on mouse right-click, and crisp `2.0×` vector text magnifier.
* Added Android native bridges in `AdwaitterPlugin.kt` for `ACTION_PROCESS_TEXT` actions with auto-trimmed monochrome/app icons, `Share`, `MediaSession` media notification controls, and interactive system notifications.
* Added native Linux emoji font loading and `AdwSearchBar` / `AdwEntryRow` / `AdwEntry` selection polish.

## 1.0.0-alpha

* Initial pre-alpha release of **Adwaitter**, a pure Flutter GNOME Libadwaita 1.10+ UI widget library and design system (zero Material dependency).
* Complete adaptive Light & Dark themes (`AdwThemeData`, `AdwColorScheme`, `AdwTypography`, `AdwStyleManager`) with GNOME/Android Material You dynamic accent colors and variable-weight `AdwaitaSans` / `AdwaitaMono` fonts.
* Full GNOME Libadwaita widget suite: `AdwApplication`, `AdwWindow`, `AdwHeaderBar`, `AdwToolbarView`, `AdwNavigationView`, `AdwNavigationSplitView`, `AdwOverlaySplitView`, `AdwSidebar`, `AdwTabView`, `AdwViewSwitcher`, `AdwCarousel`, `AdwBottomSheet`, `AdwDialog`, `AdwAlertDialog`, `AdwAboutDialog`, `AdwPreferencesDialog`, `AdwShortcutsDialog`, `AdwPopover`, `AdwContextMenu`, `AdwToastOverlay`, `AdwBanner`, `AdwTooltip`, `AdwSearchBar`, `AdwClamp`, `AdwClampScrollable`, `AdwBreakpointBin`, `AdwWrapBox`, `AdwMultiLayoutView`, `AdwCard`, `AdwOsdSurface`, `AdwLinkedBox`, `AdwActionRow`, `AdwExpanderRow`, `AdwEntryRow`, `AdwComboRow`, `AdwSpinRow`, `AdwButtonRow`, `AdwButton`, `AdwSplitButton`, `AdwToggleGroup`, `AdwDropdown`, `AdwEntry`, `AdwSwitch`, `AdwCheckbox`, `AdwSlider`, `AdwProgressBar`, `AdwLevelBar`, `AdwSpinner`, `AdwAvatar`, `AdwStatusPage`.
* Zero-config Android plugin (`AdwaitterPlugin.kt`): edge-to-edge layout, predictive back gesture support, multi-window detection, Material You accent colors, haptic feedback, and `openUri` / file picker portal handlers.
* Added CLI starter generator (`dart run adwaitter:setup`).
