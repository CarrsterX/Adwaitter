import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/adw_text_selection.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../containers/adw_preferences_group.dart';
import 'adw_button.dart';

/// Preference row containing an editable text field (`AdwEntryRow`).
///
/// Follows GNOME Libadwaita specifications:
/// * Floating [title] that sits centered when empty/unfocused and rises when
///   focused or filled.
/// * Pure Dart text entry built directly on [EditableText].
/// * Optional edit indicator icon ([showEditIcon]), quick clear button
///   ([showClearButton]), and apply confirmation button ([showApplyButton]).
/// * Optional [prefix] and [suffix] slot widgets.
///
/// ```dart
/// AdwEntryRow(
///   title: const Text('Server Address'),
///   showApplyButton: true,
///   onApply: (value) {},
/// )
/// ```
///
/// See also:
///
/// * [AdwPasswordEntryRow], for masked password inputs with a reveal toggle.
/// * [AdwEntry], for standalone text fields outside preference groups.
///
/// {@category Controls}
class AdwEntryRow extends StatefulWidget {
  /// Floating label widget describing the field.
  final Widget? title;

  /// Optional external controller for reading or modifying the text value.
  final TextEditingController? controller;

  /// Initial text value when [controller] is not provided.
  final String? initialValue;

  /// Optional placeholder hint shown when the field is focused and empty.
  final String? placeholder;

  /// Whether to obscure the entered characters. Defaults to `false`.
  final bool obscureText;

  /// Whether to show a trailing clear button when text is non-empty.
  /// Defaults to `false`.
  final bool showClearButton;

  /// Whether to show an apply confirmation button when edits are pending.
  /// Defaults to `false`.
  final bool showApplyButton;

  /// Whether to show the subtle trailing edit pencil icon. Defaults to `true`.
  final bool showEditIcon;

  /// Optional custom widget replacing the default edit pencil icon.
  final Widget? editIcon;

  /// Called whenever the entered text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the text via keyboard.
  final ValueChanged<String>? onSubmitted;

  /// Called when the user taps the apply button (when [showApplyButton] is `true`).
  final ValueChanged<String>? onApply;

  /// Optional leading widget placed before the text field.
  final Widget? prefix;

  /// Optional trailing widget placed after the text field.
  final Widget? suffix;

  /// Optional soft keyboard type.
  final TextInputType? keyboardType;

  /// Optional input formatters applied to user edits.
  final List<TextInputFormatter>? inputFormatters;

  /// Creates a Libadwaita editable text preference row.
  const AdwEntryRow({
    super.key,
    this.title,
    this.controller,
    this.initialValue,
    this.placeholder,
    this.obscureText = false,
    this.showClearButton = false,
    this.showApplyButton = false,
    this.showEditIcon = true,
    this.editIcon,
    this.onChanged,
    this.onSubmitted,
    this.onApply,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  State<AdwEntryRow> createState() => _AdwEntryRowState();
}

class _AdwEntryRowState extends State<AdwEntryRow>
    with TickerProviderStateMixin {
  late final TextEditingController _controller;
  late final AnimationController _labelController;
  late final Animation<double> _labelAnimation;
  late final AnimationController _cursorController;
  late final Animation<double> _cursorOpacity;
  final GlobalKey<EditableTextState> _editableKey =
      GlobalKey<EditableTextState>();
  final FocusNode _focusNode = FocusNode();
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _shouldFloat =>
      widget.title == null || _isFocused || _controller.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
    _labelController = AnimationController(
      vsync: this,
      duration: AdwCurves.resolveGlobal(AdwCurves.normalDuration),
      value: _shouldFloat ? 1.0 : 0.0,
    );
    _labelAnimation = CurvedAnimation(
      parent: _labelController,
      curve: Curves.fastOutSlowIn,
    );
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _cursorOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 30),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 28,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 14),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 28,
      ),
    ]).animate(_cursorController);
    _controller.addListener(_handleTextChange);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _cursorController.dispose();
    _labelController.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_handleTextChange);
    }
    super.dispose();
  }

  void _syncLabelAnimation() {
    final duration = AdwCurves.resolve(context, AdwCurves.normalDuration);
    _labelController.duration = duration;
    if (_shouldFloat) {
      if (duration == Duration.zero) {
        _labelController.value = 1.0;
      } else {
        _labelController.forward();
      }
    } else {
      if (duration == Duration.zero) {
        _labelController.value = 0.0;
      } else {
        _labelController.reverse();
      }
    }
  }

  void _handleTextChange() {
    setState(() {});
    _syncLabelAnimation();
    if (_isFocused) {
      _cursorController.value = 0.0;
      _cursorController.repeat();
    }
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    _syncLabelAnimation();
    if (_focusNode.hasFocus) {
      _cursorController.value = 0.0;
      _cursorController.repeat();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus) {
          _editableKey.currentState?.requestKeyboard();
        }
      });
    } else {
      _cursorController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final hasText = _controller.text.isNotEmpty;
    final hasTitle = widget.title != null;
    final isFloating = !hasTitle || _isFocused || hasText;

    return AdwInputBounds(
      child: TextFieldTapRegion(
      onTapOutside: (_) {
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      },
      child: MouseRegion(
        cursor: hasTitle ? SystemMouseCursors.text : MouseCursor.defer,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focusNode.requestFocus();
            _editableKey.currentState?.requestKeyboard();
          },
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: hasTitle ? AdwMetrics.rowMinHeight : 0.0,
          ),
          child: AnimatedContainer(
            duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
            curve: AdwCurves.standard,
            decoration: BoxDecoration(
              color: _isFocused
                  ? theme.colors.cardBackground
                  : (_isHovered
                      ? theme.colors.hoverColor
                      : const Color(0x00000000)),
              borderRadius:
                  hasTitle ? AdwGroupRowShape.borderRadiusOf(context) : null,
            ),
            foregroundDecoration: hasTitle
                ? BoxDecoration(
                    borderRadius: AdwGroupRowShape.borderRadiusOf(context),
                    border: _isFocused
                        ? Border.all(
                            color: theme.colors.accentColor
                                .withValues(alpha: 0.75),
                            width: 2.0,
                          )
                        : null,
                  )
                : null,
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: hasTitle ? 8 : 4,
            ),
            child: Row(
              children: [
                if (widget.prefix != null) ...[
                  widget.prefix!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: hasTitle
                      ? SizedBox(
                          height: 38,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _labelAnimation,
                                    builder: (context, child) {
                                      final t = _labelAnimation.value;
                                      final scale =
                                          1.0 - (1.0 - 11.0 / 14.0) * t;
                                      return Align(
                                        alignment: Alignment.lerp(
                                          Alignment.centerLeft,
                                          Alignment.topLeft,
                                          t,
                                        )!,
                                        child: Transform.scale(
                                          scale: scale,
                                          alignment: Alignment.topLeft,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: DefaultTextStyle(
                                      style: theme.typography.body.copyWith(
                                        fontSize: 14.0,
                                        color: theme.colors.secondaryForeground,
                                      ),
                                      child: widget.title!,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _AdwPureEditableText(
                                  editableKey: _editableKey,
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  obscureText: widget.obscureText,
                                  placeholder:
                                      isFloating ? widget.placeholder : null,
                                  keyboardType: widget.keyboardType,
                                  inputFormatters: widget.inputFormatters,
                                  style: theme.typography.body.copyWith(
                                    fontSize: 14.0,
                                    color: theme.colors.foreground,
                                  ),
                                  placeholderStyle:
                                      theme.typography.body.copyWith(
                                    fontSize: 14.0,
                                    color: theme.colors.secondaryForeground
                                        .withValues(alpha: 0.5),
                                  ),
                                  cursorColor: theme.colors.windowForeground,
                                  cursorOpacity: _cursorOpacity,
                                  selectionColor: theme.colors.accentColor,
                                  onChanged: widget.onChanged,
                                  onSubmitted: (val) {
                                    widget.onSubmitted?.call(val);
                                    if (widget.showApplyButton) {
                                      widget.onApply?.call(val);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        )
                      : _AdwPureEditableText(
                          editableKey: _editableKey,
                          controller: _controller,
                          focusNode: _focusNode,
                          obscureText: widget.obscureText,
                          placeholder: widget.placeholder,
                          keyboardType: widget.keyboardType,
                          inputFormatters: widget.inputFormatters,
                          style: theme.typography.body.copyWith(
                            fontSize: 14.0,
                            color: theme.colors.foreground,
                          ),
                          placeholderStyle: theme.typography.body.copyWith(
                            fontSize: 14.0,
                            color: theme.colors.secondaryForeground
                                .withValues(alpha: 0.5),
                          ),
                          cursorColor: theme.colors.windowForeground,
                          cursorOpacity: _cursorOpacity,
                          selectionColor: theme.colors.accentColor,
                          onChanged: widget.onChanged,
                          onSubmitted: (val) {
                            widget.onSubmitted?.call(val);
                            if (widget.showApplyButton) {
                              widget.onApply?.call(val);
                            }
                          },
                        ),
                ),
                if (widget.showClearButton && hasText) ...[
                  const SizedBox(width: 6),
                  _ClearButton(
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged?.call('');
                    },
                  ),
                ],
                if (widget.showApplyButton && hasText) ...[
                  const SizedBox(width: 6),
                  AdwButton.suggested(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    onPressed: () => widget.onApply?.call(_controller.text),
                    child: const Text('Apply'),
                  ),
                ] else if (hasTitle && widget.showEditIcon && !_isFocused) ...[
                  const SizedBox(width: 8),
                  IconTheme(
                    data: IconThemeData(
                      color: theme.colors.windowForeground,
                      size: 16,
                    ),
                    child: widget.editIcon ??
                        CustomPaint(
                          size: const Size(15, 15),
                          painter: _EditPencilPainter(
                            color: theme.colors.windowForeground,
                          ),
                        ),
                  ),
                ],
                if (widget.suffix != null) ...[
                  const SizedBox(width: 8),
                  widget.suffix!,
                ],
              ],
            ),
          ),
        ),
      ),
    ),
    ),
    );
  }
}

/// Password entry row with integrated visibility toggle (`AdwPasswordEntryRow`).
///
/// Wraps [AdwEntryRow] with masked text by default and a trailing reveal/conceal
/// eye button.
///
/// ```dart
/// AdwPasswordEntryRow(
///   title: const Text('Password'),
///   onChanged: (value) {},
/// )
/// ```
///
/// See also:
///
/// * [AdwEntryRow], for standard unmasked text entry rows.
///
/// {@category Controls}
class AdwPasswordEntryRow extends StatefulWidget {
  /// Floating label widget describing the password field.
  final Widget? title;

  /// Optional external controller for reading or modifying the password text.
  final TextEditingController? controller;

  /// Optional placeholder hint shown when focused and empty.
  final String? placeholder;

  /// Called whenever the entered password changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the password via keyboard.
  final ValueChanged<String>? onSubmitted;

  /// Optional leading widget placed before the input.
  final Widget? prefix;

  /// Optional custom edit indicator widget.
  final Widget? editIcon;

  /// Optional custom icon shown when the password is hidden (tap to reveal).
  final Widget? revealIcon;

  /// Optional custom icon shown when the password is visible (tap to conceal).
  final Widget? concealIcon;

  /// Creates a Libadwaita password entry preference row.
  const AdwPasswordEntryRow({
    super.key,
    this.title,
    this.controller,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.editIcon,
    this.revealIcon,
    this.concealIcon,
  });

  @override
  State<AdwPasswordEntryRow> createState() => _AdwPasswordEntryRowState();
}

class _AdwPasswordEntryRowState extends State<AdwPasswordEntryRow> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final customVisibilityIcon =
        _obscureText ? widget.revealIcon : widget.concealIcon;

    return AdwEntryRow(
      title: widget.title,
      controller: widget.controller,
      placeholder: widget.placeholder,
      obscureText: _obscureText,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      prefix: widget.prefix,
      editIcon: widget.editIcon,
      suffix: AdwButton.flat(
        padding: const EdgeInsets.all(6),
        onPressed: () => setState(() => _obscureText = !_obscureText),
        child: customVisibilityIcon != null
            ? IconTheme(
                data: IconThemeData(
                  color: theme.colors.windowForeground,
                  size: 16,
                ),
                child: customVisibilityIcon,
              )
            : CustomPaint(
                size: const Size(16, 16),
                painter: _EyeIconPainter(
                  color: theme.colors.windowForeground,
                  obscured: _obscureText,
                ),
              ),
      ),
    );
  }
}

class _ClearButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _ClearButton({required this.onPressed});

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isHovered
                ? theme.colors.secondaryForeground.withValues(alpha: 0.3)
                : theme.colors.secondaryForeground.withValues(alpha: 0.15),
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(8, 8),
              painter: _EntryClearIconPainter(
                color: theme.colors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryClearIconPainter extends CustomPainter {
  final Color color;

  const _EntryClearIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      const Offset(0.5, 0.5),
      Offset(size.width - 0.5, size.height - 0.5),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 0.5, 0.5),
      Offset(0.5, size.height - 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _EntryClearIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _AdwPureEditableText extends StatelessWidget {
  final GlobalKey<EditableTextState> editableKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscureText;
  final String? placeholder;
  final TextStyle style;
  final TextStyle placeholderStyle;
  final Color cursorColor;
  final Animation<double> cursorOpacity;
  final Color selectionColor;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _AdwPureEditableText({
    required this.editableKey,
    required this.controller,
    required this.focusNode,
    required this.obscureText,
    this.placeholder,
    required this.style,
    required this.placeholderStyle,
    required this.cursorColor,
    required this.cursorOpacity,
    required this.selectionColor,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        if (placeholder != null && controller.text.isEmpty)
          Text(placeholder!, style: placeholderStyle),
        AdwEditableText(
          editableTextKey: editableKey,
          controller: controller,
          focusNode: focusNode,
          style: style,
          cursorColor: const Color(0x00000000),
          backgroundCursorColor: const Color(0x00000000),
          cursorWidth: 1.0,
          cursorOpacityAnimates: false,
          showCursor: false,
          onTapOutside: (_) => focusNode.unfocus(),
          obscureText: obscureText,
          keyboardType: keyboardType ?? TextInputType.text,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          selectionColor: selectionColor.withValues(alpha: 0.3),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CaretPainter(
                editableKey: editableKey,
                controller: controller,
                focusNode: focusNode,
                cursorColor: cursorColor,
                cursorOpacity: cursorOpacity,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CaretPainter extends CustomPainter {
  final GlobalKey<EditableTextState> editableKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color cursorColor;
  final Animation<double> cursorOpacity;

  _CaretPainter({
    required this.editableKey,
    required this.controller,
    required this.focusNode,
    required this.cursorColor,
    required this.cursorOpacity,
  }) : super(repaint: cursorOpacity);

  @override
  void paint(Canvas canvas, Size size) {
    if (!focusNode.hasFocus) return;
    final double opacity = cursorOpacity.value.clamp(0.0, 1.0).toDouble();
    if (opacity <= 0.001) return;

    final renderEditable = editableKey.currentState?.renderEditable;
    if (renderEditable == null || !renderEditable.attached) return;

    final rawOffset = controller.selection.isValid
        ? controller.selection.extentOffset
        : controller.text.length;
    final int safeOffset = rawOffset.clamp(0, controller.text.length).toInt();
    final caretRect = renderEditable.getLocalRectForCaret(
      TextPosition(
        offset: safeOffset,
        affinity: controller.selection.affinity,
      ),
    );

    final double x =
        caretRect.left.clamp(0.0, math.max(0.0, size.width - 1.0)).toDouble();
    final height = caretRect.height > 0 ? caretRect.height : size.height;
    final paint = Paint()
      ..color = cursorColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(x, caretRect.top, 1.0, height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CaretPainter oldDelegate) {
    return editableKey != oldDelegate.editableKey ||
        controller != oldDelegate.controller ||
        focusNode != oldDelegate.focusNode ||
        cursorColor != oldDelegate.cursorColor ||
        cursorOpacity != oldDelegate.cursorOpacity;
  }
}

class _EditPencilPainter extends CustomPainter {
  final Color color;

  const _EditPencilPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.84)
      ..lineTo(size.width * 0.22, size.height * 0.62)
      ..lineTo(size.width * 0.72, size.height * 0.12)
      ..lineTo(size.width * 0.88, size.height * 0.28)
      ..lineTo(size.width * 0.38, size.height * 0.78)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(size.width * 0.60, size.height * 0.24),
      Offset(size.width * 0.76, size.height * 0.40),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _EditPencilPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

class _EyeIconPainter extends CustomPainter {
  final Color color;
  final bool obscured;

  const _EyeIconPainter({
    required this.color,
    required this.obscured,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final eyePath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.14,
        size.width * 0.9,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.86,
        size.width * 0.1,
        size.height * 0.5,
      );

    canvas.drawPath(eyePath, paint);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.13,
      paint,
    );

    if (!obscured) {
      canvas.drawLine(
        Offset(size.width * 0.18, size.height * 0.82),
        Offset(size.width * 0.82, size.height * 0.18),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EyeIconPainter oldDelegate) {
    return color != oldDelegate.color || obscured != oldDelegate.obscured;
  }
}
