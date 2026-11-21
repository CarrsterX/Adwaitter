import 'package:flutter/widgets.dart';

import 'adw_popover.dart';

/// High-level right-click / long-press context menu wrapper (`GtkPopoverMenu`).
///
/// Opens an [AdwPopoverSurface] anchored at the pointer position using
/// [showAdwPopover].
class AdwContextMenu extends StatelessWidget {
  final Widget child;
  final List<Widget> Function(BuildContext context, AdwPopoverHandle handle)
      itemsBuilder;
  final bool enableLongPress;
  final double minWidth;
  final double maxWidth;
  final bool isOsd;

  const AdwContextMenu({
    super.key,
    required this.child,
    required this.itemsBuilder,
    this.enableLongPress = true,
    this.minWidth = 160.0,
    this.maxWidth = 260.0,
    this.isOsd = false,
  });

  void _openAt(BuildContext context, Offset globalPosition) {
    final anchorRect = Rect.fromCenter(
      center: globalPosition,
      width: 2.0,
      height: 2.0,
    );
    showAdwPopover(
      context: context,
      anchorRect: anchorRect,
      parentAnchor: AdwPopoverAnchor.bottomLeft,
      childAnchor: AdwPopoverAnchor.topLeft,
      constraints: BoxConstraints(
        minWidth: minWidth,
        maxWidth: maxWidth,
      ),
      builder: (popoverContext, handle) {
        return AdwPopoverSurface(
          isOsd: isOsd,
          arrowSide: AdwPopoverArrowSide.none,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minWidth,
              maxWidth: maxWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: itemsBuilder(popoverContext, handle),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) => _openAt(context, details.globalPosition),
      onLongPressStart: enableLongPress
          ? (details) => _openAt(context, details.globalPosition)
          : null,
      child: child,
    );
  }
}
