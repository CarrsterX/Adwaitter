import 'package:flutter/widgets.dart';

import '../../core/adw_insets.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../layout/adw_clamp.dart';
import 'adw_page_header.dart';

/// Scrollable preferences and boxed-list page (`AdwPreferencesPage`).
///
/// Lays out [children] (typically [AdwPreferencesGroup] widgets) inside a
/// clamped scrollable column with uniform inter-group spacing ([groupSpacing])
/// and optional header metadata ([icon], [title], [description]).
class AdwPreferencesPage extends StatelessWidget {
  final Widget? icon;
  final Widget? title;
  final Widget? description;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;
  final double minimumMargin;
  final double groupSpacing;

  const AdwPreferencesPage({
    super.key,
    this.icon,
    this.title,
    this.description,
    required this.children,
    this.padding,
    this.maxWidth = AdwMetrics.preferencesPageMaxWidth,
    this.minimumMargin = 12.0,
    this.groupSpacing = AdwMetrics.preferencesGroupSpacing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final double bottomSafeInset =
        adwBottomSystemInset(context);
    final basePadding = padding ??
        ((icon != null || title != null)
            ? const EdgeInsets.only(top: 38.0, bottom: 35.0)
            : const EdgeInsets.symmetric(vertical: 24.0));
    final resolvedPadding = bottomSafeInset > 0.0
        ? basePadding.add(EdgeInsets.only(bottom: bottomSafeInset))
        : basePadding;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: resolvedPadding,
      child: AdwClamp(
        maximumSize: maxWidth,
        minimumMargin: minimumMargin,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null || title != null)
              ...buildAdwPageHeader(
                theme: theme,
                icon: icon,
                title: title,
                description: description,
                hasContentAfter: children.isNotEmpty,
              )
            else if (description != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 2.0, right: 2.0),
                child: DefaultTextStyle(
                  style: theme.typography.body.copyWith(
                    color: theme.colors.windowForeground.withValues(alpha: 0.55),
                  ),
                  textAlign: TextAlign.start,
                  child: description!,
                ),
              ),
              if (children.isNotEmpty && groupSpacing > 0)
                SizedBox(height: groupSpacing),
            ],
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1 && groupSpacing > 0)
                SizedBox(height: groupSpacing),
            ],
          ],
        ),
      ),
    );
  }
}

