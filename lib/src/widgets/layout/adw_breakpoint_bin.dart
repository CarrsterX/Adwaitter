import 'package:flutter/widgets.dart';

import 'adw_clamp.dart';

/// A responsive breakpoint condition for [AdwBreakpointBin], matching
/// GNOME Libadwaita's `AdwBreakpointCondition`.
class AdwBreakpoint {
  final String name;
  final double? maxWidth;
  final double? minWidth;
  final double? maxHeight;
  final double? minHeight;
  final AdwLengthUnit unit;

  const AdwBreakpoint({
    required this.name,
    this.maxWidth,
    this.minWidth,
    this.maxHeight,
    this.minHeight,
    this.unit = AdwLengthUnit.sp,
  });

  bool matches(BoxConstraints constraints, {required double textScale}) {
    double toPx(double v) => adwLengthUnitToPx(unit, v, textScale: textScale);

    if (maxWidth != null && constraints.maxWidth > toPx(maxWidth!)) {
      return false;
    }
    if (minWidth != null && constraints.maxWidth < toPx(minWidth!)) {
      return false;
    }
    if (maxHeight != null && constraints.maxHeight > toPx(maxHeight!)) {
      return false;
    }
    if (minHeight != null && constraints.maxHeight < toPx(minHeight!)) {
      return false;
    }
    return true;
  }
}

/// Reactive breakpoint container matching GNOME Libadwaita's `AdwBreakpointBin`.
///
/// Evaluates [breakpoints] in order against the available layout constraints
/// and passes the first matching [AdwBreakpoint] (or `null` if none match) to
/// [builder].
class AdwBreakpointBin extends StatelessWidget {
  final List<AdwBreakpoint> breakpoints;
  final Widget Function(
    BuildContext context,
    AdwBreakpoint? currentBreakpoint,
    BoxConstraints constraints,
  ) builder;

  const AdwBreakpointBin({
    super.key,
    required this.breakpoints,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.maybeTextScalerOf(context)?.scale(1.0) ?? 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        AdwBreakpoint? matched;
        for (final bp in breakpoints) {
          if (bp.matches(constraints, textScale: textScale)) {
            matched = bp;
            break;
          }
        }
        return builder(context, matched, constraints);
      },
    );
  }
}
