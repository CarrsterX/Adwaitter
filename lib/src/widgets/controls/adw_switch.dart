import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show HapticFeedback, MethodChannel;
import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_desktop_settings.dart';
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
  bool _isFocused = false;
  double? _dragProgress;
  bool _hapticTriggeredThisGesture = false;

  bool get _isEnabled => widget.onChanged != null;

  static const MethodChannel _styleChannel = MethodChannel('libadwaitter/style');

  void _triggerHapticLock(bool targetChecked) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      _styleChannel.invokeMethod<void>(
        'performSwitchHaptic',
        <String, Object>{'checked': targetChecked},
      ).catchError((_) {
        HapticFeedback.lightImpact();
      });
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  void didUpdateWidget(covariant AdwSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (_hapticTriggeredThisGesture) {
        _hapticTriggeredThisGesture = false;
      } else if (_isEnabled) {
        _triggerHapticLock(widget.value);
      }
    }
  }

  void _handleTap() {
    if (_isEnabled) {
      _hapticTriggeredThisGesture = true;
      _triggerHapticLock(!widget.value);
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
      final baseOff = theme.colors.switchOffTrackColor;
      if (_isPressed && _isEnabled) {
        trackColor = Color.lerp(
          baseOff,
          isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
          0.16,
        )!;
      } else if (_isHovered && _isEnabled) {
        trackColor = theme.colors.switchOffTrackHoverColor;
      } else {
        trackColor = baseOff;
      }
    }

    if (!_isEnabled) {
      trackColor = trackColor.withValues(alpha: 0.5);
    }

    Color sliderColor;
    if (effectiveChecked ||
        theme.colors.isHighContrast ||
        _isHovered ||
        _isPressed ||
        !isDark) {
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

    final Duration duration = AdwCurves.switchDuration;

    return Semantics(
      toggled: widget.value,
      enabled: _isEnabled,
      onTap: _isEnabled ? _handleTap : null,
      child: FocusableActionDetector(
        enabled: _isEnabled,
        mouseCursor:
            _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (hovered) {
          if (!_isEnabled) return;
          if (_isHovered != hovered) {
            setState(() {
              _isHovered = hovered;
              if (!hovered && _dragProgress == null) {
                _isPressed = false;
              }
            });
          }
        },
        onShowFocusHighlight: (focused) {
          if (_isFocused != focused) {
            setState(() => _isFocused = focused);
          }
        },
        actions: _isEnabled
            ? <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    _handleTap();
                    return null;
                  },
                ),
              }
            : const <Type, Action<Intent>>{},
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
          _hapticTriggeredThisGesture = false;
          setState(() {
            _isPressed = true;
            _dragProgress = widget.value ? 1.0 : 0.0;
          });
        },
        onHorizontalDragUpdate: (details) {
          if (!_isEnabled || _dragProgress == null) return;
          final delta = details.primaryDelta ?? 0.0;
          final double prev = _dragProgress!;
          final double next = (prev + delta / travelDistance).clamp(0.0, 1.0);
          if ((prev < 0.5 && next >= 0.5) || (prev >= 0.5 && next < 0.5)) {
            _hapticTriggeredThisGesture = true;
            _triggerHapticLock(next >= 0.5);
          }
          setState(() {
            _dragProgress = next;
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
            if (!_hapticTriggeredThisGesture) {
              _hapticTriggeredThisGesture = true;
              _triggerHapticLock(nextValue);
            }
            widget.onChanged!(nextValue);
          } else {
            _hapticTriggeredThisGesture = false;
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
          foregroundDecoration: _isFocused
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(switchHeight / 2),
                  border: Border.all(
                    color: theme.colors.focusBorderColor,
                    width: 2.0,
                  ),
                )
              : null,
          child: ValueListenableBuilder<bool>(
            valueListenable: AdwDesktopSettings.showStatusShapes,
            builder: (context, showShapes, sliderChild) {
              return Stack(
                children: [
                  if (showShapes) ...[
                    // ON indicator: centered vertical bar `|` in left half
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: switchWidth / 2,
                      child: Center(
                        child: AnimatedOpacity(
                          duration: duration,
                          opacity: effectiveChecked ? 1.0 : 0.0,
                          child: Container(
                            width: 2.5,
                            height: 10.0,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(1.25),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // OFF indicator: centered circle `○` in right half
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: switchWidth / 2,
                      child: Center(
                        child: AnimatedOpacity(
                          duration: duration,
                          opacity: effectiveChecked ? 0.0 : 1.0,
                          child: Container(
                            width: 10.0,
                            height: 10.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colors.switchShapeOffColor,
                                width: 2.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  sliderChild!,
                ],
              );
            },
            child: AnimatedPositioned(
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
          ),
        ),
      ),
      ),
    );
  }
}
