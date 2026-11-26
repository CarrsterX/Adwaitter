import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../containers/adw_preferences_group.dart';

enum AdwButtonRowStyle {
  standard,
  suggested,
  destructive,
}

/// Native Libadwaita button row (`AdwButtonRow`).
///
/// Designed to be placed inside a separated [AdwPreferencesGroup] (or standalone)
/// to present prominent centered action rows such as `Add Input Source`,
/// `Delete Event`, or `Search`.
class AdwButtonRow extends StatefulWidget {
  final Widget title;
  final Widget? startIcon;
  final Widget? endIcon;
  final AdwButtonRowStyle style;
  final VoidCallback? onPressed;
  final double minHeight;

  const AdwButtonRow({
    super.key,
    required this.title,
    this.startIcon,
    this.endIcon,
    this.style = AdwButtonRowStyle.standard,
    this.onPressed,
    this.minHeight = 44.0,
  });

  /// Suggested-action button row (accent-colored background with light text).
  const AdwButtonRow.suggested({
    super.key,
    required this.title,
    this.startIcon,
    this.endIcon,
    this.onPressed,
    this.minHeight = 44.0,
  }) : style = AdwButtonRowStyle.suggested;

  /// Destructive-action button row (alert red label).
  const AdwButtonRow.destructive({
    super.key,
    required this.title,
    this.startIcon,
    this.endIcon,
    this.onPressed,
    this.minHeight = 44.0,
  }) : style = AdwButtonRowStyle.destructive;

  @override
  State<AdwButtonRow> createState() => _AdwButtonRowState();
}

class _AdwButtonRowState extends State<AdwButtonRow> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode(debugLabel: 'AdwButtonRow');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final isEnabled = widget.onPressed != null;

    final Color bgColor;
    final Color fgColor;

    final Color idleCardBg = theme.colors.buttonRowBackground;

    final bool isHighlighted = _isHovered || _isFocused;

    switch (widget.style) {
      case AdwButtonRowStyle.standard:
        fgColor = theme.colors.windowForeground;
        if (!isEnabled) {
          bgColor = idleCardBg;
        } else if (_isPressed) {
          bgColor = Color.alphaBlend(theme.colors.activeColor, idleCardBg);
        } else if (isHighlighted) {
          bgColor = theme.colors.buttonRowHoverBackground;
        } else {
          bgColor = idleCardBg;
        }
        break;
      case AdwButtonRowStyle.destructive:
        fgColor = theme.colors.destructiveRowForeground;
        if (!isEnabled) {
          bgColor = idleCardBg;
        } else if (_isPressed) {
          bgColor = Color.alphaBlend(
              fgColor.withValues(alpha: 0.16), idleCardBg);
        } else if (isHighlighted) {
          bgColor = theme.colors.destructiveRowHoverBackground;
        } else {
          bgColor = idleCardBg;
        }
        break;
      case AdwButtonRowStyle.suggested:
        fgColor = theme.colors.accentForeground;
        final base = theme.colors.accentColor;
        if (!isEnabled) {
          bgColor = base.withValues(alpha: 0.5);
        } else if (_isPressed) {
          bgColor = Color.lerp(base, const Color(0xFF000000), 0.15)!;
        } else if (isHighlighted) {
          bgColor = Color.lerp(base, const Color(0xFFFFFFFF), 0.08)!;
        } else {
          bgColor = base;
        }
        break;
    }

    final resolvedFg =
        isEnabled ? fgColor : fgColor.withValues(alpha: 0.45);
    final rowRadius = AdwGroupRowShape.borderRadiusOf(context);
    final Color focusColor = switch (widget.style) {
      AdwButtonRowStyle.destructive =>
        theme.colors.standaloneErrorColor.withValues(alpha: 0.70),
      AdwButtonRowStyle.suggested => theme.colors.focusBorderColor,
      AdwButtonRowStyle.standard => theme.colors.focusBorderColor,
    };
    final bool useOuterOffsetRing =
        _isFocused && widget.style == AdwButtonRowStyle.suggested;

    final Widget rowSurface = AnimatedContainer(
      duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
      curve: AdwCurves.standard,
      constraints: BoxConstraints(minHeight: widget.minHeight),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: rowRadius,
      ),
      foregroundDecoration: (_isFocused && !useOuterOffsetRing)
          ? BoxDecoration(
              borderRadius: rowRadius,
              border: Border.all(
                color: focusColor,
                width: 2.0,
              ),
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Center(
        child: IconTheme(
          data: IconThemeData(
            color: resolvedFg,
            size: AdwMetrics.iconSizeSmall,
          ),
          child: DefaultTextStyle(
            style: theme.typography.heading.copyWith(
              fontSize: 14.0,
              color: resolvedFg,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.startIcon != null) ...[
                  widget.startIcon!,
                  const SizedBox(width: 8),
                ],
                widget.title,
                if (widget.endIcon != null) ...[
                  const SizedBox(width: 8),
                  widget.endIcon!,
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: isEnabled,
      onTap: isEnabled ? widget.onPressed : null,
      child: FocusableActionDetector(
        focusNode: _focusNode,
        enabled: isEnabled,
        mouseCursor:
            isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (hovered) {
          if (isEnabled && _isHovered != hovered) {
            setState(() {
              _isHovered = hovered;
              if (!hovered) _isPressed = false;
            });
          }
        },
        onShowFocusHighlight: (focused) {
          if (_isFocused != focused) {
            setState(() => _isFocused = focused);
          }
        },
        actions: isEnabled
            ? <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    widget.onPressed?.call();
                    return null;
                  },
                ),
              }
            : const <Type, Action<Intent>>{},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            if (isEnabled) setState(() => _isPressed = true);
          },
          onTapUp: (_) {
            if (isEnabled) setState(() => _isPressed = false);
          },
          onTapCancel: () {
            if (isEnabled) setState(() => _isPressed = false);
          },
          onTap: isEnabled
              ? () {
                  _focusNode.requestFocus();
                  widget.onPressed?.call();
                }
              : null,
          child: Stack(
            fit: StackFit.passthrough,
            clipBehavior: Clip.none,
            children: [
              rowSurface,
              if (useOuterOffsetRing)
                Positioned(
                  left: -3.5,
                  right: -3.5,
                  top: -3.5,
                  bottom: -3.5,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: rowRadius.topLeft + const Radius.circular(3.5),
                          topRight:
                              rowRadius.topRight + const Radius.circular(3.5),
                          bottomLeft:
                              rowRadius.bottomLeft + const Radius.circular(3.5),
                          bottomRight:
                              rowRadius.bottomRight + const Radius.circular(3.5),
                        ),
                        border: Border.all(
                          color: focusColor,
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

