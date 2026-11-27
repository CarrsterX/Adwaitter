/// Cross-platform pure Dart & Flutter implementation of GNOME Libadwaita (1.10+)
/// and the GNOME Human Interface Guidelines (HIG).
///
/// `adwaitter` is built strictly on `package:flutter/widgets.dart` with zero
/// dependency on `material.dart` or `cupertino.dart`, and runs across Linux,
/// Android, iOS, macOS, Windows, and Web/WASM.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:adwaitter/adwaitter.dart';
/// import 'package:flutter/widgets.dart';
///
/// void main() {
///   runApp(
///     const AdwApplication(
///       title: 'My App',
///       home: AdwWindow(
///         headerBar: AdwHeaderBar(
///           titleWidget: AdwWindowTitle(title: 'My App'),
///         ),
///         child: AdwStatusPage(
///           title: Text('Hello, Adwaita!'),
///           description: Text('Built with pure Flutter and Adwaitter.'),
///         ),
///       ),
///     ),
///   );
/// }
/// ```
///
/// Browse the **Topics** sidebar to explore widgets by category: **Layout**,
/// **Navigation**, **Containers**, **Controls**, **Overlays**, **Display**,
/// **Theming & Localization**, and **Core**.
library adwaitter;

// Core framework behaviors
export 'src/core/adw_scroll_behavior.dart';
export 'src/core/adw_scrollbar.dart';
export 'src/core/adw_spring.dart';
export 'src/core/adw_text_selection.dart';

// Theme and design tokens
export 'src/l10n/adw_localizations.dart';
export 'src/theme/adw_colors.dart';
export 'src/theme/adw_curves.dart';
export 'src/theme/adw_desktop_settings.dart';
export 'src/theme/adw_metrics.dart';
export 'src/theme/adw_style_manager.dart';
export 'src/theme/adw_theme.dart';
export 'src/theme/adw_typography.dart';

// Widgets: Controls
export 'src/widgets/controls/adw_button.dart';
export 'src/widgets/controls/adw_button_content.dart';
export 'src/widgets/controls/adw_button_row.dart';
export 'src/widgets/controls/adw_check_button.dart';
export 'src/widgets/controls/adw_combo_row.dart';
export 'src/widgets/controls/adw_dropdown.dart';
export 'src/widgets/controls/adw_entry.dart';
export 'src/widgets/controls/adw_entry_row.dart';
export 'src/widgets/controls/adw_search_bar.dart';
export 'src/widgets/controls/adw_slider.dart';
export 'src/widgets/controls/adw_split_button.dart';
export 'src/widgets/controls/adw_spin_row.dart';
export 'src/widgets/controls/adw_switch.dart';
export 'src/widgets/controls/adw_switch_row.dart';
export 'src/widgets/controls/adw_toggle_group.dart';

// Widgets: Containers
export 'src/widgets/containers/adw_action_row.dart';
export 'src/widgets/containers/adw_card.dart';
export 'src/widgets/containers/adw_expander_row.dart';
export 'src/widgets/containers/adw_linked_box.dart';
export 'src/widgets/containers/adw_osd_surface.dart';
export 'src/widgets/containers/adw_preferences_group.dart';
export 'src/widgets/containers/adw_preferences_page.dart';
export 'src/widgets/containers/adw_status_page.dart';

// Widgets: Layout
export 'src/widgets/layout/adw_application.dart';
export 'src/widgets/layout/adw_breakpoint_bin.dart';
export 'src/widgets/layout/adw_clamp.dart';
export 'src/widgets/layout/adw_clamp_scrollable.dart';
export 'src/widgets/layout/adw_header_bar.dart';
export 'src/widgets/layout/adw_multi_layout_view.dart';
export 'src/widgets/layout/adw_sub_window.dart';
export 'src/widgets/layout/adw_toolbar_view.dart';
export 'src/widgets/layout/adw_window.dart';
export 'src/widgets/layout/adw_window_controls.dart';
export 'src/widgets/layout/adw_window_title.dart';
export 'src/widgets/layout/adw_wrap_box.dart';

// Widgets: Navigation
export 'src/widgets/navigation/adw_carousel.dart';
export 'src/widgets/navigation/adw_carousel_indicator_dots.dart';
export 'src/widgets/navigation/adw_carousel_indicator_lines.dart';
export 'src/widgets/navigation/adw_navigation_split_view.dart';
export 'src/widgets/navigation/adw_navigation_transition.dart';
export 'src/widgets/navigation/adw_navigation_view.dart';
export 'src/widgets/navigation/adw_overlay_split_view.dart';
export 'src/widgets/navigation/adw_sidebar.dart';
export 'src/widgets/navigation/adw_sidebar_item.dart';
export 'src/widgets/navigation/adw_tab_view.dart';
export 'src/widgets/navigation/adw_view_switcher.dart';

// Widgets: Overlays
export 'src/widgets/overlays/adw_about_dialog.dart';
export 'src/widgets/overlays/adw_alert_dialog.dart';
export 'src/widgets/overlays/adw_banner.dart';
export 'src/widgets/overlays/adw_bottom_sheet.dart';
export 'src/widgets/overlays/adw_context_menu.dart';
export 'src/widgets/overlays/adw_dialog.dart';
export 'src/widgets/overlays/adw_popover.dart';
export 'src/widgets/overlays/adw_preferences_dialog.dart';
export 'src/widgets/overlays/adw_shortcuts_dialog.dart';
export 'src/widgets/overlays/adw_toast.dart';
export 'src/widgets/overlays/adw_tooltip.dart';

// Widgets: Display
export 'src/widgets/display/adw_avatar.dart';
export 'src/widgets/display/adw_emblem.dart';
export 'src/widgets/display/adw_level_bar.dart';
export 'src/widgets/display/adw_progress_bar.dart';
export 'src/widgets/display/adw_spinner.dart';
