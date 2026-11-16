import 'package:flutter/widgets.dart';

import '../../l10n/adw_localizations.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../overlays/adw_popover.dart';

/// Preference row with a native GTK4/Libadwaita popover dropdown (`AdwComboRow`).
///
/// Displays the currently selected value next to a trailing dropdown indicator
/// and opens an anchored popover menu below (or above) the chevron when activated.
class AdwComboRow<T> extends StatefulWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? prefix;
  final List<T> items;
  final T selectedItem;
  final String Function(T item)? itemTitleBuilder;
  final ValueChanged<T>? onSelected;
  final bool enableSearch;
  final String? searchPlaceholder;

  const AdwComboRow({
    super.key,
    required this.title,
    this.subtitle,
    this.prefix,
    required this.items,
    required this.selectedItem,
    this.itemTitleBuilder,
    this.onSelected,
    this.enableSearch = false,
    this.searchPlaceholder,
  });

  @override
  State<AdwComboRow<T>> createState() => _AdwComboRowState<T>();
}

class _AdwComboRowState<T> extends State<AdwComboRow<T>> {
  final GlobalKey _chevronKey = GlobalKey();
  AdwPopoverHandle? _popoverHandle;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _popoverHandle?.dismiss();
    _popoverHandle = null;
  }

  String _formatItem(T item) {
    if (widget.itemTitleBuilder != null) {
      return widget.itemTitleBuilder!(item);
    }
    return item.toString();
  }

  void _showPopoverMenu(BuildContext context) {
    if (_popoverHandle != null && _popoverHandle!.isOpen) {
      _removeOverlay();
      return;
    }

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final Offset rowOrigin = renderBox.localToGlobal(Offset.zero);
    final Size rowSize = renderBox.size;
    final Rect anchorRect = rowOrigin & rowSize;

    final RenderBox? chevronBox =
        _chevronKey.currentContext?.findRenderObject() as RenderBox?;
    final Rect chevronRect = (chevronBox != null && chevronBox.hasSize)
        ? (chevronBox.localToGlobal(Offset.zero) & chevronBox.size)
        : Rect.fromCenter(
            center: Offset(anchorRect.right - 20.0, anchorRect.center.dy),
            width: 16,
            height: 16,
          );

    final theme = AdwTheme.of(context);
    final textDirection = Directionality.of(context);
    final l10n = AdwLocalizations.of(context);
    final itemStyle = theme.typography.body;

    double maxItemTextWidth = 0.0;
    for (final item in widget.items) {
      final painter = TextPainter(
        text: TextSpan(text: _formatItem(item), style: itemStyle),
        maxLines: 1,
        textDirection: textDirection,
      )..layout();
      if (painter.width > maxItemTextWidth) {
        maxItemTextWidth = painter.width;
      }
      painter.dispose();
    }
    // Container padding (12) + item horizontal padding (24) + gap (8) + checkmark (16) + scrollbar clearance (10).
    final double popoverWidth = (maxItemTextWidth + 70.0).clamp(
      widget.enableSearch ? 180.0 : 140.0,
      280.0,
    );

    final handle = showAdwPopover(
      context: context,
      anchorRect: chevronRect,
      owner: this,
      parentAnchor: AdwPopoverAnchor.bottom,
      childAnchor: AdwPopoverAnchor.top,
      offset: const Offset(0, 4),
      constraints: BoxConstraints(
        minWidth: popoverWidth,
        maxWidth: popoverWidth,
        maxHeight: widget.enableSearch ? 380 : 320,
      ),
      onDismiss: () {
        if (mounted) {
          _popoverHandle = null;
        }
      },
      builder: (popoverContext, handle) {
        return _AdwComboPopover<T>(
          items: widget.items,
          selectedItem: widget.selectedItem,
          formatItem: _formatItem,
          enableSearch: widget.enableSearch,
          searchPlaceholder: widget.searchPlaceholder ?? l10n.searchPlaceholder,
          onSelected: (item) {
            handle.dismiss();
            widget.onSelected?.call(item);
          },
        );
      },
    );

    if (mounted && handle.isOpen) {
      _popoverHandle = handle;
    } else {
      handle.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);

    Color rowBg = const Color(0x00000000);
    if (_isPressed) {
      rowBg = theme.colors.activeColor;
    } else if (_isHovered) {
      rowBg = theme.colors.hoverBackground;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () => _showPopoverMenu(context),
        child: AnimatedContainer(
          duration: AdwCurves.shortDuration,
          curve: AdwCurves.standard,
          constraints: const BoxConstraints(minHeight: AdwMetrics.rowMinHeight),
          color: rowBg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              if (widget.prefix != null) ...[
                IconTheme(
                  data: IconThemeData(
                    color: theme.colors.windowForeground,
                    size: AdwMetrics.iconSizeMedium,
                  ),
                  child: widget.prefix!,
                ),
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
                        style: theme.typography.subtitle,
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
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      _formatItem(widget.selectedItem),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.copyWith(
                        color: theme.colors.windowForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CustomPaint(
                    key: _chevronKey,
                    size: const Size(16, 16),
                    painter: _ChevronDownPainter(
                      color: theme.colors.windowForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdwComboPopover<T> extends StatefulWidget {
  final List<T> items;
  final T selectedItem;
  final String Function(T item) formatItem;
  final bool enableSearch;
  final String searchPlaceholder;
  final ValueChanged<T> onSelected;

  const _AdwComboPopover({
    required this.items,
    required this.selectedItem,
    required this.formatItem,
    required this.enableSearch,
    required this.searchPlaceholder,
    required this.onSelected,
  });

  @override
  State<_AdwComboPopover<T>> createState() => _AdwComboPopoverState<T>();
}

class _AdwComboPopoverState<T> extends State<_AdwComboPopover<T>> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchFocused = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleFocusChange);
    if (widget.enableSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() => _searchFocused = _searchFocusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleFocusChange);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);

    final filteredItems = _query.isEmpty
        ? widget.items
        : widget.items
            .where((item) => widget
                .formatItem(item)
                .toLowerCase()
                .contains(_query.toLowerCase()))
            .toList(growable: false);

    final searchBg = theme.colors.isDark
        ? const Color(0xFF47474B)
        : const Color(0xFFE6E6EA);

    return AdwPopoverSurface(
      arrowSide: AdwPopoverArrowSide.top,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.enableSearch) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: searchBg,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: _searchFocused
                        ? theme.colors.accentColor.withValues(alpha: 0.75)
                        : theme.colors.borderColor,
                    width: _searchFocused ? 2.0 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    CustomPaint(
                      size: const Size(14, 14),
                      painter: _SearchIconPainter(
                        color: theme.colors.secondaryForeground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          if (_query.isEmpty)
                            Text(
                              widget.searchPlaceholder,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.body.copyWith(
                                fontSize: 14,
                                color: theme.colors.secondaryForeground,
                              ),
                            ),
                          EditableText(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            cursorWidth: 1.0,
                            cursorOpacityAnimates: true,
                            showCursor: true,
                            enableInteractiveSelection: true,
                            style: theme.typography.body.copyWith(
                              fontSize: 14,
                              color: theme.colors.popoverForeground,
                            ),
                            cursorColor: theme.colors.windowForeground,
                            backgroundCursorColor:
                                theme.colors.windowForeground.withValues(alpha: 0.14),
                            selectionColor:
                                theme.colors.accentColor.withValues(alpha: 0.35),
                            onChanged: (val) => setState(() => _query = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: filteredItems.map((item) {
                  final isSelected = item == widget.selectedItem;
                  return _AdwPopoverItem(
                    label: widget.formatItem(item),
                    isSelected: isSelected,
                    onTap: () => widget.onSelected(item),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdwPopoverItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AdwPopoverItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AdwPopoverItem> createState() => _AdwPopoverItemState();
}

class _AdwPopoverItemState extends State<_AdwPopoverItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);

    Color bg = const Color(0x00000000);
    if (_isPressed) {
      bg = theme.colors.activeColor;
    } else if (_isHovered) {
      bg = theme.colors.hoverColor;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AdwMetrics.buttonRadius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: theme.typography.body.copyWith(
                    color: theme.colors.popoverForeground,
                  ),
                ),
              ),
              if (widget.isSelected) ...[
                const SizedBox(width: 8),
                CustomPaint(
                  size: const Size(16, 16),
                  painter: _CheckmarkPainter(
                    color: theme.colors.popoverForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChevronDownPainter extends CustomPainter {
  final Color color;

  const _ChevronDownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.25, size.height * 0.375)
      ..lineTo(size.width * 0.5, size.height * 0.625)
      ..lineTo(size.width * 0.75, size.height * 0.375);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChevronDownPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

class _CheckmarkPainter extends CustomPainter {
  final Color color;

  const _CheckmarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(2.0, size.height * 0.55)
      ..lineTo(size.width * 0.42, size.height * 0.78)
      ..lineTo(size.width - 1.5, size.height * 0.22);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

class _SearchIconPainter extends CustomPainter {
  final Color color;

  const _SearchIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final radius = size.width * 0.34;
    final center = Offset(radius + 1.0, radius + 1.0);
    canvas.drawCircle(center, radius, paint);

    final handleStart = Offset(
      center.dx + radius * 0.72,
      center.dy + radius * 0.72,
    );
    final handleEnd = Offset(size.width - 1.0, size.height - 1.0);
    canvas.drawLine(handleStart, handleEnd, paint);
  }

  @override
  bool shouldRepaint(covariant _SearchIconPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
