import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../../theme/adw_theme.dart';

/// Translucent floating on-screen display surface (`.osd` / `.toolbar.osd`).
///
/// Renders Libadwaita's dark OSD container by default, with optional
/// [backgroundColor], [foregroundColor], and [blurSigma] (using GPU-accelerated
/// [BackdropFilter]) for translucent/frosted media bars and floating controls.
class AdwOsdSurface extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double blurSigma;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  const AdwOsdSurface({
    super.key,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.blurSigma = 0.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(15.0)),
    this.padding = const EdgeInsets.all(6.0),
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final effectiveBg = backgroundColor ?? theme.colors.osdBackground;
    final effectiveFg = foregroundColor ?? theme.colors.osdForeground;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final effectiveSigma = reduceMotion ? 0.0 : blurSigma;

    Widget surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: borderRadius,
        border: border,
        boxShadow: boxShadow,
      ),
      child: DefaultTextStyle(
        style: theme.typography.body.copyWith(color: effectiveFg),
        child: IconTheme(
          data: IconThemeData(color: effectiveFg, size: 16.0),
          child: child,
        ),
      ),
    );

    if (effectiveSigma > 0.0) {
      surface = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: effectiveSigma,
            sigmaY: effectiveSigma,
          ),
          child: surface,
        ),
      );
    }

    return surface;
  }
}
