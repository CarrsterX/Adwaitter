import 'package:flutter/widgets.dart';

import 'adw_popover.dart';

/// High-level right-click / long-press context menu wrapper (`GtkPopoverMenu`).
///
/// Opens an [AdwPopoverSurface] anchored at the pointer position using
/// [showAdwPopover].
///
/// ```dart
/// AdwContextMenu(
///   itemsBuilder: (context, handle) => [
///     AdwPopoverMenuItem(label: 'Copy', onTap: handle.dismiss),
///     AdwPopoverMenuItem(label: 'Paste', onTap: handle.dismiss),
///   ],
///   child: const AdwCard(child: Text('Right-click me')),
/// )
/// ```
///
/// See also:
///
/// * [showAdwPopover], the underlying popover presentation API.
/// * [AdwPopoverMenuItem], standard menu rows for [itemsBuilder].
///
/// {@category Overlays}
class AdwContextMenu extends StatelessWidget {
  /// Target widget that triggers the context menu on secondary click or long press.
  final Widget child;

  /// Builder returning menu widgets (typically [AdwPopoverMenuItem] and
  /// [AdwPopoverDivider]).
  final List<Widget> Function(BuildContext context, AdwPopoverHandle handle)
      itemsBuilder;

  /// Whether long-press gestures also open the context menu (recommended for
  /// touchscreens). Defaults to `true`.
  final bool enableLongPress;

  /// Minimum width of the menu popover in logical pixels. Defaults to `160.0`.
  final double minWidth;

  /// Maximum width of the menu popover in logical pixels. Defaults to `260.0`.
  final double maxWidth;

  /// Whether to render the popover with `.osd` dark styling. Defaults to `false`.
  final bool isOsd;

  /// Creates a right-click / long-press context menu wrapper.
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
