import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';

/// Libadwaita toggle switch widget (`AdwSwitch`).
///
/// Follows upstream Libadwaita specifications:
/// - Track: 46x26px pill (`border-radius: 14px; padding: 3px;`)
/// - Slider: 20x20px circle (`min-width: 20px; min-height: 20px; border-radius: 50%;`)
/// - Perfectly vertically centered with uniform 3px margins on top, bottom, and travel limits
/// - Upstream Libadwaita shadow: `box-shadow: 0 2px 4px RGB(0 0 6/20%)`
/// - Accent colored when checked, subtle monochrome surface tint when unchecked
class AdwSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AdwSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<AdwSwitch> createState() => _AdwSwitchState();
}

class _AdwSwitchState extends State<AdwSwitch> {
  bool _isHovered = false;
  bool _isPressed = false;
  double? _dragProgress;

  bool get _isEnabled => widget.onChanged != null;

  void _handleTap() {
    if (_isEnabled) {
      widget.onChanged!(!widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final isDark = theme.colors.isDark;
    final effectiveChecked =
        _dragProgress != null ? _dragProgress! >= 0.5 : widget.value;

    // Upstream Libadwaita CSS:
    // switch { border-radius: 14px; padding: 3px; background-color: color-mix(in srgb, currentColor 15%, transparent); }
    // switch:hover { background-color: color-mix(in srgb, currentColor 20%, transparent); }
    // switch:active { background-color: color-mix(in srgb, currentColor 25%, transparent); }
    // switch:checked { background-color: var(--accent-bg-color); }
    // switch > slider { min-width: 20px; min-height: 20px; border-radius: 50%; box-shadow: 0 2px 4px RGB(0 0 6/20%); }
    // switch:checked > slider { background-color: white; }
    // switch > slider: background-color: color-mix(in srgb, white 80%, var(--view-bg-color));

    Color trackColor;
    if (effectiveChecked) {
      trackColor = theme.colors.accentColor;
      if (_isPressed && _isEnabled) {
        trackColor = Color.lerp(trackColor, const Color(0xFF000000), 0.15)!;
      } else if (_isHovered && _isEnabled) {
        trackColor = Color.lerp(trackColor, const Color(0xFFFFFFFF), 0.12)!;
      }
    } else {
      if (isDark) {
        if (_isPressed && _isEnabled) {
          trackColor = const Color(0x40FFFFFF); // 25% white
        } else if (_isHovered && _isEnabled) {
          trackColor = const Color(0x33FFFFFF); // 20% white
        } else {
          trackColor = const Color(0x26FFFFFF); // 15% white
        }
      } else {
        if (_isPressed && _isEnabled) {
          trackColor = const Color(0x40000000); // 25% black
        } else if (_isHovered && _isEnabled) {
          trackColor = const Color(0x33000000); // 20% black
        } else {
          trackColor = const Color(0x26000000); // 15% black
        }
      }
    }

    if (!_isEnabled) {
      trackColor = trackColor.withValues(alpha: 0.5);
    }

    Color sliderColor;
    if (effectiveChecked || _isHovered || _isPressed || !isDark) {
      sliderColor = const Color(0xFFFFFFFF);
    } else {
      // 80% white + 20% view-bg-color (#1D1D20)
      sliderColor = const Color(0xFFD2D2D4);
    }

    if (!_isEnabled) {
      sliderColor = sliderColor.withValues(alpha: 0.7);
    }

    const double switchWidth = AdwMetrics.switchWidth; // 46.0
    const double switchHeight = AdwMetrics.switchHeight; // 26.0
    const double sliderSize = 20.0;
    const double sliderPadding = 3.0;
    const double travelDistance =
        switchWidth - sliderSize - (sliderPadding * 2); // 20.0

    final double sliderLeft = _dragProgress != null
        ? sliderPadding + (_dragProgress! * travelDistance)
        : (widget.value
            ? switchWidth - sliderSize - sliderPadding // 23.0
            : sliderPadding); // 3.0

    final Duration duration =
        AdwCurves.resolve(context, AdwCurves.switchDuration);

    return MouseRegion(
      cursor: _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (_isEnabled) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isEnabled) {
          setState(() {
            _isHovered = false;
            if (_dragProgress == null) {
              _isPressed = false;
            }
          });
        }
      },
      child: GestureDetector(
        // Exclude PointerDeviceKind.trackpad: native GtkSwitch supports
        // touch swipe and mouse click-and-hold drag, but never two-finger
        // touchpad scroll gestures.
        supportedDevices: const <PointerDeviceKind>{
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
        onTapDown: (_) {
          if (_isEnabled) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (_isEnabled) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (_isEnabled && _dragProgress == null) {
            setState(() => _isPressed = false);
          }
        },
        onTap: _handleTap,
        onHorizontalDragStart: (_) {
          if (!_isEnabled) return;
          setState(() {
            _isPressed = true;
            _dragProgress = widget.value ? 1.0 : 0.0;
          });
        },
        onHorizontalDragUpdate: (details) {
          if (!_isEnabled || _dragProgress == null) return;
          final delta = details.primaryDelta ?? 0.0;
          setState(() {
            _dragProgress =
                (_dragProgress! + delta / travelDistance).clamp(0.0, 1.0);
          });
        },
        onHorizontalDragEnd: (details) {
          if (!_isEnabled) return;
          final velocity = details.primaryVelocity ?? 0.0;
          final bool nextValue;
          if (velocity.abs() > 50.0) {
            nextValue = velocity > 0.0;
          } else {
            nextValue = (_dragProgress ?? (widget.value ? 1.0 : 0.0)) >= 0.5;
          }
          setState(() {
            _isPressed = false;
            _dragProgress = null;
          });
          if (nextValue != widget.value) {
            widget.onChanged!(nextValue);
          }
        },
        onHorizontalDragCancel: () {
          if (!_isEnabled) return;
          setState(() {
            _isPressed = false;
            _dragProgress = null;
          });
        },
        child: AnimatedContainer(
          duration: duration,
          curve: AdwCurves.standard,
          width: switchWidth,
          height: switchHeight,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(switchHeight / 2),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: _dragProgress != null ? Duration.zero : duration,
                curve: AdwCurves.standard,
                left: sliderLeft,
                top: sliderPadding,
                bottom: sliderPadding,
                width: sliderSize,
                child: Container(
                  width: sliderSize,
                  height: sliderSize,
                  decoration: BoxDecoration(
                    color: sliderColor,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000), // 20% shadow opacity
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
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
