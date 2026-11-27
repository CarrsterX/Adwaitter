import 'package:flutter/widgets.dart';

import '../../core/adw_text_selection.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';

/// Semantic style variants for [AdwEntry], matching GTK4/Libadwaita
/// `.success`, `.warning`, and `.error` entry style classes.
///
/// {@category Controls}
enum AdwEntryStyle {
  /// Default neutral text entry appearance.
  standard,

  /// Positive validation state tinted with [AdwColorScheme.standaloneSuccessColor].
  success,

  /// Caution validation state tinted with [AdwColorScheme.standaloneWarningColor].
  warning,

  /// Error validation state tinted with [AdwColorScheme.standaloneErrorColor].
  error,
}

/// Standalone Libadwaita text entry (`GtkEntry` / `AdwEntry`).
///
/// Supports placeholder text, optional [prefix]/[suffix] widgets, semantic
/// style classes ([AdwEntryStyle]), and custom [borderRadius] for `.linked`
/// control groups.
///
/// ```dart
/// AdwEntry(
///   placeholder: 'Enter username…',
///   onChanged: (value) {},
/// )
/// ```
///
/// See also:
///
/// * [AdwEntryRow], for text input rows inside an [AdwPreferencesGroup].
/// * [AdwSearchBar], for collapsible search headers.
///
/// {@category Controls}
class AdwEntry extends StatefulWidget {
  /// Optional controller for reading or mutating the text value.
  final TextEditingController? controller;

  /// Optional focus node managing keyboard focus for this entry.
  final FocusNode? focusNode;

  /// Hint text displayed when the entry is empty.
  final String? placeholder;

  /// Semantic validation style. Defaults to [AdwEntryStyle.standard].
  final AdwEntryStyle style;

  /// Optional leading widget inside the entry box (e.g. a search icon).
  final Widget? prefix;

  /// Optional trailing widget inside the entry box (e.g. a clear button).
  final Widget? suffix;

  /// Optional corner radius override (useful inside [AdwLinkedBox]).
  final BorderRadius? borderRadius;

  /// Height of the entry container in logical pixels. Defaults to `34.0`.
  final double height;

  /// Called whenever the user edits the text.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the text (e.g. pressing Enter).
  final ValueChanged<String>? onSubmitted;

  /// Whether to mask the entered text (e.g. for passwords). Defaults to `false`.
  final bool obscureText;

  /// Whether the text field is read-only. Defaults to `false`.
  final bool readOnly;

  /// Creates a standalone Libadwaita text entry.
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
    return switch (widget.style) {
      AdwEntryStyle.standard => null,
      AdwEntryStyle.success => theme.colors.standaloneSuccessColor,
      AdwEntryStyle.warning => theme.colors.standaloneWarningColor,
      AdwEntryStyle.error => theme.colors.standaloneErrorColor,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final semanticColor = _resolveSemanticColor(theme);
    final currentColor = semanticColor ?? theme.colors.windowForeground;
    final focusColor = semanticColor ?? theme.colors.accentColor;
    final bgColor = currentColor.withValues(alpha: 0.10);

    return AdwInputBounds(
      child: TextFieldTapRegion(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _focusNode.requestFocus(),
        child: AnimatedContainer(
        duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
        curve: AdwCurves.standard,
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 9.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: widget.borderRadius ??
              BorderRadius.circular(AdwMetrics.buttonRadius),
          border: _focused
              ? Border.all(
                  color: theme.colors.isHighContrast
                      ? theme.colors.focusBorderColor
                      : focusColor.withValues(alpha: 0.50),
                  width: 2.0,
                )
              : (theme.colors.isHighContrast
                  ? Border.all(
                      color: theme.colors.borderColor,
                      width: 1.0,
                    )
                  : null),
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
                  AdwEditableText(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: theme.typography.body.copyWith(color: currentColor),
                    cursorColor: currentColor,
                    backgroundCursorColor: theme.colors.windowBackground,
                    selectionColor:
                        theme.colors.accentColor.withValues(alpha: 0.3),
                    obscureText: widget.obscureText,
                    readOnly: widget.readOnly,
                    onTapOutside: (_) => _focusNode.unfocus(),
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
      ),
      ),
    );
  }
}
