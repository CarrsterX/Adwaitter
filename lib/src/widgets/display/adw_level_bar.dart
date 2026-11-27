import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_theme.dart';

/// Libadwaita level indicator (`GtkLevelBar`).
///
/// Renders either a continuous bar (`segments == null`) or a discrete segmented
/// bar (`segments != null`, e.g. password strength or disk usage). When [color]
/// is omitted, the fill color automatically adapts to warning (≤ 25%), accent,
/// or success (100%).
///
/// ```dart
/// const AdwLevelBar(
///   value: 0.75,
///   segments: 5,
/// )
/// ```
///
/// See also:
///
/// * [AdwProgressBar], for determinate or indeterminate task progress.
///
/// {@category Display}
class AdwLevelBar extends StatelessWidget {
  /// Current level value between [minValue] and [maxValue].
  final double value;

  /// Minimum bound of the bar range. Defaults to `0.0`.
  final double minValue;

  /// Maximum bound of the bar range. Defaults to `1.0`.
  final double maxValue;

  /// Optional number of discrete segments. When `null` or `<= 1`, renders a
  /// continuous bar.
  final int? segments;

  /// Height of the bar in logical pixels. Defaults to `6.0`.
  final double height;

  /// Optional override for the filled bar color.
  final Color? color;

  /// Optional override for the unfilled track color.
  final Color? trackColor;

  /// Horizontal gap between discrete segments when [segments] is set.
  /// Defaults to `3.0`.
  final double segmentSpacing;

  /// Creates a Libadwaita level indicator bar.
  const AdwLevelBar({
    super.key,
    required this.value,
    this.minValue = 0.0,
    this.maxValue = 1.0,
    this.segments,
    this.height = 6.0,
    this.color,
    this.trackColor,
    this.segmentSpacing = 3.0,
  });

  Color _resolveFillColor(AdwThemeData theme, double fraction) {
    if (color != null) return color!;
    if (fraction <= 0.25) return theme.colors.standaloneWarningColor;
    if (fraction >= 0.999) return theme.colors.standaloneSuccessColor;
    return theme.colors.accentColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final range = (maxValue - minValue).abs();
    final fraction =
        range <= 0 ? 0.0 : ((value - minValue) / range).clamp(0.0, 1.0);
    final fillColor = _resolveFillColor(theme, fraction);
    final emptyColor = trackColor ??
        theme.colors.windowForeground.withValues(alpha: 0.12);

    if (segments != null && segments! > 1) {
      final count = segments!;
      final filledCount = (fraction * count).round().clamp(0, count);
      return Row(
        children: [
          for (int i = 0; i < count; i++) ...[
            if (i > 0) SizedBox(width: segmentSpacing),
            Expanded(
              child: AnimatedContainer(
                duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
                curve: AdwCurves.standard,
                height: height,
                decoration: BoxDecoration(
                  color: i < filledCount ? fillColor : emptyColor,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: emptyColor,
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
          curve: AdwCurves.standard,
          widthFactor: fraction,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        ),
      ),
    );
  }
}
