import 'package:flutter/widgets.dart';

import '../../theme/adw_theme.dart';

/// Libadwaita scale/slider control (`GtkScale` / `AdwSlider`).
///
/// Supports both horizontal and vertical orientations as well as the `.osd`
/// style class via [isOsd].
class AdwSlider extends StatefulWidget {
  final double value;
  final Axis orientation;
  final ValueChanged<double>? onChanged;
  final bool isOsd;

  const AdwSlider({
    super.key,
    required this.value,
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

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final isEnabled = widget.onChanged != null;
    final isLit = (_hovered || _active) && isEnabled;

    final Color troughColor;
    final Color highlightColor;
    final Color thumbColor;

    if (widget.isOsd) {
      troughColor = isLit ? const Color(0x33FFFFFF) : const Color(0x26FFFFFF);
      highlightColor =
          isLit ? const Color(0xD9FFFFFF) : const Color(0xBFFFFFFF);
      thumbColor = isLit ? const Color(0xFFFFFFFF) : const Color(0xFFD2D2D3);
    } else {
      final fg = theme.colors.windowForeground;
      troughColor = fg.withValues(alpha: isLit ? 0.20 : 0.15);
      highlightColor = isLit
          ? Color.lerp(theme.colors.accentColor, const Color(0xFFFFFFFF), 0.10)!
          : theme.colors.accentColor;
      thumbColor = const Color(0xFFFFFFFF);
    }

    final clampedValue = widget.value.clamp(0.0, 1.0);

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (widget.orientation == Axis.vertical) {
            final height = constraints.maxHeight;
            void updateVertical(Offset localPosition) {
              if (!isEnabled || height <= 0) return;
              final next = (1.0 - (localPosition.dy / height)).clamp(0.0, 1.0);
              widget.onChanged!(next);
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
                      child: _SliderThumb(color: thumbColor),
                    ),
                  ],
                ),
              ),
            );
          }

          final width = constraints.maxWidth;
          void updateHorizontal(Offset localPosition) {
            if (!isEnabled || width <= 0) return;
            widget.onChanged!((localPosition.dx / width).clamp(0.0, 1.0));
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
                  Positioned(
                    left: (width - 18.0) * clampedValue,
                    child: _SliderThumb(color: thumbColor),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliderThumb extends StatelessWidget {
  final Color color;

  const _SliderThumb({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18.0,
      height: 18.0,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000006),
            blurRadius: 0.0,
            spreadRadius: 1.0,
          ),
          BoxShadow(
            color: Color(0x33000006),
            blurRadius: 4.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
