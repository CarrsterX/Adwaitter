import 'package:flutter/widgets.dart';

import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../controls/adw_button_row.dart';

/// Provides the exact [BorderRadius] for a row's position inside an
/// [AdwPreferencesGroup] (top-rounded for first, bottom-rounded for last,
/// all-rounded for single/separated, square for middle rows).
///
/// {@category Containers}
class AdwGroupRowShape extends InheritedWidget {
  /// Corner radius corresponding to this row's position in its parent group.
  final BorderRadius borderRadius;

  /// Creates an inherited row-shape provider wrapping [child].
  const AdwGroupRowShape({
    super.key,
    required this.borderRadius,
    required super.child,
  });

  /// Returns the nearest [AdwGroupRowShape.borderRadius], or a uniform
  /// [AdwMetrics.cardRadius] when used outside an [AdwPreferencesGroup].
  static BorderRadius borderRadiusOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AdwGroupRowShape>()
            ?.borderRadius ??
        BorderRadius.circular(AdwMetrics.cardRadius);
  }

  @override
  bool updateShouldNotify(AdwGroupRowShape oldWidget) =>
      borderRadius != oldWidget.borderRadius;
}

/// Container group for preferences (`AdwPreferencesGroup`).
///
/// Groups preference rows ([AdwActionRow], [AdwSwitchRow], [AdwExpanderRow],
/// [AdwComboRow], [AdwEntryRow], [AdwSpinRow], [AdwButtonRow]) inside a
/// rounded boxed-list card (`12px`) with subtle 1px dividers between items.
///
/// ```dart
/// const AdwPreferencesGroup(
///   title: Text('General'),
///   description: Text('Configure basic application behavior.'),
///   children: [
///     AdwActionRow(title: Text('Theme')),
///     AdwActionRow(title: Text('Language')),
///   ],
/// )
/// ```
///
/// See also:
///
/// * [AdwPreferencesPage], which arranges multiple groups in a clamped page.
/// * [AdwActionRow], the standard row placed inside [children].
///
/// {@category Containers}
class AdwPreferencesGroup extends StatelessWidget {
  /// Optional bold section heading displayed above the group.
  final Widget? title;

  /// Optional explanatory text displayed below [title].
  final Widget? description;

  /// Optional trailing widget aligned with the group header (e.g. a button).
  final Widget? headerSuffix;

  /// Rows or widgets displayed inside the group.
  final List<Widget> children;

  /// Outer margin around the entire preferences group.
  final EdgeInsetsGeometry margin;

  /// Whether each child is rendered in its own separated rounded card instead
  /// of a single contiguous boxed list. Defaults to `false`.
  final bool separated;

  /// Vertical gap between cards when [separated] is `true`. Defaults to `12.0`.
  final double separatedSpacing;

  /// Whether to wrap [children] in a rounded card surface. Set to `false` for
  /// unboxed custom content with a group header. Defaults to `true`.
  final bool boxed;

  /// Creates a Libadwaita preferences group.
  const AdwPreferencesGroup({
    super.key,
    this.title,
    this.description,
    this.headerSuffix,
    this.children = const <Widget>[],
    this.margin = EdgeInsets.zero,
    this.separated = false,
    this.separatedSpacing = 12.0,
    this.boxed = true,
  });

  Color _resolveCardBorderColor(AdwThemeData theme, Widget child) {
    if (child is AdwButtonRow) {
      if (child.style == AdwButtonRowStyle.destructive) {
        return theme.colors.destructiveBorderColor;
      }
      if (child.style == AdwButtonRowStyle.suggested) {
        return theme.colors.accentColor;
      }
    }
    return theme.colors.borderColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);

    final List<Widget> itemsWithDividers = [];
    for (int i = 0; i < children.length; i++) {
      final bool isFirst = i == 0;
      final bool isLast = i == children.length - 1;
      final BorderRadius rowRadius = (isFirst && isLast)
          ? BorderRadius.circular(AdwMetrics.cardRadius)
          : isFirst
              ? const BorderRadius.vertical(
                  top: Radius.circular(AdwMetrics.cardRadius),
                )
              : isLast
                  ? const BorderRadius.vertical(
                      bottom: Radius.circular(AdwMetrics.cardRadius),
                    )
                  : BorderRadius.zero;
      itemsWithDividers.add(
        AdwGroupRowShape(
          borderRadius: rowRadius,
          child: children[i],
        ),
      );
      if (i < children.length - 1) {
        itemsWithDividers.add(
          Container(
            height: 1,
            color: theme.colors.isHighContrast
                ? theme.colors.borderColor
                : (theme.colors.isDark
                    ? theme.colors.windowBackground
                    : theme.colors.dividerColor),
          ),
        );
      }
    }

    return Padding(
      padding: margin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || headerSuffix != null)
            Padding(
              padding: const EdgeInsets.only(
                left: 2,
                right: 0,
                bottom: 6,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 34.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (title != null)
                      Expanded(
                        child: DefaultTextStyle(
                          style: theme.typography.heading,
                          child: title!,
                        ),
                      ),
                    if (headerSuffix != null) headerSuffix!,
                  ],
                ),
              ),
            ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 2, bottom: 12),
              child: DefaultTextStyle(
                style: theme.typography.body.copyWith(
                  color: theme.colors.windowForeground.withValues(alpha: 0.55),
                ),
                child: description!,
              ),
            ),
          if (children.isNotEmpty && !boxed)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          if (children.isNotEmpty && boxed && !separated)
            Container(
              decoration: BoxDecoration(
                color: theme.colors.cardBackground,
                borderRadius: BorderRadius.circular(AdwMetrics.cardRadius),
                boxShadow: theme.colors.preferencesGroupShadows,
              ),
              foregroundDecoration: theme.colors.isHighContrast
                  ? BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AdwMetrics.cardRadius),
                      border: Border.all(
                        color: theme.colors.borderColor,
                        width: 1.0,
                      ),
                    )
                  : null,
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: itemsWithDividers,
              ),
            ),
          if (children.isNotEmpty && boxed && separated)
            for (int i = 0; i < children.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i < children.length - 1 ? separatedSpacing : 0.0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colors.cardBackground,
                    borderRadius: BorderRadius.circular(AdwMetrics.cardRadius),
                    boxShadow: theme.colors.preferencesGroupShadows,
                  ),
                  foregroundDecoration: theme.colors.isHighContrast
                      ? BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AdwMetrics.cardRadius),
                          border: Border.all(
                            color: _resolveCardBorderColor(
                              theme,
                              children[i],
                            ),
                            width: 1.0,
                          ),
                        )
                      : null,
                  clipBehavior: children[i] is AdwButtonRow
                      ? Clip.none
                      : Clip.antiAlias,
                  child: children[i],
                ),
              ),
        ],
      ),
    );
  }
}
