import 'package:flutter/widgets.dart';

import '../../core/adw_text_selection.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import 'adw_preferences_group.dart';

/// Standard Libadwaita action row (`AdwActionRow`).
///
/// Designed to be used inside an [AdwPreferencesGroup] or standalone.
/// Accepts either [prefix] / [leading] on the left and [suffix] / [trailing]
/// on the right. Use [AdwActionRow.property] for the `.property` style where
/// [title] is rendered as a muted caption above a prominent [subtitle] value.
///
/// ```dart
/// AdwActionRow(
///   title: const Text('Appearance'),
///   subtitle: const Text('Configure light or dark mode'),
///   onPressed: () {},
/// )
/// ```
///
/// See also:
///
/// * [AdwPreferencesGroup], which groups action rows into boxed lists.
/// * [AdwExpanderRow], for collapsible rows with nested children.
/// * [AdwSwitchRow], [AdwComboRow], [AdwEntryRow], and [AdwSpinRow], for
///   specialized preference rows.
///
/// {@category Containers}
class AdwActionRow extends StatefulWidget {
  /// Alias for [prefix] placed at the start of the row.
  final Widget? leading;

  /// Optional widget placed before [title] (e.g. a symbolic icon or avatar).
  final Widget? prefix;

  /// Primary label widget for the row.
  final Widget title;

  /// Optional secondary description displayed below [title].
  final Widget? subtitle;

  /// Alias for [suffix] placed at the end of the row.
  final Widget? trailing;

  /// Optional widget placed at the end of the row (e.g. a button or chevron).
  final Widget? suffix;

  /// Callback invoked when the row is activated.
  final VoidCallback? onPressed;

  /// Internal padding around the row's content.
  final EdgeInsetsGeometry padding;

  /// Minimum height of the row. Defaults to [AdwMetrics.rowMinHeight].
  final double minHeight;

  /// Whether the row responds to hover/press interaction when [onPressed] is
  /// provided. Defaults to `true`.
  final bool isActivatable;

  /// Whether to render using Libadwaita's `.property` style (muted caption
  /// [title] above a selectable [subtitle] value). Defaults to `false`.
  final bool isProperty;

  /// Creates a standard Libadwaita action row.
  const AdwActionRow({
    super.key,
    this.leading,
    this.prefix,
    required this.title,
    this.subtitle,
    this.trailing,
    this.suffix,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.minHeight = AdwMetrics.rowMinHeight,
    this.isActivatable = true,
    this.isProperty = false,
  });

  /// Property row variant (`.property` in Libadwaita) where [title] is rendered
  /// as a muted caption label above a prominent [subtitle] value.
  const AdwActionRow.property({
    super.key,
    this.leading,
    this.prefix,
    required this.title,
    this.subtitle,
    this.trailing,
    this.suffix,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.minHeight = AdwMetrics.rowMinHeight,
    this.isActivatable = true,
  }) : isProperty = true;

  /// Resolves the start slot widget, preferring [prefix] over [leading].
  Widget? get effectivePrefix => prefix ?? leading;

  /// Resolves the end slot widget, preferring [suffix] over [trailing].
  Widget? get effectiveSuffix => suffix ?? trailing;

  @override
  State<AdwActionRow> createState() => _AdwActionRowState();
}

class _AdwActionRowState extends State<AdwActionRow> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;
  final FocusNode _rowFocusNode = FocusNode(debugLabel: 'AdwActionRow');
  FocusNode? _propertySelectionFocusNode;

  FocusNode _getPropertySelectionFocusNode() {
    return _propertySelectionFocusNode ??= FocusNode(
      debugLabel: 'AdwActionRow.propertySelection',
    );
  }

  @override
  void dispose() {
    _rowFocusNode.dispose();
    _propertySelectionFocusNode?.dispose();
    super.dispose();
  }

  bool get _isClickable => widget.onPressed != null && widget.isActivatable;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final prefixWidget = widget.effectivePrefix;
    final suffixWidget = widget.effectiveSuffix;

    Color rowColor = const Color(0x00000000);
    if (_isClickable) {
      if (_isPressed) {
        rowColor = theme.colors.activeColor;
      } else if (_isHovered || _isFocused) {
        rowColor = theme.colors.hoverColor;
      }
    }

    Widget content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: widget.minHeight),
      child: Padding(
        padding: widget.padding,
        child: Row(
          children: [
            if (prefixWidget != null) ...[
              IconTheme(
                data: IconThemeData(
                  color: theme.colors.windowForeground,
                  size: AdwMetrics.iconSizeSmall,
                ),
                child: prefixWidget,
              ),
              const SizedBox(width: AdwMetrics.spacingMedium),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: (widget.isProperty
                            ? theme.typography.subtitle
                            : theme.typography.body)
                        .copyWith(height: 1.2),
                    child: widget.title,
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    if (widget.isProperty)
                      AdwSelectableRegion(
                        focusNode: _getPropertySelectionFocusNode(),
                        child: DefaultTextStyle(
                          style: theme.typography.body.copyWith(height: 1.2),
                          child: widget.subtitle!,
                        ),
                      )
                    else
                      DefaultTextStyle(
                        style: theme.typography.subtitle.copyWith(height: 1.2),
                        child: widget.subtitle!,
                      ),
                  ],
                ],
              ),
            ),
            if (suffixWidget != null) ...[
              const SizedBox(width: AdwMetrics.spacingMedium),
              IconTheme(
                data: IconThemeData(
                  color: theme.colors.windowForeground,
                  size: AdwMetrics.iconSizeSmall,
                ),
                child: suffixWidget,
              ),
            ],
          ],
        ),
      ),
    );

    return Semantics(
      button: _isClickable,
      enabled: true,
      onTap: _isClickable ? widget.onPressed : null,
      child: FocusableActionDetector(
        focusNode: _rowFocusNode,
        enabled: true,
        mouseCursor:
            _isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (hovered) {
          if (_isClickable && _isHovered != hovered) {
            setState(() => _isHovered = hovered);
          }
        },
        onShowFocusHighlight: (focused) {
          final next = focused && _rowFocusNode.hasPrimaryFocus;
          if (_isFocused != next) {
            setState(() => _isFocused = next);
          }
        },
        onFocusChange: (_) {
          final next = _rowFocusNode.hasPrimaryFocus &&
              FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional;
          if (_isFocused != next) {
            setState(() => _isFocused = next);
          }
        },
        actions: _isClickable
            ? <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    widget.onPressed?.call();
                    return null;
                  },
                ),
              }
            : const <Type, Action<Intent>>{},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            if (_isClickable) setState(() => _isPressed = true);
          },
          onTapUp: (_) {
            if (_isClickable) setState(() => _isPressed = false);
          },
          onTapCancel: () {
            if (_isClickable) setState(() => _isPressed = false);
          },
          onTap: () {
            _rowFocusNode.requestFocus();
            if (_isClickable) widget.onPressed?.call();
          },
          child: AnimatedContainer(
            duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
            color: rowColor,
            foregroundDecoration: _isFocused
                ? BoxDecoration(
                    borderRadius: AdwGroupRowShape.borderRadiusOf(context),
                    border: Border.all(
                      color: theme.colors.focusBorderColor,
                      width: 2.0,
                    ),
                  )
                : null,
            child: content,
          ),
        ),
      ),
    );
  }
}
