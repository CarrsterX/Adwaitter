import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';

/// Libadwaita card container (`.card` / `.card.activatable`).
///
/// Renders a rounded card surface with subtle elevation matching upstream
/// `_misc.scss` `%card`. When [activatable] is `true` (or [onPressed] is
/// provided), the card displays hover and press feedback.
///
/// ```dart
/// AdwCard(
///   activatable: true,
///   onPressed: () {},
///   child: const Text('Clickable card'),
/// )
/// ```
///
/// See also:
///
/// * [AdwPreferencesGroup], for boxed lists of preference rows.
/// * [AdwOsdSurface], for translucent floating on-screen display containers.
///
/// {@category Containers}
class AdwCard extends StatefulWidget {
  /// Content displayed inside the card.
  final Widget child;

  /// Whether the card responds to hover and press states. Defaults to `false`.
  final bool activatable;

  /// Optional tap callback. Setting this also enables interactive feedback.
  final VoidCallback? onPressed;

  /// Internal padding around [child]. Defaults to `EdgeInsets.all(12.0)`.
  final EdgeInsetsGeometry padding;

  /// Optional alignment applied to [child] inside the card.
  final AlignmentGeometry? alignment;

  /// Optional corner radius override. Defaults to [AdwMetrics.cardRadius].
  final BorderRadius? borderRadius;

  /// Creates a Libadwaita card container.
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
          duration: AdwCurves.resolve(context, AdwCurves.normalDuration),
          curve: AdwCurves.standard,
          padding: widget.padding,
          alignment: widget.alignment,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: widget.borderRadius ??
                BorderRadius.circular(AdwMetrics.cardRadius),
            border: theme.colors.isHighContrast
                ? Border.all(color: theme.colors.borderColor, width: 1.0)
                : null,
            boxShadow: theme.colors.cardShadows,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
