import 'package:flutter/widgets.dart';

import '../../core/adw_insets.dart';
import '../../theme/adw_theme.dart';
import '../layout/adw_clamp.dart';
import 'adw_page_header.dart';

/// Libadwaita status or welcome page widget (`AdwStatusPage`).
///
/// Displays an optional central [icon] (such as an [AdwEmblem]), bold [title],
/// explanatory [description], and optional body/action [child] — commonly used
/// for welcome screens, empty states, and error views.
///
/// ```dart
/// const AdwStatusPage(
///   icon: AdwEmblem(size: 96),
///   title: Text('Welcome'),
///   description: Text('Select an item from the sidebar to begin.'),
/// )
/// ```
///
/// See also:
///
/// * [AdwPreferencesPage], for scrollable preference groups.
/// * [AdwEmblem], the geometric Libadwaita hero emblem.
///
/// {@category Containers}
class AdwStatusPage extends StatelessWidget {
  /// Optional large hero icon or illustration centered above [title].
  final Widget? icon;

  /// Optional bold heading displayed in the center of the status page.
  final Widget? title;

  /// Optional explanatory text displayed below [title].
  final Widget? description;

  /// Optional action button or custom content displayed below [description].
  final Widget? child;

  /// Maximum width of the clamped content column. Defaults to `450.0`.
  final double maxWidth;

  /// Vertical scroll padding around the status page content.
  final EdgeInsetsGeometry padding;

  /// Whether [child] is constrained inside [maxWidth] alongside the header.
  /// Defaults to `true`.
  final bool clampChild;

  /// Creates a Libadwaita status or empty-state page.
  const AdwStatusPage({
    super.key,
    this.icon,
    this.title,
    this.description,
    this.child,
    this.maxWidth = 450.0,
    this.padding = const EdgeInsets.only(top: 38.0, bottom: 38.0),
    this.clampChild = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final double bottomSafeInset =
        adwBottomSystemInset(context);
    final EdgeInsetsGeometry resolvedPadding = bottomSafeInset > 0.0
        ? padding.add(EdgeInsets.only(bottom: bottomSafeInset))
        : padding;

    final headerWidgets = buildAdwPageHeader(
      theme: theme,
      icon: icon,
      title: title,
      description: description,
      hasContentAfter: child != null,
    );

    return Center(
      child: SingleChildScrollView(
        padding: resolvedPadding,
        child: clampChild
            ? AdwClamp(
                maximumSize: maxWidth,
                minimumMargin: 16.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ...headerWidgets,
                    if (child != null) child!,
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (headerWidgets.isNotEmpty)
                    AdwClamp(
                      maximumSize: maxWidth,
                      minimumMargin: 0.0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: headerWidgets,
                      ),
                    ),
                  if (child != null) child!,
                ],
              ),
      ),
    );
  }
}
