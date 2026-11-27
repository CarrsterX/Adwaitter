import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';

/// Interactive navigation sidebar item (`AdwSidebarItem`).
///
/// Implements the GNOME Libadwaita navigation sidebar row with hover/active
/// feedback, a `6px` rounded selection highlight, and optional leading [icon]
/// and [trailing] badge/counter.
///
/// ```dart
/// AdwSidebarItem(
///   icon: const Icon(AdwIcons.folder_symbolic, size: 16),
///   title: const Text('Documents'),
///   isSelected: true,
///   onTap: () {},
/// )
/// ```
///
/// See also:
///
/// * [AdwSidebar], the container for [AdwSidebarItem] entries.
///
/// {@category Navigation}
class AdwSidebarItem extends StatefulWidget {
  /// Optional leading symbolic icon placed before [title].
  final Widget? icon;

  /// Primary label widget for the sidebar entry.
  final Widget title;

  /// Optional trailing widget (e.g. unread badge or status icon).
  final Widget? trailing;

  /// Whether this item is currently selected. Defaults to `false`.
  final bool isSelected;

  /// Callback invoked when the user activates this sidebar item.
  final VoidCallback? onTap;

  /// Creates an interactive GNOME sidebar item.
  const AdwSidebarItem({
    super.key,
    this.icon,
    required this.title,
    this.trailing,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<AdwSidebarItem> createState() => _AdwSidebarItemState();
}

class _AdwSidebarItemState extends State<AdwSidebarItem> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;
  bool _focusedByPointer = false;
  final FocusNode _focusNode = FocusNode(debugLabel: 'AdwSidebarItem');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);

    Color bg = const Color(0x00000000);
    if (widget.isSelected) {
      if (_isPressed) {
        bg = theme.colors.sidebarSelectedActiveBackground; // 19%
      } else if (_isHovered || _isFocused) {
        bg = theme.colors.sidebarSelectedHoverBackground; // 13%
      } else {
        bg = theme.colors.sidebarSelectedBackground; // 10% -> exact #424246 over #2e2e32
      }
    } else if (_isPressed) {
      bg = theme.colors.sidebarActiveBackground; // 16%
    } else if (_isHovered || _isFocused) {
      bg = theme.colors.sidebarHoverBackground; // 7%
    }

    final effectiveFg = theme.colors.windowForeground;

    final isEnabled = widget.onTap != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.0),
      child: Semantics(
        button: isEnabled,
        selected: widget.isSelected,
        enabled: isEnabled,
        onTap: widget.onTap,
        child: FocusableActionDetector(
          focusNode: _focusNode,
          enabled: isEnabled,
          mouseCursor:
              isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onShowHoverHighlight: (hovered) {
            if (_isHovered != hovered) setState(() => _isHovered = hovered);
          },
          onShowFocusHighlight: (focused) {
            if (!focused) {
              _focusedByPointer = false;
            }
            final showRing = focused && !_focusedByPointer;
            if (_isFocused != showRing) setState(() => _isFocused = showRing);
          },
          actions: isEnabled
              ? <Type, Action<Intent>>{
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      widget.onTap?.call();
                      return null;
                    },
                  ),
                }
              : const <Type, Action<Intent>>{},
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: () {
              if (isEnabled) {
                _focusedByPointer = true;
                if (_isFocused) setState(() => _isFocused = false);
                _focusNode.requestFocus();
              }
              widget.onTap?.call();
            },
            child: AnimatedContainer(
              duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
              constraints: const BoxConstraints(minHeight: 40.0),
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 3.0),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(9.0),
              ),
              foregroundDecoration: _isFocused
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(9.0),
                      border: Border.all(
                        color: theme.colors.focusBorderColor,
                        width: 2.0,
                      ),
                    )
                  : (theme.colors.isHighContrast &&
                          (widget.isSelected || _isHovered || _isPressed))
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(9.0),
                          border: Border.all(
                            color: theme.colors.borderColor,
                            width: 1.0,
                          ),
                        )
                      : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  SizedBox(
                    width: AdwMetrics.iconSizeSmall,
                    height: AdwMetrics.iconSizeSmall,
                    child: Center(
                      child: IconTheme(
                        data: IconThemeData(
                          color: effectiveFg,
                          size: AdwMetrics.iconSizeSmall,
                        ),
                        child: widget.icon!,
                      ),
                    ),
                  ),
                  const SizedBox(width: AdwMetrics.spacingMedium),
                ],
                Expanded(
                  child: DefaultTextStyle(
                    style: theme.typography.body.copyWith(
                      color: effectiveFg,
                      height: 1.0,
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: widget.title,
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

