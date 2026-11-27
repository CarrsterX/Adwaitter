import 'package:flutter/widgets.dart';

import '../../core/adw_insets.dart';
import '../../core/adw_scrollbar.dart';
import 'adw_clamp.dart';

/// Scrollable variant of [AdwClamp] matching GNOME Libadwaita's
/// `AdwClampScrollable`.
///
/// Keeps the [AdwScrollbar] anchored at the outer edge of the viewport while
/// clamping and centering [child] to [maximumSize], and automatically pads
/// bottom system safe-area insets.
///
/// ```dart
/// const AdwClampScrollable(
///   maximumSize: 600,
///   child: Text('Long readable content…'),
/// )
/// ```
///
/// See also:
///
/// * [AdwClamp], the non-scrolling width clamp.
/// * [AdwPreferencesPage], for clamped scrollable preference groups.
///
/// {@category Layout}
class AdwClampScrollable extends StatefulWidget {
  /// Scrollable content centered inside the clamped column.
  final Widget child;

  /// Maximum width of [child] in [unit]. Defaults to `600.0`.
  final double maximumSize;

  /// Width in [unit] above which growth eases smoothly toward [maximumSize].
  /// Defaults to `400.0`.
  final double tighteningThreshold;

  /// Length unit for [maximumSize] and [tighteningThreshold].
  /// Defaults to [AdwLengthUnit.px].
  final AdwLengthUnit unit;

  /// Scroll padding applied around the clamped content.
  final EdgeInsetsGeometry padding;

  /// Optional external [ScrollController].
  final ScrollController? controller;

  /// Optional custom [ScrollPhysics].
  final ScrollPhysics? physics;

  /// Creates a scrollable Libadwaita width clamp.
  const AdwClampScrollable({
    super.key,
    required this.child,
    this.maximumSize = 600.0,
    this.tighteningThreshold = 400.0,
    this.unit = AdwLengthUnit.px,
    this.padding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 24.0),
    this.controller,
    this.physics,
  });

  @override
  State<AdwClampScrollable> createState() => _AdwClampScrollableState();
}

class _AdwClampScrollableState extends State<AdwClampScrollable> {
  ScrollController? _internalController;

  ScrollController get _controller =>
      widget.controller ?? (_internalController ??= ScrollController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = adwBottomSystemInset(context);
    final resolvedPadding = widget.padding
        .resolve(Directionality.of(context))
        .add(EdgeInsets.only(bottom: bottomInset));

    return AdwScrollbar(
      axisDirection: AxisDirection.down,
      controller: _controller,
      child: SingleChildScrollView(
        controller: _controller,
        physics: widget.physics,
        padding: resolvedPadding,
        child: AdwClamp(
          maximumSize: widget.maximumSize,
          tighteningThreshold: widget.tighteningThreshold,
          unit: widget.unit,
          child: widget.child,
        ),
      ),
    );
  }
}
