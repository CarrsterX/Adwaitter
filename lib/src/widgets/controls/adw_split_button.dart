import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../overlays/adw_popover.dart';

/// Descriptor for an entry inside an [AdwSplitButton] dropdown menu.
class AdwSplitButtonMenuItem {
  final String label;
  final VoidCallback? onPressed;

  const AdwSplitButtonMenuItem({
    required this.label,
    this.onPressed,
  });
}

/// Official Libadwaita split button (`AdwSplitButton`).
///
/// Combines a primary action button on the left with a linked dropdown arrow
/// button on the right that opens an anchored [AdwPopoverSurface] menu.
class AdwSplitButton extends StatefulWidget {
  /// Optional leading icon for the primary action side.
  final Widget? icon;

  /// Optional label for the primary action side.
  final Widget? label;

  /// Optional custom child overriding [icon] and [label].
  final Widget? child;

  /// Callback triggered when the primary left button is clicked.
  final VoidCallback? onPressed;

  /// Menu items displayed inside the dropdown popover.
  final List<AdwSplitButtonMenuItem> menuItems;

  /// Optional custom popover builder overriding [menuItems].
  final Widget Function(BuildContext context, AdwPopoverHandle handle)?
      menuBuilder;

  /// Whether to render using the `.flat` transparent button variant.
  final bool isFlat;

  /// Minimum height of the split button (defaults to [AdwMetrics.buttonMinHeight]).
  final double height;

  const AdwSplitButton({
    super.key,
    this.icon,
    this.label,
    this.child,
    this.onPressed,
    this.menuItems = const <AdwSplitButtonMenuItem>[],
    this.menuBuilder,
    this.isFlat = false,
    this.height = AdwMetrics.buttonMinHeight,
  });

  @override
  State<AdwSplitButton> createState() => _AdwSplitButtonState();
}

class _AdwSplitButtonState extends State<AdwSplitButton> {
  final GlobalKey _dropdownKey = GlobalKey();
  AdwPopoverHandle? _popoverHandle;
  bool _primaryHovered = false;
  bool _primaryPressed = false;
  bool _dropdownHovered = false;
  bool _dropdownPressed = false;
  bool _isMenuOpen = false;

  @override
  void dispose() {
    _popoverHandle?.dismiss();
    super.dispose();
  }

  void _toggleMenu(BuildContext context) {
    if (_popoverHandle != null && _popoverHandle!.isOpen) {
      _popoverHandle!.dismiss();
      _popoverHandle = null;
      return;
    }
    if (widget.menuBuilder == null && widget.menuItems.isEmpty) return;

    final RenderBox? renderBox =
        _dropdownKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final Rect anchorRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;

    setState(() => _isMenuOpen = true);

    final handle = showAdwPopover(
      context: context,
      anchorRect: anchorRect,
      owner: this,
      parentAnchor: AdwPopoverAnchor.bottom,
      childAnchor: AdwPopoverAnchor.top,
      offset: Offset.zero,
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 240),
      onDismiss: () {
        if (mounted) {
          setState(() {
            _isMenuOpen = false;
            _popoverHandle = null;
          });
        }
      },
      builder: (popoverContext, handle) {
        if (widget.menuBuilder != null) {
          return widget.menuBuilder!(popoverContext, handle);
        }
        return AdwPopoverSurface(
          arrowSide: AdwPopoverArrowSide.top,
          padding: const EdgeInsets.all(6),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in widget.menuItems)
                  AdwPopoverMenuItem(
                    label: item.label,
                    onTap: () {
                      handle.dismiss();
                      item.onPressed?.call();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (mounted && handle.isOpen) {
      _popoverHandle = handle;
    } else {
      handle.dismiss();
      if (mounted) setState(() => _isMenuOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final duration = AdwCurves.resolve(context, AdwCurves.shortDuration);

    final fg = theme.colors.windowForeground;
    final baseBg = widget.isFlat
        ? theme.colors.splitButtonFlatSiblingColor.withValues(alpha: 0.0)
        : (theme.colors.isDark
            ? const Color(0xFF38383B)
            : const Color(0xFFE6E6E7));
    final bool isAnyActive = _primaryHovered ||
        _primaryPressed ||
        _dropdownHovered ||
        _dropdownPressed ||
        _isMenuOpen;
    final nonFlatHoverBg = Color.lerp(baseBg, fg, 0.08)!;
    final nonFlatActiveBg = Color.lerp(baseBg, fg, 0.16)!;
    final primaryBg = _primaryPressed
        ? (widget.isFlat ? theme.colors.activeColor : nonFlatActiveBg)
        : _primaryHovered
            ? (widget.isFlat
                ? theme.colors.splitButtonFlatHoverColor
                : nonFlatHoverBg)
            : (widget.isFlat ? baseBg : baseBg);
    final dropdownBg = (_dropdownPressed || _isMenuOpen)
        ? (widget.isFlat ? theme.colors.activeColor : nonFlatActiveBg)
        : _dropdownHovered
            ? (widget.isFlat
                ? theme.colors.splitButtonFlatHoverColor
                : nonFlatHoverBg)
            : (widget.isFlat ? baseBg : baseBg);

    Widget primaryContent = widget.child ??
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              IconTheme(
                data: IconThemeData(
                  color: theme.colors.foreground,
                  size: AdwMetrics.iconSizeSmall,
                ),
                child: widget.icon!,
              ),
              if (widget.label != null)
                const SizedBox(width: AdwMetrics.spacingSmall),
            ],
            if (widget.label != null)
              DefaultTextStyle(
                style: theme.typography.heading,
                child: widget.label!,
              ),
          ],
        );

    final primaryHorizontalPadding =
        (widget.label != null || widget.child != null) ? 10.0 : 8.0;

    final splitContent = AnimatedContainer(
      duration: duration,
      decoration: BoxDecoration(
        color: (widget.isFlat && isAnyActive)
            ? theme.colors.splitButtonFlatSiblingColor
            : baseBg,
        borderRadius: BorderRadius.circular(AdwMetrics.buttonRadius),
        border: widget.isFlat
            ? Border.all(
                color: (theme.colors.isHighContrast && isAnyActive)
                    ? theme.colors.splitButtonFlatSiblingBorderColor
                    : const Color(0x00000000),
                width: 1.0,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdwMetrics.buttonRadius),
        child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _primaryHovered = true),
            onExit: (_) => setState(() {
              _primaryHovered = false;
              _primaryPressed = false;
            }),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _primaryPressed = true),
              onTapUp: (_) => setState(() => _primaryPressed = false),
              onTapCancel: () => setState(() => _primaryPressed = false),
              onTap: widget.onPressed,
              child: AnimatedContainer(
                duration: duration,
                height: widget.height,
                padding: EdgeInsets.symmetric(
                  horizontal: primaryHorizontalPadding,
                ),
                decoration: BoxDecoration(
                  color: primaryBg,
                  borderRadius: widget.isFlat
                      ? BorderRadius.circular(AdwMetrics.buttonRadius)
                      : null,
                ),
                foregroundDecoration: (widget.isFlat &&
                        theme.colors.isHighContrast &&
                        (_primaryHovered || _primaryPressed))
                    ? BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AdwMetrics.buttonRadius),
                        border: Border.all(
                          color: theme.colors.borderColor,
                          width: 1.0,
                        ),
                      )
                    : null,
                child: Center(child: primaryContent),
              ),
            ),
          ),
          AnimatedOpacity(
            duration: duration,
            opacity: (widget.isFlat &&
                    (_primaryHovered ||
                        _primaryPressed ||
                        _dropdownHovered ||
                        _dropdownPressed ||
                        _isMenuOpen))
                ? 0.0
                : 1.0,
            child: Container(
              width: 1,
              height: widget.isFlat ? widget.height - 10.0 : widget.height,
              color: theme.colors.isHighContrast
                  ? theme.colors.splitButtonDividerHighContrastColor
                  : (widget.isFlat
                      ? (theme.colors.isDark
                          ? const Color(0xFF646467)
                          : const Color(0xFFBEBEC0))
                      : (theme.colors.isDark
                          ? const Color(0x28FFFFFF)
                          : const Color(0x22000000))),
            ),
          ),
          MouseRegion(
            key: _dropdownKey,
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _dropdownHovered = true),
            onExit: (_) => setState(() {
              _dropdownHovered = false;
              _dropdownPressed = false;
            }),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _dropdownPressed = true),
              onTapUp: (_) => setState(() => _dropdownPressed = false),
              onTapCancel: () => setState(() => _dropdownPressed = false),
              onTap: () => _toggleMenu(context),
              child: AnimatedContainer(
                duration: duration,
                height: widget.height,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: dropdownBg,
                  borderRadius: widget.isFlat
                      ? BorderRadius.circular(AdwMetrics.buttonRadius)
                      : null,
                ),
                foregroundDecoration: (widget.isFlat &&
                        theme.colors.isHighContrast &&
                        (_dropdownHovered || _dropdownPressed || _isMenuOpen))
                    ? BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AdwMetrics.buttonRadius),
                        border: Border.all(
                          color: theme.colors.borderColor,
                          width: 1.0,
                        ),
                      )
                    : null,
                child: Center(
                  child: CustomPaint(
                    size: const Size(14, 14),
                    painter: _SplitArrowPainter(color: theme.colors.foreground),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );

    if (theme.colors.isHighContrast && !widget.isFlat) {
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AdwMetrics.buttonRadius),
          border: Border.all(
            color: theme.colors.borderColor,
            width: 1.0,
          ),
        ),
        child: splitContent,
      );
    }

    return splitContent;
  }
}

class _SplitArrowPainter extends CustomPainter {
  final Color color;

  const _SplitArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.24, size.height * 0.42)
      ..lineTo(size.width * 0.50, size.height * 0.68)
      ..lineTo(size.width * 0.76, size.height * 0.42);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SplitArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
