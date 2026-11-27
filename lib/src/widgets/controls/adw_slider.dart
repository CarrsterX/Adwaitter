import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../theme/adw_colors.dart';
import '../../theme/adw_theme.dart';

/// Libadwaita scale/slider control (`GtkScale` / `AdwSlider`).
///
/// Supports both horizontal and vertical orientations, optional tick [marks],
/// keyboard arrow stepping, and the `.osd` style class via [isOsd].
///
/// ```dart
/// AdwSlider(
///   value: volume,
///   min: 0.0,
///   max: 1.0,
///   onChanged: (v) {},
/// )
/// ```
///
/// See also:
///
/// * [AdwProgressBar], for read-only progress display.
/// * [AdwSpinRow], for precise numeric entry inside preference lists.
///
/// {@category Controls}
class AdwSlider extends StatefulWidget {
  /// Current slider value between [min] and [max].
  final double value;

  /// Minimum selectable value. Defaults to `0.0`.
  final double min;

  /// Maximum selectable value. Defaults to `1.0`.
  final double max;

  /// Optional list of tick mark positions along the track (in `[min, max]`).
  final List<double>? marks;

  /// Axis along which the slider moves. Defaults to [Axis.horizontal].
  final Axis orientation;

  /// Called continuously as the user drags or adjusts the slider. When `null`,
  /// the slider is disabled.
  final ValueChanged<double>? onChanged;

  /// Whether to use translucent dark `.osd` styling (e.g. inside an
  /// [AdwOsdSurface] media bar). Defaults to `false`.
  final bool isOsd;

  /// Creates a Libadwaita scale/slider control.
  const AdwSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.marks,
    this.orientation = Axis.horizontal,
    required this.onChanged,
    this.isOsd = false,
  });

  @override
  State<AdwSlider> createState() => _AdwSliderState();
}

class _AdwSliderState extends State<AdwSlider> {
  bool _hovered = false;
  bool _active = false;
  bool _focused = false;

  double get _range => (widget.max - widget.min).abs();

  double _toNormalized(double val) {
    if (_range <= 0) return 0.0;
    return ((val - widget.min) / _range).clamp(0.0, 1.0);
  }

  double _fromNormalized(double norm) {
    return widget.min + norm.clamp(0.0, 1.0) * (widget.max - widget.min);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final isEnabled = widget.onChanged != null;
    final isLit = (_hovered || _active) && isEnabled;

    final Color troughColor;
    final Color highlightColor;
    final Color thumbColor;

    if (widget.isOsd) {
      troughColor = isLit
          ? theme.colors.osdSliderTroughLitColor
          : theme.colors.osdSliderTroughColor;
      highlightColor = isLit
          ? theme.colors.osdSliderHighlightLitColor
          : theme.colors.osdSliderHighlightColor;
      thumbColor = isLit ? AdwColors.light1 : theme.colors.osdSliderThumbColor;
    } else {
      final fg = theme.colors.windowForeground;
      troughColor = fg.withValues(alpha: isLit ? 0.20 : 0.15);
      highlightColor = isLit
          ? Color.lerp(theme.colors.accentColor, AdwColors.light1, 0.10)!
          : theme.colors.accentColor;
      thumbColor = theme.colors.sliderThumbColor;
    }

    final clampedValue = _toNormalized(widget.value);

    void stepBy(double delta) {
      if (!isEnabled) return;
      final next = (clampedValue + delta).clamp(0.0, 1.0);
      widget.onChanged!(_fromNormalized(next));
    }

    return Semantics(
      slider: true,
      enabled: isEnabled,
      value: '${(clampedValue * 100).round()}%',
      increasedValue:
          isEnabled ? '${((clampedValue + 0.05).clamp(0.0, 1.0) * 100).round()}%' : null,
      decreasedValue:
          isEnabled ? '${((clampedValue - 0.05).clamp(0.0, 1.0) * 100).round()}%' : null,
      onIncrease: isEnabled ? () => stepBy(0.05) : null,
      onDecrease: isEnabled ? () => stepBy(-0.05) : null,
      child: FocusableActionDetector(
        enabled: isEnabled,
        mouseCursor:
            isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (hovered) {
          if (_hovered != hovered) setState(() => _hovered = hovered);
        },
        onShowFocusHighlight: (focused) {
          if (_focused != focused) setState(() => _focused = focused);
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowRight): _SliderStepIntent(0.05),
          SingleActivator(LogicalKeyboardKey.arrowUp): _SliderStepIntent(0.05),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _SliderStepIntent(-0.05),
          SingleActivator(LogicalKeyboardKey.arrowDown): _SliderStepIntent(-0.05),
        },
        actions: <Type, Action<Intent>>{
          _SliderStepIntent: CallbackAction<_SliderStepIntent>(
            onInvoke: (intent) {
              stepBy(intent.delta);
              return null;
            },
          ),
        },
        child: LayoutBuilder(
        builder: (context, constraints) {
          if (widget.orientation == Axis.vertical) {
            final height = constraints.maxHeight;
            void updateVertical(Offset localPosition) {
              if (!isEnabled || height <= 0) return;
              final next = (1.0 - (localPosition.dy / height)).clamp(0.0, 1.0);
              widget.onChanged!(_fromNormalized(next));
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: isEnabled
                  ? (d) {
                      setState(() => _active = true);
                      updateVertical(d.localPosition);
                    }
                  : null,
              onTapUp: isEnabled ? (_) => setState(() => _active = false) : null,
              onTapCancel:
                  isEnabled ? () => setState(() => _active = false) : null,
              onVerticalDragStart: isEnabled
                  ? (d) {
                      setState(() => _active = true);
                      updateVertical(d.localPosition);
                    }
                  : null,
              onVerticalDragUpdate:
                  isEnabled ? (d) => updateVertical(d.localPosition) : null,
              onVerticalDragEnd:
                  isEnabled ? (_) => setState(() => _active = false) : null,
              onVerticalDragCancel:
                  isEnabled ? () => setState(() => _active = false) : null,
              child: SizedBox(
                width: 30.0,
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: 6.0,
                      height: height,
                      decoration: BoxDecoration(
                        color: troughColor,
                        borderRadius: BorderRadius.circular(99.0),
                      ),
                    ),
                    FractionallySizedBox(
                      heightFactor: clampedValue,
                      child: Container(
                        width: 6.0,
                        decoration: BoxDecoration(
                          color: highlightColor,
                          borderRadius: BorderRadius.circular(99.0),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: (height - 18.0) * clampedValue,
                      child: _SliderThumb(
                        color: thumbColor,
                        focusRingColor: _focused
                            ? (widget.isOsd
                                ? theme.colors.osdFocusBorderColor
                                : theme.colors.focusBorderColor)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final width = constraints.maxWidth;
          void updateHorizontal(Offset localPosition) {
            if (!isEnabled || width <= 0) return;
            widget.onChanged!(
              _fromNormalized((localPosition.dx / width).clamp(0.0, 1.0)),
            );
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: isEnabled
                ? (d) {
                    setState(() => _active = true);
                    updateHorizontal(d.localPosition);
                  }
                : null,
            onTapUp: isEnabled ? (_) => setState(() => _active = false) : null,
            onTapCancel:
                isEnabled ? () => setState(() => _active = false) : null,
            onHorizontalDragStart: isEnabled
                ? (d) {
                    setState(() => _active = true);
                    updateHorizontal(d.localPosition);
                  }
                : null,
            onHorizontalDragUpdate:
                isEnabled ? (d) => updateHorizontal(d.localPosition) : null,
            onHorizontalDragEnd:
                isEnabled ? (_) => setState(() => _active = false) : null,
            onHorizontalDragCancel:
                isEnabled ? () => setState(() => _active = false) : null,
            child: SizedBox(
              height: 30.0,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 6.0,
                    decoration: BoxDecoration(
                      color: troughColor,
                      borderRadius: BorderRadius.circular(99.0),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: clampedValue,
                    child: Container(
                      height: 6.0,
                      decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(99.0),
                      ),
                    ),
                  ),
                  if (widget.marks != null)
                    for (final mark in widget.marks!)
                      Positioned(
                        left: (width - 2.0) * _toNormalized(mark),
                        bottom: 0,
                        child: Container(
                          width: 2.0,
                          height: 5.0,
                          decoration: BoxDecoration(
                            color: troughColor,
                            borderRadius: BorderRadius.circular(1.0),
                          ),
                        ),
                      ),
                  Positioned(
                    left: (width - 18.0) * clampedValue,
                    child: _SliderThumb(
                      color: thumbColor,
                      focusRingColor: _focused
                          ? (widget.isOsd
                              ? theme.colors.osdFocusBorderColor
                              : theme.colors.focusBorderColor)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}

class _SliderStepIntent extends Intent {
  final double delta;
  const _SliderStepIntent(this.delta);
}

class _SliderThumb extends StatelessWidget {
  final Color color;
  final Color? focusRingColor;

  const _SliderThumb({
    required this.color,
    this.focusRingColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (focusRingColor != null)
          Positioned(
            left: -4.0,
            right: -4.0,
            top: -4.0,
            bottom: -4.0,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: focusRingColor!,
                    width: 2.0,
                  ),
                ),
              ),
            ),
          ),
        Container(
          width: 18.0,
          height: 18.0,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: AdwTheme.of(context).colors.sliderThumbShadows,
          ),
        ),
      ],
    );
  }
}
