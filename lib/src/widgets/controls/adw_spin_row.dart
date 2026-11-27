import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../containers/adw_preferences_group.dart';

/// Preference row with numeric increment/decrement spin control (`AdwSpinRow`).
///
/// Enables users to adjust numeric values within `[min, max]` using direct
/// keyboard entry or dedicated `[-]` and `[+]` stepper buttons.
///
/// ```dart
/// AdwSpinRow(
///   title: const Text('Font Size'),
///   value: 11,
///   min: 6,
///   max: 32,
///   step: 1,
///   onChanged: (value) {},
/// )
/// ```
///
/// See also:
///
/// * [AdwEntryRow], for free-form text input rows.
/// * [AdwSlider], for continuous range selection.
///
/// {@category Controls}
class AdwSpinRow extends StatefulWidget {
  /// Primary label widget for the row.
  final Widget title;

  /// Optional secondary description displayed below [title].
  final Widget? subtitle;

  /// Optional leading widget placed before [title].
  final Widget? prefix;

  /// Current numeric value clamped between [min] and [max].
  final double value;

  /// Lower bound of allowed values. Defaults to `0.0`.
  final double min;

  /// Upper bound of allowed values. Defaults to `100.0`.
  final double max;

  /// Amount added or subtracted when tapping `+` or `-`. Defaults to `1.0`.
  final double step;

  /// Number of fractional digits formatted in the numeric field. Defaults to `0`.
  final int decimalDigits;

  /// Called whenever the numeric value changes. When `null`, the row is disabled.
  final ValueChanged<double>? onChanged;

  /// Creates a Libadwaita numeric spin preference row.
  const AdwSpinRow({
    super.key,
    required this.title,
    this.subtitle,
    this.prefix,
    required this.value,
    this.min = 0.0,
    this.max = 100.0,
    this.step = 1.0,
    this.decimalDigits = 0,
    this.onChanged,
  });

  @override
  State<AdwSpinRow> createState() => _AdwSpinRowState();
}

class _AdwSpinRowState extends State<AdwSpinRow> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'AdwSpinRow');
  late final TextEditingController _textController;
  bool _isFocused = false;

  String _formatValue(double val) {
    return widget.decimalDigits == 0
        ? val.round().toString()
        : val.toStringAsFixed(widget.decimalDigits);
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _formatValue(widget.value));
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant AdwSpinRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.decimalDigits != widget.decimalDigits) {
      final formatted = _formatValue(widget.value);
      if (_textController.text != formatted) {
        _textController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
  }

  void _commitText() {
    final parsed = double.tryParse(_textController.text.trim());
    if (parsed != null) {
      final clamped = parsed.clamp(widget.min, widget.max).toDouble();
      final formatted = _formatValue(clamped);
      _textController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      if (clamped != widget.value) {
        widget.onChanged?.call(clamped);
      }
    } else {
      final formatted = _formatValue(widget.value);
      _textController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _onFocusChange() {
    if (!mounted) return;
    final hasFocus = _focusNode.hasFocus;
    if (!hasFocus && _isFocused) {
      _commitText();
    } else if (hasFocus && !_isFocused) {
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    }
    setState(() => _isFocused = hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _increment() {
    _focusNode.requestFocus();
    final next = (widget.value + widget.step).clamp(widget.min, widget.max);
    if (next != widget.value) {
      widget.onChanged?.call(next);
    }
  }

  void _decrement() {
    _focusNode.requestFocus();
    final next = (widget.value - widget.step).clamp(widget.min, widget.max);
    if (next != widget.value) {
      widget.onChanged?.call(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final isEnabled = widget.onChanged != null;
    final canDecrement = isEnabled && widget.value > widget.min;
    final canIncrement = isEnabled && widget.value < widget.max;
    final displayText = _formatValue(widget.value);
    final allowDecimal = widget.decimalDigits > 0;
    final allowNegative = widget.min < 0;
    final allowedPattern = switch ((allowNegative, allowDecimal)) {
      (true, true) => RegExp(r'[0-9.\-]'),
      (true, false) => RegExp(r'[0-9\-]'),
      (false, true) => RegExp(r'[0-9.]'),
      (false, false) => RegExp(r'[0-9]'),
    };

    final increasedDisplay = _formatValue(
      (widget.value + widget.step).clamp(widget.min, widget.max).toDouble(),
    );
    final decreasedDisplay = _formatValue(
      (widget.value - widget.step).clamp(widget.min, widget.max).toDouble(),
    );

    return Semantics(
      textField: true,
      enabled: isEnabled,
      value: displayText,
      increasedValue: canIncrement ? increasedDisplay : null,
      decreasedValue: canDecrement ? decreasedDisplay : null,
      onIncrease: canIncrement ? _increment : null,
      onDecrease: canDecrement ? _decrement : null,
      child: TapRegion(
        onTapOutside: (_) {
          if (_focusNode.hasFocus) _focusNode.unfocus();
        },
        child: CallbackShortcuts(
          bindings: isEnabled
              ? <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.arrowUp): _increment,
                  const SingleActivator(LogicalKeyboardKey.arrowDown):
                      _decrement,
                }
              : const <ShortcutActivator, VoidCallback>{},
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isEnabled ? () => _focusNode.requestFocus() : null,
            child: AnimatedContainer(
              duration: AdwCurves.resolve(context, AdwCurves.normalDuration),
              curve: AdwCurves.standard,
              constraints:
                  const BoxConstraints(minHeight: AdwMetrics.rowMinHeight),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              foregroundDecoration: BoxDecoration(
                borderRadius: AdwGroupRowShape.borderRadiusOf(context),
                border: Border.all(
                  color: _isFocused
                      ? theme.colors.spinRowFocusBorderColor
                      : theme.colors.spinRowFocusBorderColor
                          .withValues(alpha: 0.0),
                  width: 2.0,
                ),
              ),
              child: Row(
                children: [
                  if (widget.prefix != null) ...[
                    widget.prefix!,
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DefaultTextStyle(
                          style: theme.typography.body,
                          child: widget.title,
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          DefaultTextStyle(
                            style: theme.typography.caption.copyWith(
                              color: theme.colors.secondaryForeground,
                            ),
                            child: widget.subtitle!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IntrinsicWidth(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            maxWidth: 96,
                          ),
                          child: EditableText(
                            controller: _textController,
                            focusNode: _focusNode,
                            readOnly: !isEnabled,
                            textAlign: TextAlign.right,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: allowDecimal,
                              signed: allowNegative,
                            ),
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(allowedPattern),
                            ],
                            style: theme.typography.body.copyWith(
                              color: theme.colors.windowForeground,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                            cursorColor: theme.colors.accentColor,
                            backgroundCursorColor: theme.colors.borderColor,
                            selectionColor:
                                theme.colors.accentColor.withValues(alpha: 0.30),
                            onSubmitted: (_) => _commitText(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      _SpinButton(
                        isIncrement: false,
                        enabled: canDecrement,
                        onPressed: _decrement,
                      ),
                      const SizedBox(width: 10),
                      _SpinButton(
                        isIncrement: true,
                        enabled: canIncrement,
                        onPressed: _increment,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpinButton extends StatefulWidget {
  final bool isIncrement;
  final bool enabled;
  final VoidCallback onPressed;

  const _SpinButton({
    required this.isIncrement,
    required this.enabled,
    required this.onPressed,
  });

  @override
  State<_SpinButton> createState() => _SpinButtonState();
}

class _SpinButtonState extends State<_SpinButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final Color bgColor;
    if (!widget.enabled) {
      bgColor = theme.colors.buttonBackground.withValues(alpha: 0.45);
    } else if (_isPressed) {
      bgColor = theme.colors.activeColor;
    } else if (_isHovered) {
      bgColor = theme.colors.hoverBackground;
    } else {
      bgColor = theme.colors.buttonBackground;
    }

    final Color fgColor = widget.enabled
        ? theme.colors.windowForeground
        : theme.colors.secondaryForeground.withValues(alpha: 0.4);

    return MouseRegion(
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (widget.enabled) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (widget.enabled) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (widget.enabled) setState(() => _isPressed = false);
        },
        onTap: widget.enabled ? widget.onPressed : null,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: theme.colors.isHighContrast
                ? Border.all(color: theme.colors.borderColor, width: 1.0)
                : null,
          ),
          child: CustomPaint(
            painter: _SpinSymbolPainter(
              isIncrement: widget.isIncrement,
              color: fgColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpinSymbolPainter extends CustomPainter {
  final bool isIncrement;
  final Color color;

  const _SpinSymbolPainter({
    required this.isIncrement,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    const halfLen = 4.5;

    canvas.drawLine(
      Offset(cx - halfLen, cy),
      Offset(cx + halfLen, cy),
      paint,
    );
    if (isIncrement) {
      canvas.drawLine(
        Offset(cx, cy - halfLen),
        Offset(cx, cy + halfLen),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpinSymbolPainter oldDelegate) =>
      oldDelegate.isIncrement != isIncrement || oldDelegate.color != color;
}
