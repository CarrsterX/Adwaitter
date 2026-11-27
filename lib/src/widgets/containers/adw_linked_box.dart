import 'package:flutter/widgets.dart';

import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';

/// Libadwaita linked control group container (`.linked`).
///
/// Joins adjacent controls (such as [AdwButton] and [AdwEntry]) horizontally or
/// vertically with 1px separators and outer rounded corners matching
/// [AdwMetrics.buttonRadius].
///
/// ```dart
/// AdwLinkedBox(
///   children: [
///     AdwButton(onPressed: () {}, child: const Text('Back')),
///     AdwButton(onPressed: () {}, child: const Text('Forward')),
///   ],
/// )
/// ```
///
/// See also:
///
/// * [AdwToggleGroup], for mutually exclusive segmented toggles.
/// * [AdwSplitButton], for a primary action linked with a dropdown menu.
///
/// {@category Containers}
class AdwLinkedBox extends StatelessWidget {
  /// Child controls to join seamlessly along [direction].
  final List<Widget> children;

  /// Layout axis along which [children] are joined. Defaults to [Axis.horizontal].
  final Axis direction;

  /// Outer corner radius of the linked container.
  /// Defaults to [AdwMetrics.buttonRadius].
  final double borderRadius;

  /// Optional 1px separator color between adjacent controls.
  final Color? dividerColor;

  /// How much space should be occupied in the main axis.
  /// Defaults to [MainAxisSize.min].
  final MainAxisSize mainAxisSize;

  /// Creates a Libadwaita `.linked` control group container.
  const AdwLinkedBox({
    super.key,
    required this.children,
    this.direction = Axis.horizontal,
    this.borderRadius = AdwMetrics.buttonRadius,
    this.dividerColor,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final gapColor = dividerColor ??
        (theme.colors.isHighContrast
            ? theme.colors.borderColor
            : theme.colors.windowBackground);

    final List<Widget> spaced = [];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        spaced.add(
          direction == Axis.horizontal
              ? Container(width: 1.0, color: gapColor)
              : Container(height: 1.0, color: gapColor),
        );
      }
      spaced.add(children[i]);
    }

    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: direction == Axis.horizontal
          ? IntrinsicHeight(
              child: Row(
                mainAxisSize: mainAxisSize,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: spaced,
              ),
            )
          : IntrinsicWidth(
              child: Column(
                mainAxisSize: mainAxisSize,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: spaced,
              ),
            ),
    );

    if (theme.colors.isHighContrast) {
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: theme.colors.borderColor,
            width: 1.0,
          ),
        ),
        child: clipped,
      );
    }

    return clipped;
  }
}
