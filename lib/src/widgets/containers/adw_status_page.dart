import 'package:flutter/widgets.dart';

import '../../core/adw_insets.dart';
import '../../theme/adw_theme.dart';
import '../layout/adw_clamp.dart';
import 'adw_page_header.dart';

/// Libadwaita status or welcome page widget (`AdwStatusPage`).
///
/// Displays an optional central icon/emblem, bold title, explanatory description,
/// and optional body/action widgets (as seen in `adwaita-1-demo`).
class AdwStatusPage extends StatelessWidget {
  final Widget? icon;
  final Widget? title;
  final Widget? description;
  final Widget? child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool clampChild;

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
