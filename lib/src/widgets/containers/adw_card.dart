import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';

/// Libadwaita card container (`.card` / `.card.activatable`).
///
/// Renders a rounded card surface with subtle elevation matching upstream
/// `_misc.scss` `%card`. When [activatable] is `true` (or [onPressed] is
/// provided), the card displays hover and press feedback.
class AdwCard extends StatefulWidget {
  final Widget child;
  final bool activatable;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry? alignment;
  final BorderRadius? borderRadius;

  const AdwCard({
    super.key,
    required this.child,
    this.activatable = false,
    this.onPressed,
    this.padding = const EdgeInsets.all(12.0),
    this.alignment,
    this.borderRadius,
  });

  @override
  State<AdwCard> createState() => _AdwCardState();
}

class _AdwCardState extends State<AdwCard> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _isInteractive => widget.activatable || widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);

    // Matches `_misc.scss` `%card`:
    // `background-color: var(--card-bg-color)`
    // hover adds 3% currentColor, active adds 8% currentColor.
    Color bg = theme.colors.cardBackground;
    if (_isInteractive) {
      if (_pressed) {
        bg = Color.alphaBlend(
          theme.colors.windowForeground.withValues(alpha: 0.08),
          bg,
        );
      } else if (_hovered) {
        bg = Color.alphaBlend(
          theme.colors.windowForeground.withValues(alpha: 0.03),
          bg,
        );
      }
    }

    return MouseRegion(
      cursor:
          _isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (_isInteractive) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_isInteractive) setState(() => _hovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:
            _isInteractive ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _isInteractive
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel:
            _isInteractive ? () => setState(() => _pressed = false) : null,
        child: AnimatedContainer(
          duration: AdwCurves.normalDuration,
          curve: AdwCurves.standard,
          padding: widget.padding,
          alignment: widget.alignment,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: widget.borderRadius ??
                BorderRadius.circular(AdwMetrics.cardRadius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000006),
                blurRadius: 0.0,
                spreadRadius: 1.0,
              ),
              BoxShadow(
                color: Color(0x12000006),
                blurRadius: 3.0,
                spreadRadius: 1.0,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: Color(0x08000006),
                blurRadius: 6.0,
                spreadRadius: 2.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
