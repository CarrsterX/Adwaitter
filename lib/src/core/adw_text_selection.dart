import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, ValueListenable, defaultTargetPlatform;
import 'package:flutter/widgets.dart';

import '../theme/adw_colors.dart';
import '../theme/adw_metrics.dart';
import '../theme/adw_theme.dart';

/// Pure-Dart Adwaita-styled [TextSelectionControls] for mobile (Android & iOS)
/// plus a unified Adwaita context menu toolbar for [EditableText] and
/// [SelectableRegion].
class AdwTextSelectionControls extends TextSelectionControls {
  final Color? accentColor;

  AdwTextSelectionControls({this.accentColor});

  static const double _kHandleTouchWidth = 40.0;
  static const double _kHandleMinHeight = 36.0;

  /// Returns [AdwTextSelectionControls] on Android and iOS, and
  /// [EmptyTextSelectionControls] on desktop platforms.
  static TextSelectionControls forPlatform(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return AdwTextSelectionControls(
        accentColor: AdwTheme.maybeOf(context)?.colors.accentColor,
      );
    }
    return EmptyTextSelectionControls();
  }

  /// Adwaita context menu builder for [EditableText.contextMenuBuilder].
  static Widget contextMenuBuilder(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    return _AdwTextSelectionToolbar(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: editableTextState.contextMenuButtonItems,
    );
  }

  /// Adwaita context menu builder for [SelectableRegion.contextMenuBuilder].
  static Widget selectableContextMenuBuilder(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    return _AdwTextSelectionToolbar(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: selectableRegionState.contextMenuButtonItems,
    );
  }

  @override
  Size getHandleSize(double textLineHeight) => Size(
        _kHandleTouchWidth,
        math.max(_kHandleMinHeight, textLineHeight + 12.0),
      );

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    final size = getHandleSize(textLineHeight);
    switch (type) {
      case TextSelectionHandleType.left:
        return Offset(_kHandleTouchWidth / 2 + 2.0, size.height - 6.0);
      case TextSelectionHandleType.right:
        return Offset(_kHandleTouchWidth / 2 - 2.0, size.height - 6.0);
      case TextSelectionHandleType.collapsed:
        return Offset(_kHandleTouchWidth / 2, size.height - 6.0);
    }
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    final theme = AdwTheme.maybeOf(context);
    final Color color =
        accentColor ?? theme?.colors.accentColor ?? AdwColors.accentBlue;
    final size = getHandleSize(textLineHeight);

    final Widget handle = _AdwSelectionHandle(
      width: size.width,
      height: size.height,
      type: type,
      color: color,
    );

    if (onTap == null) return handle;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: handle,
    );
  }

  @override
  // ignore: deprecated_member_use
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset selectionMidpoint,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ValueListenable<ClipboardStatus>? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) {
    return const SizedBox.shrink();
  }
}

class _AdwSelectionHandle extends StatefulWidget {
  final double width;
  final double height;
  final TextSelectionHandleType type;
  final Color color;

  const _AdwSelectionHandle({
    required this.width,
    required this.height,
    required this.type,
    required this.color,
  });

  @override
  State<_AdwSelectionHandle> createState() => _AdwSelectionHandleState();
}

class _AdwSelectionHandleState extends State<_AdwSelectionHandle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final double barWidth = _pressed
        ? 7.0
        : (widget.type == TextSelectionHandleType.collapsed ? 2.5 : 3.0);

    return TextFieldTapRegion(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          if (!_pressed) setState(() => _pressed = true);
        },
        onPointerUp: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        onPointerCancel: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              width: barWidth,
              height: widget.height - 10.0,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdwTextSelectionToolbar extends StatelessWidget {
  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> buttonItems;

  const _AdwTextSelectionToolbar({
    required this.anchors,
    required this.buttonItems,
  });

  String _labelFor(ContextMenuButtonItem item) {
    if (item.label != null && item.label!.isNotEmpty) return item.label!;
    return switch (item.type) {
      ContextMenuButtonType.cut => 'Cut',
      ContextMenuButtonType.copy => 'Copy',
      ContextMenuButtonType.paste => 'Paste',
      ContextMenuButtonType.selectAll => 'Select All',
      ContextMenuButtonType.delete => 'Delete',
      ContextMenuButtonType.lookUp => 'Look Up',
      ContextMenuButtonType.searchWeb => 'Search',
      ContextMenuButtonType.share => 'Share',
      ContextMenuButtonType.liveTextInput => 'Scan Text',
      ContextMenuButtonType.custom => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (buttonItems.isEmpty) return const SizedBox.shrink();
    final theme = AdwTheme.maybeOf(context);
    final bg = theme?.colors.popoverBackground ?? const Color(0xFF36363A);
    final fg = theme?.colors.popoverForeground ?? const Color(0xFFFFFFFF);
    final border = theme?.colors.windowOutline ?? const Color(0x26000000);
    final hoverBg = theme?.colors.hoverBackground ?? const Color(0x14FFFFFF);

    return TextFieldTapRegion(
      child: CustomSingleChildLayout(
        delegate: _AdwToolbarLayoutDelegate(
          anchorAbove: anchors.primaryAnchor,
          anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AdwMetrics.cardRadius),
            border: Border.all(color: border, width: 1.0),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < buttonItems.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: border,
                  ),
                _AdwToolbarButton(
                  label: _labelFor(buttonItems[i]),
                  foregroundColor: fg,
                  hoverColor: hoverBg,
                  onPressed: buttonItems[i].onPressed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdwToolbarButton extends StatefulWidget {
  final String label;
  final Color foregroundColor;
  final Color hoverColor;
  final VoidCallback? onPressed;

  const _AdwToolbarButton({
    required this.label,
    required this.foregroundColor,
    required this.hoverColor,
    this.onPressed,
  });

  @override
  State<_AdwToolbarButton> createState() => _AdwToolbarButtonState();
}

class _AdwToolbarButtonState extends State<_AdwToolbarButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.maybeOf(context);
    final style = (theme?.typography.body ?? const TextStyle(fontSize: 13.5))
        .copyWith(
      color: widget.foregroundColor,
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (_hovered || _pressed)
                ? widget.hoverColor
                : const Color(0x00000000),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(widget.label, style: style),
        ),
      ),
    );
  }
}

class _AdwToolbarLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset anchorAbove;
  final Offset anchorBelow;

  const _AdwToolbarLayoutDelegate({
    required this.anchorAbove,
    required this.anchorBelow,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const double margin = 8.0;
    const double gap = 8.0;
    final double dx = (anchorAbove.dx - childSize.width / 2).clamp(
      margin,
      math.max(margin, size.width - childSize.width - margin),
    );
    double dy = anchorAbove.dy - childSize.height - gap;
    if (dy < margin) {
      dy = (anchorBelow.dy + gap).clamp(
        margin,
        math.max(margin, size.height - childSize.height - margin),
      );
    }
    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(covariant _AdwToolbarLayoutDelegate oldDelegate) {
    return anchorAbove != oldDelegate.anchorAbove ||
        anchorBelow != oldDelegate.anchorBelow;
  }
}
