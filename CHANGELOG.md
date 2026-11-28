## 1.0.0-alpha.12

* **Mobile Web & Adaptive Dialogs**: Kept `AdwDialog` in centered floating mode on wide mobile landscape viewports (`width >= 540`) instead of covering the sidebar as a bottom sheet.
* **Web Swipe-Back Safe Zone**: Disabled system predictive-back listeners on Web and added a `72px` edge safe-zone on both screen edges in `AdwNavigationView` to avoid collisions with mobile browser Back/Forward gestures, plus duplicate-pop protection.
* **Carousel Long Swipes**: Fixed `AdwCarousel` `allowLongSwipes` toggle so disabling it strictly clamps touch/mouse swipes to ±1 page.
* Documented mobile Web edge-gesture browser limitations in `README.md` and `doc/navigation.md`.

## 1.0.0-alpha.11

* **Full Paginated `dartdoc` Documentation**: Added `dartdoc_options.yaml` with 8 topic categories (`Layout`, `Navigation`, `Containers`, `Controls`, `Overlays`, `Display`, `Theming & Localization`, `Core`), 8 topic guides under `doc/`, and 100% public API documentation across all 74 exported files (0 warnings, 0 errors on `dart doc --validate-links`).
* **Libadwaita 1.6+ OKLab Color Engine & Centralization**: Implemented pure-Dart `AdwColors.colorMix`, `AdwColors.colorMixTransparent`, `AdwColors.standaloneOklab`, and `AdwColors.standaloneOklabOver` matching GTK4's extended-sRGB compositor; fixed stale accent base colors (`accentYellow`, `accentOrange`, `accentRed`, `accentSlate`) and centralized all widget colors and shadow stacks into `AdwColorScheme` / `AdwColors` (0 hardcoded colors in widgets).
* **Focus Ring & Cleanup**: Suppressed blue `:focus-visible` ring on mouse clicks in `AdwSidebarItem` (ring now appears only on `Tab` / arrow-key navigation, matching GTK4), removed 30 dead legacy widget shim files, and aligned `flutter_lints: ^3.0.0`.

## 1.0.0-alpha.10

* Fixed `README.md` screenshot and GIF URLs to use absolute `raw.githubusercontent.com` links so they render reliably on `pub.dev`.

## 1.0.0-alpha.9

* **Pure Dart/Flutter Architecture**: Removed the native Android plugin from `adwaitter` (now hosted in `libadwaitter`), making `adwaitter` a 100% pure Dart/Flutter UI library with zero native code and zero external dependencies across all 6 platforms.
* **Accessibility, Reduced Motion & Keyboard Navigation**: Added 1:1 GNOME HIG keyboard navigation (`Tab`/`Shift+Tab`/`Enter`/`Space`/arrows, roving tabindex in `AdwSidebarFocusGroup`, global auto-scroll on focus, 2px focus rings), `Semantics` across all interactive widgets, `AdwSpinRow` numeric `EditableText`, Reduced Motion parity, and Web CSS Media Queries (`prefers-reduced-motion`, `prefers-contrast`, `forced-colors`).
* **Mobile System Bar Contrast**: Added automatic `AnnotatedRegion<SystemUiOverlayStyle>` in `AdwApplication` to sync status bar and navigation bar icon brightness with Light/Dark themes.
* **Widget Test Suite & Showcase**: Expanded widget test suite to 60 passing tests and added desktop/mobile screenshots and animation GIFs to `README.md`.

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
