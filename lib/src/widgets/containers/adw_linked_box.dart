import 'package:flutter/widgets.dart';

import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';

/// Libadwaita linked control group container (`.linked`).
///
/// Joins adjacent controls (such as [AdwButton] and [AdwEntry]) horizontally or
/// vertically with 1px separators and outer rounded corners matching
/// [AdwMetrics.buttonRadius].
class AdwLinkedBox extends StatelessWidget {
  final List<Widget> children;
  final Axis direction;
  final double borderRadius;
  final Color? dividerColor;
  final MainAxisSize mainAxisSize;

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
    final gapColor = dividerColor ?? theme.colors.windowBackground;

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

    return ClipRRect(
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
  }
}
