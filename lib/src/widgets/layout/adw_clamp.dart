import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Length unit for [AdwClamp] (`AdwLengthUnit`).
enum AdwLengthUnit {
  /// Pixels (`px`), unaffected by text scale factor.
  px,

  /// Points (`pt`), scaled by `96 / 72` and the text scale factor.
  pt,

  /// Scale-independent pixels (`sp`), scaled by the text scale factor.
  sp,
}

/// Converts [value] from [unit] to logical pixels using [textScale].
double adwLengthUnitToPx(
  AdwLengthUnit unit,
  double value, {
  double textScale = 1.0,
}) {
  return switch (unit) {
    AdwLengthUnit.px => value,
    AdwLengthUnit.pt => value * (96.0 / 72.0) * textScale,
    AdwLengthUnit.sp => value * textScale,
  };
}

/// Adaptive width-constraining container (`AdwClamp`).
///
/// Constrains the maximum width of its child according to GNOME HIG guidelines,
/// easing out growth between [tighteningThreshold] and [maximumSize] while
/// keeping it centered horizontally with a guaranteed [minimumMargin].
class AdwClamp extends StatelessWidget {
  final double maximumSize;
  final double tighteningThreshold;
  final double minimumSize;
  final AdwLengthUnit unit;
  final double minimumMargin;
  final double? maximumMargin;
  final Widget child;

  const AdwClamp({
    super.key,
    this.maximumSize = 600.0,
    this.tighteningThreshold = 400.0,
    this.minimumSize = 0.0,
    this.unit = AdwLengthUnit.sp,
    this.minimumMargin = 12.0,
    this.maximumMargin,
    required this.child,
  });

  static const double _easeOutTanCubic = 3.0;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.maybeTextScalerOf(context)?.scale(1.0) ?? 1.0;
    final effectiveMax = adwLengthUnitToPx(
      unit,
      maximumSize,
      textScale: textScale,
    );
    final effectiveThreshold = adwLengthUnitToPx(
      unit,
      tighteningThreshold,
      textScale: textScale,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: minimumMargin),
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: effectiveMax),
                child: child,
              ),
            ),
          );
        }

        final availableWidth = constraints.maxWidth;
        final usableWidth = math.max(0.0, availableWidth - minimumMargin * 2);
        final lower = math.min(effectiveThreshold, effectiveMax);
        final maxVal = math.max(lower, effectiveMax);
        final upper = lower + _easeOutTanCubic * (maxVal - lower);

        final double contentMaxWidth;
        if (usableWidth <= lower) {
          contentMaxWidth = usableWidth;
        } else if (usableWidth >= upper) {
          contentMaxWidth = maxVal;
        } else {
          final progress = (usableWidth - lower) / (upper - lower);
          final ease = 1.0 - math.pow(1.0 - progress, 3.0);
          contentMaxWidth = lower + (maxVal - lower) * ease;
        }

        final double clampedMaxWidth = math.max(
          math.min(usableWidth, minimumSize),
          contentMaxWidth,
        );

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: minimumMargin),
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: clampedMaxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

