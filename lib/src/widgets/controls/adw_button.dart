import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';

enum AdwButtonStyle {
  standard,
  flat,
  suggested,
  destructive,
  osd,
  osdFlat,
}

/// Official button widget adhering to Libadwaita metrics and visual states.
class AdwButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final AdwButtonStyle style;
  final bool isPill;
  final bool isCircular;
  final bool isChecked;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AdwButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style = AdwButtonStyle.standard,
    this.isPill = false,
    this.isCircular = false,
    this.isChecked = false,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
  });

  /// Flat button variant (transparent until hovered or active).
  const AdwButton.flat({
    super.key,
    required this.child,
    this.onPressed,
    this.isChecked = false,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
  })  : style = AdwButtonStyle.flat,
        isPill = false,
        isCircular = false;

  /// Suggested action button variant (styled with the active accent color).
  const AdwButton.suggested({
    super.key,
    required this.child,
    this.onPressed,
    this.isPill = false,
    this.isChecked = false,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
  })  : style = AdwButtonStyle.suggested,
        isCircular = false;

  /// Destructive action button variant (styled with GNOME red alert color).
  const AdwButton.destructive({
    super.key,
    required this.child,
    this.onPressed,
    this.isPill = false,
    this.isChecked = false,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
  })  : style = AdwButtonStyle.destructive,
        isCircular = false;

  /// Pill button variant (fully rounded capsule edges).
  const AdwButton.pill({
    super.key,
    required this.child,
    this.onPressed,
    this.style = AdwButtonStyle.standard,
    this.isChecked = false,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
  })  : isPill = true,
        isCircular = false;

  /// Circular button variant for icon actions.
  const AdwButton.circular({
    super.key,
    required this.child,
    this.onPressed,
    this.style = AdwButtonStyle.standard,
    this.isChecked = false,
    this.padding,
    double size = 34.0,
  })  : isPill = false,
        isCircular = true,
        width = size,
        height = size,
        borderRadius = null;

  /// On-screen display (`.osd`) translucent dark button variant.
  const AdwButton.osd({
    super.key,
    required this.child,
    this.onPressed,
    bool isFlat = false,
    this.isPill = false,
    this.isCircular = false,
    this.isChecked = false,
    this.padding = EdgeInsets.zero,
    this.width = 42.0,
    this.height = 42.0,
    this.borderRadius,
  }) : style = isFlat ? AdwButtonStyle.osdFlat : AdwButtonStyle.osd;

  @override
  State<AdwButton> createState() => _AdwButtonState();
}

class _AdwButtonState extends State<AdwButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);

    // Compute background and foreground colors according to style and state
    Color backgroundColor;
    Color foregroundColor;
    Color borderColor = const Color(0x00000000);

    switch (widget.style) {
      case AdwButtonStyle.suggested:
        backgroundColor = theme.colors.accentColor;
        foregroundColor = theme.colors.accentForeground;
        if (_isPressed) {
          backgroundColor =
              Color.lerp(backgroundColor, const Color(0xFF000000), 0.15)!;
        } else if (_isHovered) {
          backgroundColor =
              Color.lerp(backgroundColor, const Color(0xFFFFFFFF), 0.12)!;
        }
        break;

      case AdwButtonStyle.destructive:
        // Matches upstream `_buttons.scss` `%destructive_button`:
        // `color: var(--destructive-color)` with translucent 15%/20%/35% fill.
        foregroundColor = theme.colors.standaloneErrorColor;
        if (_isPressed) {
          backgroundColor = foregroundColor.withValues(
            alpha: widget.isChecked ? 0.45 : 0.35,
          );
        } else if (widget.isChecked) {
          backgroundColor = foregroundColor.withValues(
            alpha: _isHovered ? 0.40 : 0.35,
          );
        } else if (_isHovered) {
          backgroundColor = foregroundColor.withValues(alpha: 0.20);
        } else {
          backgroundColor = foregroundColor.withValues(alpha: 0.15);
        }
        break;

      case AdwButtonStyle.flat:
        foregroundColor = theme.colors.windowForeground;
        if (_isPressed && _isEnabled) {
          backgroundColor = widget.isChecked
              ? foregroundColor.withValues(alpha: 0.19)
              : theme.colors.activeColor;
        } else if (widget.isChecked) {
          backgroundColor = foregroundColor.withValues(
            alpha: (_isHovered && _isEnabled) ? 0.13 : 0.10,
          );
        } else if (_isHovered && _isEnabled) {
          backgroundColor = theme.colors.hoverColor;
        } else {
          backgroundColor = const Color(0x00000000);
        }
        break;

      case AdwButtonStyle.standard:
        foregroundColor = theme.colors.windowForeground;
        if (_isPressed) {
          backgroundColor = foregroundColor.withValues(
            alpha: widget.isChecked ? 0.40 : 0.30,
          );
        } else if (widget.isChecked) {
          backgroundColor = foregroundColor.withValues(
            alpha: _isHovered ? 0.35 : 0.30,
          );
        } else if (_isHovered) {
          backgroundColor = foregroundColor.withValues(alpha: 0.15);
        } else {
          backgroundColor = foregroundColor.withValues(
            alpha: theme.colors.isDark ? 0.12 : 0.08,
          );
        }
        break;

      case AdwButtonStyle.osd:
        foregroundColor = theme.colors.osdForeground;
        if (_isPressed) {
          backgroundColor = theme.colors.osdActiveBackground;
        } else if (_isHovered) {
          backgroundColor = theme.colors.osdHoverBackground;
        } else {
          backgroundColor = theme.colors.osdBackground;
        }
        break;

      case AdwButtonStyle.osdFlat:
        foregroundColor = theme.colors.osdForeground;
        if (_isPressed) {
          backgroundColor = const Color(0x29FFFFFF);
        } else if (_isHovered) {
          backgroundColor = const Color(0x12FFFFFF);
        } else {
          backgroundColor = const Color(0x00000000);
        }
        break;
    }

    if (!_isEnabled) {
      if (widget.style != AdwButtonStyle.flat) {
        backgroundColor = backgroundColor.withValues(alpha: 0.5);
      }
      foregroundColor = foregroundColor.withValues(alpha: 0.4);
    }

    final borderRadius = widget.isCircular || widget.isPill
        ? BorderRadius.circular(AdwMetrics.pillRadius)
        : BorderRadius.circular(AdwMetrics.buttonRadius);

    final defaultPadding = widget.isCircular
        ? EdgeInsets.zero
        : (widget.isPill
            ? const EdgeInsets.symmetric(horizontal: 32, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 6));

    Widget buttonContent = AnimatedDefaultTextStyle(
      duration: AdwCurves.shortDuration,
      style: theme.typography.heading.copyWith(
        color: foregroundColor,
      ),
      child: IconTheme(
        data: IconThemeData(
          color: foregroundColor,
          size: AdwMetrics.iconSizeMedium,
        ),
        child: Center(
          widthFactor: 1.0,
          heightFactor: 1.0,
          child: widget.child,
        ),
      ),
    );

    return MouseRegion(
      cursor: _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (_isEnabled) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isEnabled) {
          setState(() => _isHovered = false);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (_isEnabled) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (_isEnabled) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (_isEnabled) setState(() => _isPressed = false);
        },
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AdwCurves.shortDuration,
          curve: AdwCurves.standard,
          constraints: BoxConstraints(
            minWidth: widget.width ?? 0.0,
            maxWidth: widget.width ?? double.infinity,
            minHeight: widget.height ??
                (widget.isCircular ? 0.0 : AdwMetrics.buttonMinHeight),
            maxHeight: widget.height ?? double.infinity,
          ),
          padding: widget.padding ?? defaultPadding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: widget.borderRadius ?? borderRadius,
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: buttonContent,
        ),
      ),
    );
  }
}
