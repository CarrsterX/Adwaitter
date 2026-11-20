import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';

/// Semantic style variants for [AdwEntry], matching GTK4/Libadwaita
/// `.success`, `.warning`, and `.error` entry style classes.
enum AdwEntryStyle {
  standard,
  success,
  warning,
  error,
}

/// Standalone Libadwaita text entry (`GtkEntry` / `AdwEntry`).
///
/// Supports placeholder text, optional [prefix]/[suffix] widgets, semantic
/// style classes ([AdwEntryStyle]), and custom [borderRadius] for `.linked`
/// control groups.
class AdwEntry extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final AdwEntryStyle style;
  final Widget? prefix;
  final Widget? suffix;
  final BorderRadius? borderRadius;
  final double height;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final bool readOnly;

  const AdwEntry({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.style = AdwEntryStyle.standard,
    this.prefix,
    this.suffix,
    this.borderRadius,
    this.height = 34.0,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.readOnly = false,
  });

  @override
  State<AdwEntry> createState() => _AdwEntryState();
}

class _AdwEntryState extends State<AdwEntry> {
  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;
  bool _focused = false;

  TextEditingController get _controller =>
      widget.controller ?? (_internalController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
  }

  @override
  void didUpdateWidget(covariant AdwEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)
          ?.removeListener(_onFocusChange);
      _focusNode.addListener(_onFocusChange);
      _focused = _focusNode.hasFocus;
    }
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _internalController)
          ?.removeListener(_onTextChange);
      _controller.addListener(_onTextChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);
    _internalFocusNode?.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  void _onTextChange() {
    if (mounted) {
      setState(() {});
    }
  }

  Color? _resolveSemanticColor(AdwThemeData theme) {
    final isDark = theme.colors.isDark;
    return switch (widget.style) {
      AdwEntryStyle.standard => null,
      AdwEntryStyle.success =>
        isDark ? const Color(0xFF78EABE) : const Color(0xFF1B8553),
      AdwEntryStyle.warning =>
        isDark ? const Color(0xFFF8E45C) : const Color(0xFF9C6E03),
      AdwEntryStyle.error =>
        isDark ? const Color(0xFFFF7B63) : const Color(0xFFC01C28),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final semanticColor = _resolveSemanticColor(theme);
    final currentColor = semanticColor ?? theme.colors.windowForeground;
    final focusColor = semanticColor ?? theme.colors.accentColor;
    final bgColor = currentColor.withValues(alpha: 0.10);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focusNode.requestFocus(),
      child: AnimatedContainer(
        duration: AdwCurves.shortDuration,
        curve: AdwCurves.standard,
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 9.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: widget.borderRadius ??
              BorderRadius.circular(AdwMetrics.buttonRadius),
          border: _focused
              ? Border.all(
                  color: focusColor.withValues(alpha: 0.50),
                  width: 2.0,
                )
              : null,
        ),
        child: Row(
          children: [
            if (widget.prefix != null) ...[
              IconTheme(
                data: IconThemeData(
                  color: currentColor.withValues(alpha: 0.70),
                  size: 16.0,
                ),
                child: widget.prefix!,
              ),
              const SizedBox(width: 6.0),
            ],
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  if (widget.placeholder != null && _controller.text.isEmpty)
                    Text(
                      widget.placeholder!,
                      style: theme.typography.body.copyWith(
                        color: currentColor.withValues(alpha: 0.55),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  EditableText(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: theme.typography.body.copyWith(color: currentColor),
                    cursorColor: currentColor,
                    backgroundCursorColor: theme.colors.windowBackground,
                    obscureText: widget.obscureText,
                    readOnly: widget.readOnly,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                  ),
                ],
              ),
            ),
            if (widget.suffix != null) ...[
              const SizedBox(width: 6.0),
              IconTheme(
                data: IconThemeData(
                  color: currentColor.withValues(alpha: 0.70),
                  size: 16.0,
                ),
                child: widget.suffix!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
