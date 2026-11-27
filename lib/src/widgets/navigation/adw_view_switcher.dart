import 'package:flutter/widgets.dart';

import '../../core/adw_insets.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';

/// Layout policy for [AdwViewSwitcher] tabs, matching `AdwViewSwitcherPolicy`.
///
/// {@category Navigation}
enum AdwViewSwitcherPolicy {
  /// Icon and label side-by-side (used in wide header bars).
  wide,

  /// Icon stacked above a compact label (used in narrow bars / [AdwViewSwitcherBar]).
  narrow,
}

/// Item descriptor for [AdwViewSwitcher] and [AdwViewSwitcherBar].
///
/// {@category Navigation}
class AdwViewSwitcherItem {
  /// Optional symbolic icon displayed for this tab.
  final Widget? icon;

  /// Display label for this tab.
  final String title;

  /// Optional custom badge widget rendered over the icon.
  final Widget? badge;

  /// Optional numeric counter rendered as a pill badge when `> 0`.
  final int? badgeNumber;

  /// Whether to show a subtle accent attention dot on this tab. Defaults to `false`.
  final bool needsAttention;

  /// Creates a view switcher tab descriptor.
  const AdwViewSwitcherItem({
    this.icon,
    required this.title,
    this.badge,
    this.badgeNumber,
    this.needsAttention = false,
  });
}

/// Segmented view switcher control (`AdwViewSwitcher`) matching Libadwaita 1.10.
///
/// Renders a homogeneous row of flat toggle tabs with optional indicator badges
/// ([AdwViewSwitcherItem.badgeNumber] / [AdwViewSwitcherItem.needsAttention])
/// and [AdwViewSwitcherPolicy.wide] or [AdwViewSwitcherPolicy.narrow] layouts.
///
/// ```dart
/// AdwViewSwitcher(
///   currentIndex: selectedTab,
///   onIndexChanged: (i) {},
///   items: const [
///     AdwViewSwitcherItem(title: 'World'),
///     AdwViewSwitcherItem(title: 'Alarms'),
///   ],
/// )
/// ```
///
/// See also:
///
/// * [AdwViewSwitcherBar], the bottom-bar counterpart for narrow screens.
/// * [AdwViewSwitcherItem], describing each tab.
///
/// {@category Navigation}
class AdwViewSwitcher extends StatelessWidget {
  /// Ordered list of tabs displayed in the switcher.
  final List<AdwViewSwitcherItem> items;

  /// Zero-based index of the currently active tab.
  final int currentIndex;

  /// Callback invoked when the user selects a different tab index.
  final ValueChanged<int> onIndexChanged;

  /// Tab layout policy (`wide` or `narrow`). Defaults to [AdwViewSwitcherPolicy.wide].
  final AdwViewSwitcherPolicy policy;

  /// Creates a Libadwaita header-bar view switcher.
  const AdwViewSwitcher({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onIndexChanged,
    this.policy = AdwViewSwitcherPolicy.wide,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: _ViewSwitcherTab(
                item: items[i],
                isSelected: i == currentIndex,
                policy: policy,
                onTap: () => onIndexChanged(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom view switcher bar (`AdwViewSwitcherBar`) revealed on narrow widths.
///
/// Typically placed in [AdwToolbarView.bottomBar] and revealed when the viewport
/// becomes too narrow for an [AdwViewSwitcher] in the header bar.
///
/// {@category Navigation}
class AdwViewSwitcherBar extends StatelessWidget {
  /// Ordered list of tabs displayed in the bottom bar.
  final List<AdwViewSwitcherItem> items;

  /// Zero-based index of the currently active tab.
  final int currentIndex;

  /// Callback invoked when the user taps a tab.
  final ValueChanged<int> onIndexChanged;

  /// Whether the bottom bar is animated into view. Defaults to `true`.
  final bool reveal;

  /// Whether the bar uses flat styling (`true`) or a raised surface (`false`).
  /// Defaults to `true`.
  final bool isFlat;

  /// Creates a Libadwaita bottom view switcher bar.
  const AdwViewSwitcherBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onIndexChanged,
    this.reveal = true,
    this.isFlat = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final duration = AdwCurves.resolve(context, AdwCurves.normalDuration);
    final double bottomSafeInset =
        reveal ? (adwBottomSystemInset(context)) : 0.0;

    return ClipRect(
      child: AnimatedAlign(
        duration: duration,
        curve: AdwCurves.standard,
        alignment: Alignment.topCenter,
        heightFactor: reveal ? 1.0 : 0.0,
        child: Container(
          width: double.infinity,
          decoration: isFlat
              ? null
              : BoxDecoration(
                  color: theme.colors.headerBarBackground,
                  border: Border(
                    top: BorderSide(
                      color: theme.colors.dividerColor,
                      width: 1.0,
                    ),
                  ),
                ),
          padding: EdgeInsets.fromLTRB(8, 6, 8, 6 + bottomSafeInset),
          child: AdwBottomInsetConsumer(
 child: Row(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: _ViewSwitcherTab(
                      item: items[i],
                      isSelected: i == currentIndex,
                      policy: AdwViewSwitcherPolicy.narrow,
                      onTap: () => onIndexChanged(i),
                    ),
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

class _ViewSwitcherTab extends StatefulWidget {
  final AdwViewSwitcherItem item;
  final bool isSelected;
  final AdwViewSwitcherPolicy policy;
  final VoidCallback onTap;

  const _ViewSwitcherTab({
    required this.item,
    required this.isSelected,
    required this.policy,
    required this.onTap,
  });

  @override
  State<_ViewSwitcherTab> createState() => _ViewSwitcherTabState();
}

class _ViewSwitcherTabState extends State<_ViewSwitcherTab> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final fg = theme.colors.windowForeground;

    // Flat toggle button colors matching _buttons.scss ($selected_color = 10%)
    final Color backgroundColor;
    if (_isPressed) {
      backgroundColor = fg.withValues(alpha: widget.isSelected ? 0.19 : 0.16);
    } else if (widget.isSelected) {
      backgroundColor =
          fg.withValues(alpha: (_isHovered || _isFocused) ? 0.13 : 0.10);
    } else if (_isHovered || _isFocused) {
      backgroundColor = fg.withValues(alpha: 0.07);
    } else {
      backgroundColor = const Color(0x00000000);
    }

    final contentColor = widget.isSelected ? fg : fg.withValues(alpha: 0.85);

    Widget? iconWithBadge;
    if (widget.item.icon != null) {
      final iconWidget = IconTheme(
        data: IconThemeData(
          size: 16,
          color: contentColor,
        ),
        child: widget.item.icon!,
      );
      final badgeNum = widget.item.badgeNumber ?? 0;
      if (widget.item.badge != null ||
          badgeNum > 0 ||
          widget.item.needsAttention) {
        iconWithBadge = Stack(
          clipBehavior: Clip.none,
          children: [
            iconWidget,
            if (widget.item.badge != null)
              Positioned(right: -8, top: -4, child: widget.item.badge!)
            else if (badgeNum > 0)
              Positioned(
                right: -9,
                top: -5,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colors.accentColor,
                    borderRadius: BorderRadius.circular(AdwMetrics.pillRadius),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$badgeNum',
                    style: TextStyle(
                      fontFamily: theme.typography.body.fontFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: theme.colors.accentForeground,
                      height: 1.1,
                    ),
                  ),
                ),
              )
            else if (widget.item.needsAttention)
              Positioned(
                right: -4,
                top: -2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.colors.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      } else {
        iconWithBadge = iconWidget;
      }
    }

    final isWide = widget.policy == AdwViewSwitcherPolicy.wide;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (hovered) {
          if (_isHovered != hovered) setState(() => _isHovered = hovered);
        },
        onShowFocusHighlight: (focused) {
          if (_isFocused != focused) setState(() => _isFocused = focused);
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
            curve: AdwCurves.standard,
            constraints: BoxConstraints(minHeight: isWide ? 34 : 36),
            decoration: BoxDecoration(
              color: backgroundColor,
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
          padding: isWide
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 2)
              : const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: isWide
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (iconWithBadge != null) ...[
                      iconWithBadge,
                      const SizedBox(width: 6),
                    ],
                    Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.heading.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: contentColor,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (iconWithBadge != null) iconWithBadge,
                    const SizedBox(height: 1),
                    Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: contentColor,
                      ),
                    ),
                  ],
                ),
        ),
      ),
      ),
    );
  }
}
