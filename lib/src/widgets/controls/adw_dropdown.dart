import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../overlays/adw_popover.dart';

/// Standalone Libadwaita dropdown selector (`GtkDropDown`).
///
/// Displays the currently selected item with a trailing chevron and opens an
/// anchored [AdwPopoverSurface] menu on tap.
///
/// ```dart
/// AdwDropdown<String>(
///   value: 'Normal',
///   items: const ['Compact', 'Normal', 'Spacious'],
///   itemLabelBuilder: (item) => item,
///   onChanged: (value) {},
/// )
/// ```
///
/// See also:
///
/// * [AdwComboRow], for dropdown selection inside an [AdwPreferencesGroup].
/// * [AdwPopoverSurface], the popover container rendered for the menu.
///
/// {@category Controls}
class AdwDropdown<T> extends StatefulWidget {
  /// Currently selected value from [items].
  final T value;

  /// Available options shown in the dropdown popover.
  final List<T> items;

  /// Converts an item in [items] into its display label.
  final String Function(T item) itemLabelBuilder;

  /// Callback invoked when the user chooses a new item. When `null`, the
  /// dropdown is disabled.
  final ValueChanged<T>? onChanged;

  /// Whether to use flat button styling (transparent until hovered/open).
  /// Defaults to `false`.
  final bool isFlat;

  /// Optional fixed width for the trigger button.
  final double? width;

  /// Maximum height of the scrollable popover menu. Defaults to `280.0`.
  final double maxMenuHeight;

  /// Creates a standalone Libadwaita dropdown selector.
  const AdwDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.itemLabelBuilder,
    required this.onChanged,
    this.isFlat = false,
    this.width,
    this.maxMenuHeight = 280.0,
  });

  @override
  State<AdwDropdown<T>> createState() => _AdwDropdownState<T>();
}

class _AdwDropdownState<T> extends State<AdwDropdown<T>> {
  final GlobalKey _buttonKey = GlobalKey();
  bool _isHovered = false;
  bool _isOpen = false;
  bool _isFocused = false;

  bool get _isEnabled => widget.onChanged != null && widget.items.isNotEmpty;

  void _openMenu() {
    if (!_isEnabled) return;
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final anchorRect = box.localToGlobal(Offset.zero) & box.size;

    setState(() => _isOpen = true);
    showAdwPopover(
      context: context,
      anchorRect: anchorRect,
      owner: _buttonKey,
      parentAnchor: AdwPopoverAnchor.bottom,
      childAnchor: AdwPopoverAnchor.top,
      offset: const Offset(0, 6),
      constraints: BoxConstraints(
        minWidth: box.size.width,
        maxWidth: box.size.width < 220.0 ? 220.0 : box.size.width,
        maxHeight: widget.maxMenuHeight,
      ),
      onDismiss: () {
        if (mounted) setState(() => _isOpen = false);
      },
      builder: (popoverContext, handle) {
        final theme = AdwTheme.of(popoverContext);
        return AdwPopoverSurface(
          arrowSide: AdwPopoverArrowSide.top,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in widget.items)
                  AdwPopoverMenuItem(
                    label: widget.itemLabelBuilder(item),
                    trailing: item == widget.value
                        ? CustomPaint(
                            size: const Size(14, 14),
                            painter: _DropdownCheckPainter(
                              color: theme.colors.windowForeground,
                            ),
                          )
                        : null,
                    onTap: () {
                      handle.dismiss();
                      widget.onChanged?.call(item);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final fg = theme.colors.windowForeground;

    Color bg;
    if (widget.isFlat) {
      if (_isOpen) {
        bg = fg.withValues(alpha: 0.16);
      } else if (_isHovered && _isEnabled) {
        bg = theme.colors.hoverColor;
      } else {
        bg = const Color(0x00000000);
      }
    } else {
      if (_isOpen) {
        bg = fg.withValues(alpha: 0.25);
      } else if (_isHovered && _isEnabled) {
        bg = fg.withValues(alpha: 0.15);
      } else {
        bg = fg.withValues(alpha: theme.colors.isDark ? 0.12 : 0.08);
      }
    }

    final effectiveFg = _isEnabled ? fg : fg.withValues(alpha: 0.4);

    return Semantics(
      button: true,
      enabled: _isEnabled,
      onTap: _isEnabled ? _openMenu : null,
      child: FocusableActionDetector(
        enabled: _isEnabled,
        mouseCursor:
            _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (hovered) {
          if (_isEnabled && _isHovered != hovered) {
            setState(() => _isHovered = hovered);
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
                    _openMenu();
                    return null;
                  },
                ),
              }
            : const <Type, Action<Intent>>{},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _isEnabled ? _openMenu : null,
          child: AnimatedContainer(
            key: _buttonKey,
            duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
            curve: AdwCurves.standard,
            width: widget.width,
            constraints: const BoxConstraints(
              minHeight: AdwMetrics.buttonMinHeight,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AdwMetrics.buttonRadius),
            ),
            foregroundDecoration: _isFocused
                ? BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AdwMetrics.buttonRadius),
                    border: Border.all(
                      color: theme.colors.focusBorderColor,
                      width: 2.0,
                    ),
                  )
                : null,
            child: Row(
              mainAxisSize:
                  widget.width != null ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    widget.itemLabelBuilder(widget.value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.heading.copyWith(color: effectiveFg),
                  ),
                ),
                const SizedBox(width: 8.0),
                CustomPaint(
                  size: const Size(12, 12),
                  painter: _DropdownChevronPainter(color: effectiveFg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownChevronPainter extends CustomPainter {
  final Color color;

  const _DropdownChevronPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.36)
      ..lineTo(size.width * 0.50, size.height * 0.66)
      ..lineTo(size.width * 0.78, size.height * 0.36);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DropdownChevronPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DropdownCheckPainter extends CustomPainter {
  final Color color;

  const _DropdownCheckPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.20, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.74)
      ..lineTo(size.width * 0.80, size.height * 0.28);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DropdownCheckPainter oldDelegate) =>
      oldDelegate.color != color;
}
