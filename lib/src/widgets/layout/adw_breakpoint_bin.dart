import 'package:flutter/widgets.dart';

import 'adw_clamp.dart';

/// A responsive breakpoint condition for [AdwBreakpointBin], matching
/// GNOME Libadwaita's `AdwBreakpointCondition`.
///
/// {@category Layout}
class AdwBreakpoint {
  /// Identifier name for this breakpoint (e.g. `'compact'`, `'medium'`).
  final String name;

  /// Optional maximum viewport width in [unit] for this breakpoint to match.
  final double? maxWidth;

  /// Optional minimum viewport width in [unit] for this breakpoint to match.
  final double? minWidth;

  /// Optional maximum viewport height in [unit] for this breakpoint to match.
  final double? maxHeight;

  /// Optional minimum viewport height in [unit] for this breakpoint to match.
  final double? minHeight;

  /// Length unit used to interpret dimension bounds. Defaults to [AdwLengthUnit.sp].
  final AdwLengthUnit unit;

  /// Creates a responsive breakpoint condition.
  const AdwBreakpoint({
    required this.name,
    this.maxWidth,
    this.minWidth,
    this.maxHeight,
    this.minHeight,
    this.unit = AdwLengthUnit.sp,
  });

  /// Returns `true` if [constraints] satisfy all non-null bounds of this
  /// breakpoint under the given [textScale].
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
///
/// ```dart
/// AdwBreakpointBin(
///   breakpoints: const [
///     AdwBreakpoint(name: 'compact', maxWidth: 500),
///   ],
///   builder: (context, bp, constraints) {
///     return Text(bp?.name ?? 'wide');
///   },
/// )
/// ```
///
/// See also:
///
/// * [AdwMultiLayoutView], for swapping between named layouts at breakpoints.
/// * [AdwClamp], for width-constrained content.
///
/// {@category Layout}
class AdwBreakpointBin extends StatelessWidget {
  /// Ordered list of breakpoint conditions evaluated against available space.
  final List<AdwBreakpoint> breakpoints;

  /// Builder invoked with the first matching [AdwBreakpoint] (or `null`) and
  /// the current [BoxConstraints].
  final Widget Function(
    BuildContext context,
    AdwBreakpoint? currentBreakpoint,
    BoxConstraints constraints,
  ) builder;

  /// Creates a reactive breakpoint container.
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
