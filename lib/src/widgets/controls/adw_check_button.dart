import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_theme.dart';

/// Native Libadwaita / GTK4 radio indicator (`AdwRadio`).
///
/// Renders an 18px circular radio button matching GNOME HIG:
/// - Selected: solid accent fill with a crisp white center dot.
/// - Unselected: transparent fill with a subtle 1.5px border.
class AdwRadio<T> extends StatefulWidget {
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final double size;

  const AdwRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.size = 18.0,
  });

  bool get _isSelected => value == groupValue;

  @override
  State<AdwRadio<T>> createState() => _AdwRadioState<T>();
}

class _AdwRadioState<T> extends State<AdwRadio<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final isEnabled = widget.onChanged != null;
    final isSelected = widget._isSelected;

    final Color unselectedBorder = theme.colors.windowForeground.withValues(
      alpha: _isHovered && isEnabled ? 0.45 : 0.25,
    );
    final Color fillColor = isSelected
        ? (isEnabled
            ? theme.colors.accentColor
            : theme.colors.accentColor.withValues(alpha: 0.45))
        : (_isHovered && isEnabled
            ? theme.colors.windowForeground.withValues(alpha: 0.06)
            : const Color(0x00000000));

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isEnabled ? () => widget.onChanged!(widget.value) : null,
        child: AnimatedContainer(
          duration: AdwCurves.shortDuration,
          curve: AdwCurves.standard,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fillColor,
            border: isSelected
                ? null
                : Border.all(
                    color: unselectedBorder,
                    width: 1.5,
                  ),
          ),
          child: isSelected
              ? Center(
                  child: Container(
                    width: widget.size * 0.35,
                    height: widget.size * 0.35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colors.accentForeground,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Native Libadwaita / GTK4 checkbox indicator (`AdwCheckbox`).
///
/// Renders an 18px rounded-square check button for multi-item selection:
/// - Checked: solid accent fill with a crisp white checkmark.
/// - Unchecked: transparent fill with a subtle 1.5px border.
class AdwCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double? size;
  final bool selectionMode;

  const AdwCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size,
    this.selectionMode = false,
  });

  @override
  State<AdwCheckbox> createState() => _AdwCheckboxState();
}

class _AdwCheckboxState extends State<AdwCheckbox> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final isEnabled = widget.onChanged != null;
    final isChecked = widget.value;
    final effectiveSize = widget.size ?? (widget.selectionMode ? 28.0 : 18.0);

    final Color unselectedBorder = theme.colors.windowForeground.withValues(
      alpha: widget.selectionMode
          ? (_isHovered && isEnabled ? 0.20 : 0.15)
          : (_isHovered && isEnabled ? 0.45 : 0.25),
    );
    final Color fillColor = isChecked
        ? (isEnabled
            ? (_isHovered && widget.selectionMode
                ? Color.alphaBlend(
                    theme.colors.accentForeground.withValues(alpha: 0.10),
                    theme.colors.accentColor,
                  )
                : theme.colors.accentColor)
            : theme.colors.accentColor.withValues(alpha: 0.45))
        : (_isHovered && isEnabled
            ? theme.colors.windowForeground.withValues(alpha: 0.06)
            : const Color(0x00000000));

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isEnabled ? () => widget.onChanged!(!isChecked) : null,
        child: AnimatedContainer(
          duration: AdwCurves.shortDuration,
          curve: AdwCurves.standard,
          width: effectiveSize,
          height: effectiveSize,
          decoration: BoxDecoration(
            shape: widget.selectionMode ? BoxShape.circle : BoxShape.rectangle,
            borderRadius:
                widget.selectionMode ? null : BorderRadius.circular(5.0),
            color: fillColor,
            border: isChecked
                ? null
                : Border.all(
                    color: unselectedBorder,
                    width: widget.selectionMode ? 2.0 : 1.5,
                  ),
          ),
          child: widget.selectionMode
              ? AnimatedScale(
                  scale: isChecked ? 1.0 : 0.6,
                  duration: AdwCurves.shortDuration,
                  curve: AdwCurves.standard,
                  child: AnimatedOpacity(
                    opacity: isChecked ? 1.0 : 0.0,
                    duration: AdwCurves.shortDuration,
                    curve: AdwCurves.standard,
                    child: CustomPaint(
                      painter: _CheckmarkPainter(
                        color: theme.colors.accentForeground,
                      ),
                    ),
                  ),
                )
              : (isChecked
                  ? CustomPaint(
                      painter: _CheckmarkPainter(
                        color: theme.colors.accentForeground,
                      ),
                    )
                  : null),
        ),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final Color color;

  const _CheckmarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.24, size.height * 0.52)
      ..lineTo(size.width * 0.43, size.height * 0.70)
      ..lineTo(size.width * 0.76, size.height * 0.32);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

