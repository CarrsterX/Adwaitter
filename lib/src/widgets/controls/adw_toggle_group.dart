import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';

/// Single item descriptor within an [AdwToggleGroup].
class AdwToggleItem<T> {
  final T value;
  final Widget child;
  final Widget? icon;
  final Widget? label;
  final String? tooltip;
  final bool enabled;

  const AdwToggleItem({
    required this.value,
    this.child = const SizedBox.shrink(),
    this.icon,
    this.label,
    this.tooltip,
    this.enabled = true,
  });

  /// Convenience constructor creating a standard icon + label toggle item.
  factory AdwToggleItem.withLabel({
    required T value,
    Widget? icon,
    required Widget label,
    String? tooltip,
    bool enabled = true,
  }) {
    return AdwToggleItem(
      value: value,
      icon: icon,
      label: label,
      tooltip: tooltip,
      enabled: enabled,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon,
            const SizedBox(width: AdwMetrics.spacingSmall),
          ],
          label,
        ],
      ),
    );
  }
}

/// Visual style variants for [AdwToggleGroup] matching Libadwaita CSS classes.
enum AdwToggleGroupStyle {
  /// Standard recessed container with rounded segments.
  standard,

  /// Transparent container with no dividers (`.flat` in Libadwaita).
  flat,

  /// Fully pill-shaped capsule container and segments (`.round` in Libadwaita).
  round,
}

/// Official Libadwaita segmented toggle group (`AdwToggleGroup`).
///
/// Follows upstream Libadwaita linked button bar specifications:
/// - GitLab source: `https://gitlab.gnome.org/GNOME/libadwaita/-/blob/main/src/...`
/// - CSS selector: `.linked.toggle-group`
///
/// Displays multiple mutually-exclusive options in a unified rounded container
/// with an animated active pill indicator and 1px dividers between unselected items.
class AdwToggleGroup<T> extends StatelessWidget {
  /// The list of selectable items.
  final List<AdwToggleItem<T>> items;

  /// The currently active selected value.
  final T selectedValue;

  /// Callback emitted when a new item is selected.
  final ValueChanged<T>? onChanged;

  /// Minimum height of each toggle item (default [AdwMetrics.buttonMinHeight]).
  final double height;

  /// Padding surrounding each individual toggle segment.
  final EdgeInsetsGeometry? itemPadding;

  /// Whether all segments expand to share equal width across the container.
  final bool homogeneous;

  /// Visual style variant (`standard`, `flat`, or `round`).
  final AdwToggleGroupStyle style;

  /// Layout orientation (`Axis.horizontal` or `Axis.vertical`).
  final Axis orientation;

  const AdwToggleGroup({
    super.key,
    required this.items,
    required this.selectedValue,
    this.onChanged,
    this.height = AdwMetrics.buttonMinHeight,
    this.itemPadding,
    this.homogeneous = false,
    this.style = AdwToggleGroupStyle.standard,
    this.orientation = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final isFlat = style == AdwToggleGroupStyle.flat;
    final isRound = style == AdwToggleGroupStyle.round;
    final isVertical = orientation == Axis.vertical;
    final outerRadius = isRound ? 999.0 : AdwMetrics.buttonRadius;
    final innerRadius = isRound
        ? 999.0
        : (isFlat ? AdwMetrics.buttonRadius : AdwMetrics.buttonRadius - 3.0);
    final List<Widget> children = [];

    for (int index = 0; index < items.length; index++) {
      final item = items[index];
      final isSelected = item.value == selectedValue;
      final isLast = index == items.length - 1;
      final nextIsSelected = !isLast && items[index + 1].value == selectedValue;
      final effectivePadding = itemPadding ??
          (item.label != null
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 2)
              : const EdgeInsets.symmetric(horizontal: 6, vertical: 2));

      final double segMinWidth = item.label == null
          ? (isVertical && !isFlat ? 28.0 : 34.0)
          : 0.0;
      final double segMinHeight = isFlat ? height : height - 6.0;

      final segment = _AdwToggleSegment<T>(
        item: item,
        isSelected: isSelected,
        isFlat: isFlat,
        padding: effectivePadding,
        borderRadius: innerRadius,
        minWidth: segMinWidth,
        minHeight: segMinHeight,
        onSelected: item.enabled && onChanged != null
            ? () => onChanged!(item.value)
            : null,
      );

      children.add(homogeneous ? Expanded(child: segment) : segment);

      if (!isLast) {
        final showDivider = !isFlat && !isSelected && !nextIsSelected;
        final dividerDuration =
            AdwCurves.resolve(context, const Duration(milliseconds: 240));
        final inset = isRound ? 6.0 : 3.0;
        children.add(
          AnimatedContainer(
            duration: dividerDuration,
            curve: Curves.easeOutCubic,
            margin: isVertical
                ? EdgeInsets.symmetric(vertical: 1.0, horizontal: inset)
                : EdgeInsets.symmetric(horizontal: 1.0, vertical: inset),
            width: isVertical ? double.infinity : 1.0,
            height: isVertical ? 1.0 : null,
            color: showDivider
                ? theme.colors.dividerColor
                : theme.colors.dividerColor.withValues(alpha: 0.0),
          ),
        );
      }
    }

    final trackColor = isFlat
        ? const Color(0x00000000)
        : theme.colors.toggleGroupTrackColor;

    return Container(
      height: isVertical ? null : height,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(outerRadius),
      ),
      foregroundDecoration: (!isFlat && theme.colors.isHighContrast)
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(outerRadius),
              border: Border.all(
                color: theme.colors.borderColor,
                width: 1.0,
              ),
            )
          : null,
      padding: isFlat ? EdgeInsets.zero : const EdgeInsets.all(3),
      child: isVertical
          ? IntrinsicWidth(
              child: Column(
                mainAxisSize: homogeneous ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            )
          : Row(
              mainAxisSize: homogeneous ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
    );
  }
}

class _AdwToggleSegment<T> extends StatefulWidget {
  final AdwToggleItem<T> item;
  final bool isSelected;
  final bool isFlat;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double minWidth;
  final double minHeight;
  final VoidCallback? onSelected;

  const _AdwToggleSegment({
    required this.item,
    required this.isSelected,
    this.isFlat = false,
    required this.padding,
    required this.borderRadius,
    this.minWidth = 0.0,
    this.minHeight = 0.0,
    this.onSelected,
  });

  @override
  State<_AdwToggleSegment<T>> createState() => _AdwToggleSegmentState<T>();
}

class _AdwToggleSegmentState<T> extends State<_AdwToggleSegment<T>> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  bool get _isClickable => widget.item.enabled && widget.onSelected != null;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final duration =
        AdwCurves.resolve(context, const Duration(milliseconds: 240));

    final Color selectedBg = theme.colors.isDark
        ? (widget.isFlat
            ? const Color(0xFF47474B)
            : const Color(0xFF6C6C6F))
        : (widget.isFlat
            ? const Color(0xFFEBEBEB)
            : const Color(0xFFFFFFFF));

    Color bg = selectedBg.withValues(alpha: 0.0);
    Color fg = theme.colors.foreground;

    if (widget.isSelected) {
      bg = selectedBg;
      fg = theme.colors.foreground;
    } else if (_isClickable) {
      if (_isPressed) {
        bg = selectedBg.withValues(alpha: 0.55);
      } else if (_isHovered || _isFocused) {
        bg = selectedBg.withValues(alpha: 0.30);
      }
    }

    if (!widget.item.enabled) {
      fg = fg.withValues(alpha: 0.4);
    }

    Widget content = widget.item.child;
    if (widget.item.icon != null || widget.item.label != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.item.icon != null) ...[
            IconTheme(
              data: IconThemeData(
                color: fg,
                size: AdwMetrics.iconSizeSmall,
              ),
              child: widget.item.icon!,
            ),
            if (widget.item.label != null)
              const SizedBox(width: AdwMetrics.spacingSmall),
          ],
          if (widget.item.label != null)
            DefaultTextStyle(
              style: theme.typography.heading.copyWith(
                color: fg,
                height: 1.0,
              ),
              child: widget.item.label!,
            ),
        ],
      );
    }

    return Semantics(
      button: true,
      selected: widget.isSelected,
      enabled: _isClickable,
      onTap: _isClickable ? widget.onSelected : null,
      child: FocusableActionDetector(
        enabled: _isClickable,
        mouseCursor:
            _isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (hovered) {
          if (_isClickable && _isHovered != hovered) {
            setState(() {
              _isHovered = hovered;
              if (!hovered) _isPressed = false;
            });
          }
        },
        onShowFocusHighlight: (focused) {
          if (_isFocused != focused) setState(() => _isFocused = focused);
        },
        actions: _isClickable
            ? <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    widget.onSelected?.call();
                    return null;
                  },
                ),
              }
            : const <Type, Action<Intent>>{},
        child: GestureDetector(
          onTapDown: (_) {
            if (_isClickable) setState(() => _isPressed = true);
          },
          onTapUp: (_) {
            if (_isClickable) setState(() => _isPressed = false);
          },
          onTapCancel: () {
            if (_isClickable) setState(() => _isPressed = false);
          },
          onTap: widget.onSelected,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(
              minWidth: widget.minWidth,
              minHeight: widget.minHeight,
            ),
            padding: widget.padding,
            foregroundDecoration: _isFocused
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    border: Border.all(
                      color: theme.colors.focusBorderColor,
                      width: 2.0,
                    ),
                  )
                : (theme.colors.isHighContrast &&
                        (widget.isSelected || _isHovered || _isPressed))
                    ? BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(widget.borderRadius),
                        border: Border.all(
                          color: theme.colors.borderColor,
                          width: 1.0,
                        ),
                      )
                    : null,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: widget.isFlat
                ? null
                : [
                    BoxShadow(
                      color: widget.isSelected
                          ? const Color(0x1F000000)
                          : const Color(0x00000000),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Center(
            child: DefaultTextStyle(
              style: theme.typography.body.copyWith(
                color: fg,
                fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              child: content,
            ),
          ),
        ),
      ),
      ),
    );
  }
}

