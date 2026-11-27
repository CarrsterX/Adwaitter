import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';

import '../../theme/adw_theme.dart';

/// Native Libadwaita hover tooltip (`GtkTooltip`).
///
/// Displays a floating dark tooltip near the pointer after [waitDuration]
/// without depending on `material.dart`.
///
/// ```dart
/// const AdwTooltip(
///   message: 'Save changes',
///   child: AdwButton(child: Text('Save')),
/// )
/// ```
///
/// See also:
///
/// * [AdwPopoverSurface], for interactive popovers and menus.
///
/// {@category Overlays}
class AdwTooltip extends StatefulWidget {
  /// Text displayed inside the floating tooltip bubble.
  final String message;

  /// Target widget that triggers the tooltip on hover.
  final Widget child;

  /// Hover delay before the tooltip appears. Defaults to `550ms`.
  final Duration waitDuration;

  /// Creates a Libadwaita hover tooltip wrapping [child].
  const AdwTooltip({
    super.key,
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 550),
  });

  @override
  State<AdwTooltip> createState() => _AdwTooltipState();
}

class _AdwTooltipState extends State<AdwTooltip> {
  OverlayEntry? _entry;
  Timer? _timer;
  Offset? _pointerGlobalPosition;

  @override
  void dispose() {
    _cancelTooltip();
    super.dispose();
  }

  void _scheduleTooltip() {
    _timer?.cancel();
    _timer = Timer(widget.waitDuration, _showTooltip);
  }

  void _cancelTooltip() {
    _timer?.cancel();
    _timer = null;
    _pointerGlobalPosition = null;
    _entry?.remove();
    _entry = null;
  }

  void _showTooltip() {
    if (!mounted || _entry != null) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final RenderBox? targetBox = context.findRenderObject() as RenderBox?;
    final RenderBox? overlayBox =
        overlay.context.findRenderObject() as RenderBox?;
    if (targetBox == null ||
        !targetBox.hasSize ||
        overlayBox == null ||
        !overlayBox.hasSize) {
      return;
    }

    final theme = AdwTheme.of(context);
    final textStyle = theme.typography.body.copyWith(
      color: theme.colors.tooltipForeground,
    );
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    final painter = TextPainter(
      text: TextSpan(text: widget.message, style: textStyle),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 2,
    )..layout(maxWidth: 280.0);

    final tipWidth = painter.width + 20.0;
    final tipHeight = painter.height + 12.0;

    final pointerLocal = _pointerGlobalPosition != null
        ? overlayBox.globalToLocal(_pointerGlobalPosition!)
        : targetBox.localToGlobal(
            Offset(targetBox.size.width / 2, targetBox.size.height),
            ancestor: overlayBox,
          );

    const margin = 8.0;
    final double left = (pointerLocal.dx - tipWidth / 2)
        .clamp(margin,
            math.max(margin, overlayBox.size.width - tipWidth - margin))
        .toDouble();

    double top = pointerLocal.dy + 18.0;
    if (top + tipHeight + margin > overlayBox.size.height) {
      top = math.max(margin, pointerLocal.dy - tipHeight - 12.0);
    }

    _entry = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: theme.colors.tooltipBackground,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: theme.colors.tooltipBorderColor,
                width: 1.0,
              ),
              boxShadow: theme.colors.tooltipShadows,
            ),
            child: DefaultTextStyle(
              style: textStyle,
              child: Text(widget.message),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  bool _isHoverDevice(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.mouse || kind == PointerDeviceKind.trackpad;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      onEnter: (event) {
        if (!_isHoverDevice(event.kind)) return;
        _pointerGlobalPosition = event.position;
        _scheduleTooltip();
      },
      onHover: (event) {
        if (!_isHoverDevice(event.kind)) return;
        _pointerGlobalPosition = event.position;
        if (_entry == null) {
          _scheduleTooltip();
        }
      },
      onExit: (_) => _cancelTooltip(),
      child: widget.child,
    );
  }
}
