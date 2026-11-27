import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../../theme/adw_theme.dart';

/// Translucent floating on-screen display surface (`.osd` / `.toolbar.osd`).
///
/// Renders Libadwaita's dark OSD container by default, with optional
/// [backgroundColor], [foregroundColor], and [blurSigma] (using GPU-accelerated
/// [BackdropFilter]) for translucent/frosted media bars and floating controls.
///
/// ```dart
/// const AdwOsdSurface(
///   padding: EdgeInsets.all(8),
///   child: Text('Media Controls'),
/// )
/// ```
///
/// See also:
///
/// * [AdwButton.osd], for buttons styled to sit inside an OSD toolbar.
/// * [AdwCard], for standard non-OSD elevated surfaces.
///
/// {@category Containers}
class AdwOsdSurface extends StatelessWidget {
  /// Content displayed inside the OSD surface.
  final Widget child;

  /// Optional surface background override.
  /// Defaults to [AdwColorScheme.osdBackground].
  final Color? backgroundColor;

  /// Optional text and icon foreground override.
  /// Defaults to [AdwColorScheme.osdForeground].
  final Color? foregroundColor;

  /// Gaussian backdrop blur sigma (`0.0` disables blur). Automatically set to
  /// `0.0` when reduced motion is enabled.
  final double blurSigma;

  /// Corner radius of the OSD container. Defaults to `15.0`.
  final BorderRadius borderRadius;

  /// Internal padding around [child]. Defaults to `EdgeInsets.all(6.0)`.
  final EdgeInsetsGeometry padding;

  /// Optional border drawn around the OSD surface.
  final BoxBorder? border;

  /// Optional elevation shadows behind the OSD surface.
  final List<BoxShadow>? boxShadow;

  /// Creates a Libadwaita `.osd` floating surface container.
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
