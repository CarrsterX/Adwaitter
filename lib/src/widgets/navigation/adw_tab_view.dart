import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../controls/adw_button.dart';
import '../layout/adw_header_bar.dart';
import '../layout/adw_toolbar_view.dart';

/// Represents a single tab page managed by an [AdwTabViewController].
class AdwTabPage extends ChangeNotifier {
  String _title;
  String? _tooltip;
  Widget? _icon;
  bool _loading;
  Widget? _indicatorIcon;
  String? _indicatorTooltip;
  bool _indicatorActivates;
  bool _pinned;
  bool _needsAttention;
  Color? _thumbnailColor;
  Object? userData;
  final Widget child;
  final Key pageKey;

  AdwTabPage({
    Key? key,
    required String title,
    String? tooltip,
    Widget? icon,
    bool loading = false,
    Widget? indicatorIcon,
    String? indicatorTooltip,
    bool indicatorActivates = true,
    bool pinned = false,
    bool needsAttention = false,
    Color? thumbnailColor,
    this.userData,
    required this.child,
  })  : pageKey = key ?? UniqueKey(),
        _title = title,
        _tooltip = tooltip,
        _icon = icon,
        _loading = loading,
        _indicatorIcon = indicatorIcon,
        _indicatorTooltip = indicatorTooltip,
        _indicatorActivates = indicatorActivates,
        _pinned = pinned,
        _needsAttention = needsAttention,
        _thumbnailColor = thumbnailColor;

  String get title => _title;
  set title(String value) {
    if (_title == value) return;
    _title = value;
    notifyListeners();
  }

  String? get tooltip => _tooltip;
  set tooltip(String? value) {
    if (_tooltip == value) return;
    _tooltip = value;
    notifyListeners();
  }

  Widget? get icon => _icon;
  set icon(Widget? value) {
    if (_icon == value) return;
    _icon = value;
    notifyListeners();
  }

  bool get loading => _loading;
  set loading(bool value) {
    if (_loading == value) return;
    _loading = value;
    notifyListeners();
  }

  Widget? get indicatorIcon => _indicatorIcon;
  set indicatorIcon(Widget? value) {
    if (_indicatorIcon == value) return;
    _indicatorIcon = value;
    notifyListeners();
  }

  String? get indicatorTooltip => _indicatorTooltip;
  set indicatorTooltip(String? value) {
    if (_indicatorTooltip == value) return;
    _indicatorTooltip = value;
    notifyListeners();
  }

  bool get indicatorActivates => _indicatorActivates;
  set indicatorActivates(bool value) {
    if (_indicatorActivates == value) return;
    _indicatorActivates = value;
    notifyListeners();
  }

  bool get pinned => _pinned;
  set pinned(bool value) {
    if (_pinned == value) return;
    _pinned = value;
    notifyListeners();
  }

  bool get needsAttention => _needsAttention;
  set needsAttention(bool value) {
    if (_needsAttention == value) return;
    _needsAttention = value;
    notifyListeners();
  }

  Color? get thumbnailColor => _thumbnailColor;
  set thumbnailColor(Color? value) {
    if (_thumbnailColor == value) return;
    _thumbnailColor = value;
    notifyListeners();
  }
}

/// Controller for [AdwTabView], [AdwTabBar], [AdwTabButton], and [AdwTabOverview].
class AdwTabViewController extends ChangeNotifier {
  final List<AdwTabPage> _pages = <AdwTabPage>[];
  AdwTabPage? _selectedPage;

  /// Optional callback invoked when the last page is closed or detached.
  VoidCallback? onEmpty;

  /// Optional callback invoked when a tab's indicator button is clicked.
  void Function(AdwTabPage page)? onIndicatorActivated;

  /// Optional callback invoked when a tab is dragged out of the bar to create a new window.
  AdwTabViewController? Function(AdwTabPage page)? onCreateWindow;

  AdwTabViewController({
    List<AdwTabPage>? initialPages,
    this.onEmpty,
    this.onIndicatorActivated,
    this.onCreateWindow,
  }) {
    if (initialPages != null && initialPages.isNotEmpty) {
      for (final page in initialPages) {
        page.addListener(_onPageMutated);
        _pages.add(page);
      }
      _sortPinnedFirst();
      _selectedPage = _pages.first;
    }
  }

  @override
  void dispose() {
    for (final page in _pages) {
      page.removeListener(_onPageMutated);
    }
    super.dispose();
  }

  void _onPageMutated() {
    // Clear needsAttention if the selected page requests it? No, keep until selected or toggled
    notifyListeners();
  }

  List<AdwTabPage> get pages => List<AdwTabPage>.unmodifiable(_pages);

  List<AdwTabPage> get pinnedPages =>
      _pages.where((p) => p.pinned).toList(growable: false);

  List<AdwTabPage> get unpinnedPages =>
      _pages.where((p) => !p.pinned).toList(growable: false);

  int get nPages => _pages.length;

  int get nPinnedPages => _pages.where((p) => p.pinned).length;

  bool get anyNeedsAttention =>
      _pages.any((p) => p.needsAttention && p != _selectedPage);

  AdwTabPage? get selectedPage => _selectedPage;

  int get selectedIndex =>
      _selectedPage == null ? -1 : _pages.indexOf(_selectedPage!);

  void _sortPinnedFirst() {
    final pinned = _pages.where((p) => p.pinned).toList();
    final unpinned = _pages.where((p) => !p.pinned).toList();
    _pages
      ..clear()
      ..addAll(pinned)
      ..addAll(unpinned);
  }

  AdwTabPage addPage(AdwTabPage page, {bool select = true}) {
    page.addListener(_onPageMutated);
    if (page.pinned) {
      _pages.insert(nPinnedPages, page);
    } else {
      _pages.add(page);
    }
    if (select || _selectedPage == null) {
      _selectedPage = page;
    }
    notifyListeners();
    return page;
  }

  AdwTabPage insertPage(AdwTabPage page, int index, {bool select = true}) {
    page.addListener(_onPageMutated);
    final int minIdx = page.pinned ? 0 : nPinnedPages;
    final int maxIdx = page.pinned ? nPinnedPages : _pages.length;
    final int targetIdx = index.clamp(minIdx, maxIdx);
    _pages.insert(targetIdx, page);
    if (select || _selectedPage == null) {
      _selectedPage = page;
    }
    notifyListeners();
    return page;
  }

  void selectPage(AdwTabPage page) {
    if (!_pages.contains(page)) return;
    if (_selectedPage == page && !page.needsAttention) return;
    _selectedPage = page;
    if (page.needsAttention) {
      page.needsAttention = false;
    }
    notifyListeners();
  }

  void selectIndex(int index) {
    if (index < 0 || index >= _pages.length) return;
    selectPage(_pages[index]);
  }

  void selectNextPage() {
    if (_pages.length <= 1) return;
    final nextIdx = (selectedIndex + 1) % _pages.length;
    selectIndex(nextIdx);
  }

  void selectPreviousPage() {
    if (_pages.length <= 1) return;
    final prevIdx = (selectedIndex - 1 + _pages.length) % _pages.length;
    selectIndex(prevIdx);
  }

  void setPagePinned(AdwTabPage page, bool pinned) {
    if (!_pages.contains(page) || page.pinned == pinned) return;
    _pages.remove(page);
    page.pinned = pinned;
    if (pinned) {
      _pages.insert(nPinnedPages, page);
    } else {
      _pages.insert(nPinnedPages, page);
    }
    notifyListeners();
  }

  bool reorderPage(AdwTabPage page, int newIndex) {
    final oldIndex = _pages.indexOf(page);
    if (oldIndex == -1) return false;
    final int minIdx = page.pinned ? 0 : nPinnedPages;
    final int maxIdx = page.pinned ? nPinnedPages - 1 : _pages.length - 1;
    final int clamped = newIndex.clamp(minIdx, maxIdx);
    if (oldIndex == clamped) return false;
    _pages.removeAt(oldIndex);
    _pages.insert(clamped, page);
    notifyListeners();
    return true;
  }

  bool closePage(AdwTabPage page) {
    final idx = _pages.indexOf(page);
    if (idx == -1) return false;
    page.removeListener(_onPageMutated);
    _pages.removeAt(idx);
    if (_selectedPage == page) {
      if (_pages.isEmpty) {
        _selectedPage = null;
      } else {
        final nextIdx = math.min(idx, _pages.length - 1);
        _selectedPage = _pages[nextIdx];
      }
    }
    notifyListeners();
    if (_pages.isEmpty) {
      onEmpty?.call();
    }
    return true;
  }

  void closeOtherPages(AdwTabPage keepPage) {
    final toClose = _pages
        .where((p) => p != keepPage && !p.pinned)
        .toList(growable: false);
    for (final p in toClose) {
      p.removeListener(_onPageMutated);
      _pages.remove(p);
    }
    if (!_pages.contains(_selectedPage)) {
      _selectedPage = keepPage;
    }
    notifyListeners();
  }

  void closePagesBefore(AdwTabPage referencePage) {
    final refIdx = _pages.indexOf(referencePage);
    if (refIdx <= 0) return;
    final toClose = <AdwTabPage>[];
    for (int i = 0; i < refIdx; i++) {
      if (!_pages[i].pinned) {
        toClose.add(_pages[i]);
      }
    }
    for (final p in toClose) {
      p.removeListener(_onPageMutated);
      _pages.remove(p);
    }
    if (!_pages.contains(_selectedPage)) {
      _selectedPage = referencePage;
    }
    notifyListeners();
  }

  void closePagesAfter(AdwTabPage referencePage) {
    final refIdx = _pages.indexOf(referencePage);
    if (refIdx == -1 || refIdx >= _pages.length - 1) return;
    final toClose = <AdwTabPage>[];
    for (int i = refIdx + 1; i < _pages.length; i++) {
      if (!_pages[i].pinned) {
        toClose.add(_pages[i]);
      }
    }
    for (final p in toClose) {
      p.removeListener(_onPageMutated);
      _pages.remove(p);
    }
    if (!_pages.contains(_selectedPage)) {
      _selectedPage = referencePage;
    }
    notifyListeners();
  }

  /// Transfers [page] from this controller to [targetController] without
  /// losing its widget state.
  void transferPage(
    AdwTabPage page,
    AdwTabViewController targetController, {
    int? position,
  }) {
    if (targetController == this) return;
    final idx = _pages.indexOf(page);
    if (idx == -1) return;
    page.removeListener(_onPageMutated);
    _pages.removeAt(idx);
    if (_selectedPage == page) {
      _selectedPage = _pages.isEmpty
          ? null
          : _pages[math.min(idx, _pages.length - 1)];
    }
    notifyListeners();

    if (position != null) {
      targetController.insertPage(page, position, select: true);
    } else {
      targetController.addPage(page, select: true);
    }

    if (_pages.isEmpty) {
      onEmpty?.call();
    }
  }
}

/// Callback signature for building or showing a context menu for a tab page.
typedef AdwTabContextMenuCallback = void Function(
  BuildContext context,
  AdwTabPage page,
  Offset globalPosition,
);

/// Dynamic tabbed container widget (`AdwTabView`).
///
/// Displays the active [AdwTabPage] while preserving widget state across tabs
/// and handling standard GNOME keyboard shortcuts (`Ctrl+T`, `Ctrl+W`,
/// `Ctrl+Tab`, `Ctrl+Shift+Tab`, `Alt+1..9`).
class AdwTabView extends StatelessWidget {
  final AdwTabViewController controller;
  final VoidCallback? onNewTabShortcut;

  const AdwTabView({
    super.key,
    required this.controller,
    this.onNewTabShortcut,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final pages = controller.pages;
        final selectedIndex = controller.selectedIndex;

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            if (onNewTabShortcut != null)
              const SingleActivator(LogicalKeyboardKey.keyT, control: true):
                  onNewTabShortcut!,
            const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
              final current = controller.selectedPage;
              if (current != null && !current.pinned) {
                controller.closePage(current);
              }
            },
            const SingleActivator(LogicalKeyboardKey.tab, control: true):
                controller.selectNextPage,
            const SingleActivator(
              LogicalKeyboardKey.tab,
              control: true,
              shift: true,
            ): controller.selectPreviousPage,
            for (int i = 0; i < 9; i++)
              SingleActivator(
                LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
                alt: true,
              ): () => controller.selectIndex(i),
          },
          child: Focus(
            autofocus: true,
            child: pages.isEmpty
                ? const SizedBox.expand()
                : IndexedStack(
                    index: selectedIndex.clamp(0, pages.length - 1),
                    children: [
                      for (final page in pages)
                        KeyedSubtree(
                          key: page.pageKey,
                          child: page.child,
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// Horizontal tab bar widget (`AdwTabBar`) paired with an [AdwTabViewController].
///
/// Follows upstream Libadwaita CSS (`tabbar`, `tabbox`, `tab`):
/// - Pinned tabs compact on the left, unpinned tabs expanding to fill space.
/// - `tabbar tabbox { padding-top: 6px; padding-bottom: 6px; min-height: 34px; }`
/// - `tabbar tab { min-height: 26px; padding: 4px; border-radius: 9px; }`
/// - Middle-click to close, drag horizontally to reorder, drag vertically out
///   of the bar to detach into a new window (`controller.onCreateWindow`).
class AdwTabBar extends StatefulWidget {
  final AdwTabViewController controller;
  final Widget? startActionWidget;
  final Widget? endActionWidget;
  final bool autohide;
  final bool expandTabs;
  final bool inverted;
  final bool isInline;
  final AdwTabContextMenuCallback? onContextMenu;

  const AdwTabBar({
    super.key,
    required this.controller,
    this.startActionWidget,
    this.endActionWidget,
    this.autohide = true,
    this.expandTabs = true,
    this.inverted = false,
    this.isInline = true,
    this.onContextMenu,
  });

  @override
  State<AdwTabBar> createState() => _AdwTabBarState();
}

class _AdwTabBarState extends State<AdwTabBar> {
  int? _hoveredUnpinnedIndex;
  AdwTabPage? _draggingPage;
  double _dragAccumulatedDx = 0.0;
  double _dragStartGlobalY = 0.0;
  bool _detachedDuringDrag = false;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final duration = AdwCurves.resolve(context, AdwCurves.normalDuration);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final pinned = widget.controller.pinnedPages;
        final unpinned = widget.controller.unpinnedPages;
        final total = pinned.length + unpinned.length;
        final shouldShow =
            !widget.autohide || total > 1 || pinned.isNotEmpty;
        final isSingleTab = total == 1 && pinned.isEmpty;

        return ClipRect(
          child: AnimatedAlign(
            duration: duration,
            curve: AdwCurves.standard,
            alignment: Alignment.topCenter,
            heightFactor: shouldShow ? 1.0 : 0.0,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 38),
              decoration: widget.isInline
                  ? null
                  : BoxDecoration(
                      color: theme.colors.headerBarBackground,
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colors.dividerColor,
                          width: 1.0,
                        ),
                      ),
                    ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.startActionWidget != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: widget.startActionWidget!,
                    ),
                  // Pinned tabs box
                  if (pinned.isNotEmpty) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < pinned.length; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          _AdwTabItem(
                            page: pinned[i],
                            isSelected:
                                widget.controller.selectedPage == pinned[i],
                            isSingleTab: false,
                            inverted: widget.inverted,
                            onSelect: () =>
                                widget.controller.selectPage(pinned[i]),
                            onClose: () =>
                                widget.controller.closePage(pinned[i]),
                            onIndicatorTap: () => widget
                                .controller.onIndicatorActivated
                                ?.call(pinned[i]),
                            onContextMenu: widget.onContextMenu != null
                                ? (pos) => widget.onContextMenu!(
                                      context,
                                      pinned[i],
                                      pos,
                                    )
                                : null,
                          ),
                        ],
                      ],
                    ),
                    if (unpinned.isNotEmpty)
                      Container(
                        width: 1,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: theme.colors.dividerColor,
                      ),
                  ],
                  // Unpinned tabs box
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (unpinned.isEmpty) {
                          return const SizedBox(height: 32);
                        }
                        final count = unpinned.length;
                        final double rawTabWidth =
                            (constraints.maxWidth - (count - 1) * 3.0) / count;
                        final bool needsScroll = rawTabWidth < 130.0;
                        final double tabWidth = widget.expandTabs
                            ? rawTabWidth.clamp(130.0, 2000.0)
                            : rawTabWidth.clamp(130.0, 240.0);

                        final tabRow = Row(
                          mainAxisSize: widget.expandTabs && !needsScroll
                              ? MainAxisSize.max
                              : MainAxisSize.min,
                          children: [
                            for (int i = 0; i < unpinned.length; i++) ...[
                              if (i > 0)
                                _buildTabSeparator(
                                  theme: theme,
                                  leftPage: unpinned[i - 1],
                                  rightPage: unpinned[i],
                                  leftIndex: i - 1,
                                  rightIndex: i,
                                ),
                              if (widget.expandTabs && !needsScroll)
                                Expanded(
                                  child: _buildDraggableUnpinnedTab(
                                    context: context,
                                    page: unpinned[i],
                                    index: i,
                                    tabWidth: tabWidth,
                                    isSingleTab: isSingleTab,
                                  ),
                                )
                              else
                                SizedBox(
                                  width: tabWidth,
                                  child: _buildDraggableUnpinnedTab(
                                    context: context,
                                    page: unpinned[i],
                                    index: i,
                                    tabWidth: tabWidth,
                                    isSingleTab: isSingleTab,
                                  ),
                                ),
                            ],
                          ],
                        );

                        if (needsScroll) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: tabRow,
                          );
                        }
                        return tabRow;
                      },
                    ),
                  ),
                  if (widget.endActionWidget != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: widget.endActionWidget!,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabSeparator({
    required AdwThemeData theme,
    required AdwTabPage leftPage,
    required AdwTabPage rightPage,
    required int leftIndex,
    required int rightIndex,
  }) {
    final selected = widget.controller.selectedPage;
    final bool hidden = selected == leftPage ||
        selected == rightPage ||
        _hoveredUnpinnedIndex == leftIndex ||
        _hoveredUnpinnedIndex == rightIndex;
    return AnimatedOpacity(
      duration: AdwCurves.shortDuration,
      opacity: hidden ? 0.0 : 1.0,
      child: Container(
        width: 1,
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        color: theme.colors.dividerColor,
      ),
    );
  }

  Widget _buildDraggableUnpinnedTab({
    required BuildContext context,
    required AdwTabPage page,
    required int index,
    required double tabWidth,
    required bool isSingleTab,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        _draggingPage = page;
        _dragAccumulatedDx = 0.0;
        _dragStartGlobalY = details.globalPosition.dy;
        _detachedDuringDrag = false;
        widget.controller.selectPage(page);
      },
      onPanUpdate: (details) {
        if (_draggingPage != page || _detachedDuringDrag) return;
        final dyFromBar = (details.globalPosition.dy - _dragStartGlobalY).abs();
        if (dyFromBar > 52.0 &&
            widget.controller.nPages > 1 &&
            widget.controller.onCreateWindow != null) {
          _detachedDuringDrag = true;
          final targetController = widget.controller.onCreateWindow!(page);
          if (targetController != null) {
            widget.controller.transferPage(page, targetController);
          }
          return;
        }
        _dragAccumulatedDx += details.delta.dx;
        final step = math.max(80.0, tabWidth * 0.65);
        if (_dragAccumulatedDx.abs() >= step) {
          final deltaIdx = _dragAccumulatedDx > 0 ? 1 : -1;
          final currentIdx = widget.controller.pages.indexOf(page);
          if (currentIdx != -1) {
            final moved =
                widget.controller.reorderPage(page, currentIdx + deltaIdx);
            if (moved) {
              _dragAccumulatedDx = 0.0;
            }
          }
        }
      },
      onPanEnd: (_) {
        _draggingPage = null;
        _dragAccumulatedDx = 0.0;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredUnpinnedIndex = index),
        onExit: (_) {
          if (_hoveredUnpinnedIndex == index) {
            setState(() => _hoveredUnpinnedIndex = null);
          }
        },
        child: _AdwTabItem(
          page: page,
          isSelected: widget.controller.selectedPage == page,
          isSingleTab: isSingleTab,
          inverted: widget.inverted,
          onSelect: () => widget.controller.selectPage(page),
          onClose: () => widget.controller.closePage(page),
          onIndicatorTap: () =>
              widget.controller.onIndicatorActivated?.call(page),
          onContextMenu: widget.onContextMenu != null
              ? (pos) => widget.onContextMenu!(context, page, pos)
              : null,
        ),
      ),
    );
  }
}

class _AdwTabItem extends StatefulWidget {
  final AdwTabPage page;
  final bool isSelected;
  final bool isSingleTab;
  final bool inverted;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  final VoidCallback? onIndicatorTap;
  final void Function(Offset globalPosition)? onContextMenu;

  const _AdwTabItem({
    required this.page,
    required this.isSelected,
    required this.isSingleTab,
    required this.inverted,
    required this.onSelect,
    required this.onClose,
    this.onIndicatorTap,
    this.onContextMenu,
  });

  @override
  State<_AdwTabItem> createState() => _AdwTabItemState();
}

class _AdwTabItemState extends State<_AdwTabItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final fg = theme.colors.windowForeground;

    return ListenableBuilder(
      listenable: widget.page,
      builder: (context, _) {
        final Color bg;
        if (widget.isSingleTab) {
          bg = const Color(0x00000000);
        } else if (_isPressed) {
          bg = fg.withValues(alpha: widget.isSelected ? 0.19 : 0.16);
        } else if (widget.isSelected) {
          bg = fg.withValues(alpha: _isHovered ? 0.13 : 0.10);
        } else if (_isHovered) {
          bg = fg.withValues(alpha: 0.07);
        } else {
          bg = const Color(0x00000000);
        }

        final showClose =
            !widget.page.pinned && (_isHovered || widget.isSelected);

        return Listener(
          onPointerDown: (event) {
            if (event.buttons == kMiddleMouseButton && !widget.page.pinned) {
              widget.onClose();
            } else if (event.buttons == kSecondaryMouseButton) {
              widget.onContextMenu?.call(event.position);
            }
          },
          child: MouseRegion(
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
              onTap: widget.onSelect,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: AdwCurves.shortDuration,
                    curve: AdwCurves.standard,
                    constraints: BoxConstraints(
                      minHeight: 32,
                      minWidth: widget.page.pinned ? 36 : 80,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius:
                          BorderRadius.circular(AdwMetrics.buttonRadius),
                    ),
                    child: widget.page.pinned
                        ? _buildPinnedContent(fg)
                        : _buildUnpinnedContent(theme, fg, showClose),
                  ),
                  if (widget.page.needsAttention)
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: theme.colors.accentColor
                              .withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPinnedContent(Color fg) {
    Widget content;
    if (widget.page.loading) {
      content = _AdwMiniSpinner(color: fg);
    } else if (widget.page.indicatorIcon != null) {
      content = _buildIndicatorWidget(fg);
    } else if (widget.page.icon != null) {
      content = IconTheme(
        data: IconThemeData(size: 16, color: fg),
        child: widget.page.icon!,
      );
    } else {
      content = Text(
        widget.page.title.isEmpty ? '•' : widget.page.title.characters.first,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      );
    }
    return SizedBox(
      width: 28,
      height: 24,
      child: Center(child: content),
    );
  }

  Widget _buildUnpinnedContent(
    AdwThemeData theme,
    Color fg,
    bool showClose,
  ) {
    final Widget? leadingIcon;
    if (widget.page.loading) {
      leadingIcon = _AdwMiniSpinner(color: fg);
    } else if (widget.page.icon != null) {
      leadingIcon = IconTheme(
        data: IconThemeData(size: 16, color: fg),
        child: widget.page.icon!,
      );
    } else {
      leadingIcon = null;
    }

    final Widget? indicator = widget.page.indicatorIcon != null
        ? _buildIndicatorWidget(fg)
        : null;

    final Widget closeSlot = SizedBox(
      width: 24,
      height: 24,
      child: showClose
          ? _TabCircleIconButton(
              onTap: widget.onClose,
              child: CustomPaint(
                size: const Size(12, 12),
                painter: _TabCloseCrossPainter(color: fg),
              ),
            )
          : null,
    );

    final Widget leadingSlot = SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: widget.inverted
            ? closeSlot
            : (leadingIcon ?? const SizedBox.shrink()),
      ),
    );

    final Widget trailingSlot = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (indicator != null) indicator,
        if (widget.inverted)
          if (leadingIcon != null)
            SizedBox(width: 24, height: 24, child: Center(child: leadingIcon))
          else
            const SizedBox(width: 24, height: 24)
        else
          closeSlot,
      ],
    );

    return Row(
      children: [
        leadingSlot,
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              widget.page.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.typography.body.copyWith(
                fontSize: 13,
                fontWeight:
                    widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                color: widget.isSelected
                    ? fg
                    : fg.withValues(alpha: 0.82),
              ),
            ),
          ),
        ),
        trailingSlot,
      ],
    );
  }

  Widget _buildIndicatorWidget(Color fg) {
    final icon = IconTheme(
      data: IconThemeData(size: 16, color: fg),
      child: widget.page.indicatorIcon!,
    );
    if (!widget.page.indicatorActivates) {
      return SizedBox(width: 24, height: 24, child: Center(child: icon));
    }
    return _TabCircleIconButton(
      onTap: widget.onIndicatorTap,
      child: icon,
    );
  }
}

class _TabCircleIconButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final Color? backgroundColor;

  const _TabCircleIconButton({
    required this.onTap,
    required this.child,
    this.backgroundColor,
  });

  @override
  State<_TabCircleIconButton> createState() => _TabCircleIconButtonState();
}

class _TabCircleIconButtonState extends State<_TabCircleIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fg = AdwTheme.of(context).colors.windowForeground;
    final Color bg;
    if (widget.backgroundColor != null) {
      if (_pressed) {
        bg = Color.alphaBlend(fg.withValues(alpha: 0.20), widget.backgroundColor!);
      } else if (_hovered) {
        bg = Color.alphaBlend(fg.withValues(alpha: 0.10), widget.backgroundColor!);
      } else {
        bg = widget.backgroundColor!;
      }
    } else {
      if (_pressed) {
        bg = fg.withValues(alpha: 0.19);
      } else if (_hovered) {
        bg = fg.withValues(alpha: 0.10);
      } else {
        bg = const Color(0x00000000);
      }
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Companion header bar button (`AdwTabButton`) displaying the current open
/// tab count inside `adw-tab-counter-symbolic` and an optional attention badge.
class AdwTabButton extends StatelessWidget {
  final AdwTabViewController controller;
  final VoidCallback onPressed;

  const AdwTabButton({
    super.key,
    required this.controller,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final fg = theme.colors.windowForeground;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final count = controller.nPages;
        final isSmall = count >= 10;
        final labelText = count > 99 ? '∞' : '$count';
        final needsAttention = controller.anyNeedsAttention;

        return AdwButton.flat(
          width: 34,
          height: 34,
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(16, 16),
                painter: _TabCounterFramePainter(color: fg),
              ),
              Text(
                labelText,
                style: TextStyle(
                  fontFamily: theme.typography.body.fontFamily,
                  fontSize: isSmall ? 8.0 : 10.5,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: fg,
                ),
              ),
              if (needsAttention)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: theme.colors.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Full-window responsive grid overview for [AdwTabView] (`AdwTabOverview`).
class AdwTabOverview extends StatefulWidget {
  final AdwTabViewController controller;
  final bool open;
  final ValueChanged<bool> onOpenChanged;
  final bool enableNewTab;
  final VoidCallback? onCreateTab;
  final Widget? secondaryMenu;
  final AdwTabContextMenuCallback? onContextMenu;
  final Widget child;

  const AdwTabOverview({
    super.key,
    required this.controller,
    required this.open,
    required this.onOpenChanged,
    this.enableNewTab = true,
    this.onCreateTab,
    this.secondaryMenu,
    this.onContextMenu,
    required this.child,
  });

  @override
  State<AdwTabOverview> createState() => _AdwTabOverviewState();
}

class _AdwTabOverviewState extends State<AdwTabOverview> {
  bool _searchActive = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void didUpdateWidget(covariant AdwTabOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.open && oldWidget.open) {
      _searchActive = false;
      _searchQuery = '';
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (_searchActive) {
        _searchFocusNode.requestFocus();
      } else {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final duration = AdwCurves.resolve(context, AdwCurves.normalDuration);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Underlying normal window content
        IgnorePointer(
          ignoring: widget.open,
          child: AnimatedOpacity(
            duration: duration,
            curve: AdwCurves.standard,
            opacity: widget.open ? 0.0 : 1.0,
            child: widget.child,
          ),
        ),
        // Overview layer
        IgnorePointer(
          ignoring: !widget.open,
          child: AnimatedOpacity(
            duration: duration,
            curve: AdwCurves.standard,
            opacity: widget.open ? 1.0 : 0.0,
            child: AnimatedScale(
              duration: duration,
              curve: AdwCurves.standard,
              scale: widget.open ? 1.0 : 0.96,
              child: ColoredBox(
                color: theme.colors.windowBackground,
                child: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) {
                    final query = _searchQuery.trim().toLowerCase();
                    final pinned = widget.controller.pinnedPages
                        .where((p) =>
                            query.isEmpty ||
                            p.title.toLowerCase().contains(query))
                        .toList();
                    final unpinned = widget.controller.unpinnedPages
                        .where((p) =>
                            query.isEmpty ||
                            p.title.toLowerCase().contains(query))
                        .toList();

                    return AdwToolbarView(
                      topBar: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AdwHeaderBar(
                            isFlat: true,
                            start: AdwButton.flat(
                              width: 34,
                              height: 34,
                              padding: EdgeInsets.zero,
                              isChecked: _searchActive,
                              onPressed: _toggleSearch,
                              child: CustomPaint(
                                size: const Size(16, 16),
                                painter: _OverviewSearchIconPainter(
                                  color: theme.colors.windowForeground,
                                ),
                              ),
                            ),
                            title: const Text('Open Tabs'),
                            end: widget.secondaryMenu,
                          ),
                          if (_searchActive)
                            Container(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 400),
                                  child: Container(
                                    height: 34,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colors.windowForeground
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(
                                        AdwMetrics.entryRadius,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        CustomPaint(
                                          size: const Size(14, 14),
                                          painter: _OverviewSearchIconPainter(
                                            color:
                                                theme.colors.secondaryForeground,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: EditableText(
                                            controller: _searchController,
                                            focusNode: _searchFocusNode,
                                            style:
                                                theme.typography.body.copyWith(
                                              height: 1.0,
                                              leadingDistribution:
                                                  TextLeadingDistribution.even,
                                            ),
                                            cursorColor:
                                                theme.colors.accentColor,
                                            backgroundCursorColor:
                                                theme.colors.dividerColor,
                                            onChanged: (v) => setState(
                                              () => _searchQuery = v,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      content: Stack(
                        fit: StackFit.expand,
                        children: [
                          SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 84),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (pinned.isNotEmpty) ...[
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      for (final page in pinned)
                                        SizedBox(
                                          width: 140,
                                          height: 110,
                                          child: _AdwTabThumbnailCard(
                                            page: page,
                                            isSelected: widget
                                                    .controller.selectedPage ==
                                                page,
                                            onSelect: () {
                                              widget.controller
                                                  .selectPage(page);
                                              widget.onOpenChanged(false);
                                            },
                                            onCloseOrUnpin: () => widget
                                                .controller
                                                .setPagePinned(page, false),
                                            onIndicatorTap: () => widget
                                                .controller.onIndicatorActivated
                                                ?.call(page),
                                            onContextMenu:
                                                widget.onContextMenu != null
                                                    ? (pos) =>
                                                        widget.onContextMenu!(
                                                          context,
                                                          page,
                                                          pos,
                                                        )
                                                    : null,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final cols = math.max(
                                      1,
                                      (constraints.maxWidth / 220).floor(),
                                    );
                                    final cardWidth = (constraints.maxWidth -
                                            (cols - 1) * 16.0) /
                                        cols;
                                    final cardHeight = cardWidth * 0.78;

                                    return Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: [
                                        for (final page in unpinned)
                                          SizedBox(
                                            width: cardWidth,
                                            height: cardHeight,
                                            child: _AdwTabThumbnailCard(
                                              page: page,
                                              isSelected: widget.controller
                                                      .selectedPage ==
                                                  page,
                                              onSelect: () {
                                                widget.controller
                                                    .selectPage(page);
                                                widget.onOpenChanged(false);
                                              },
                                              onCloseOrUnpin: () => widget
                                                  .controller
                                                  .closePage(page),
                                              onIndicatorTap: () => widget
                                                  .controller
                                                  .onIndicatorActivated
                                                  ?.call(page),
                                              onContextMenu:
                                                  widget.onContextMenu != null
                                                      ? (pos) =>
                                                          widget.onContextMenu!(
                                                            context,
                                                            page,
                                                            pos,
                                                          )
                                                      : null,
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (widget.enableNewTab)
                            Positioned(
                              right: 18,
                              bottom: 18,
                              child: AdwButton.pill(
                                onPressed: () {
                                  widget.onCreateTab?.call();
                                  widget.onOpenChanged(false);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: CustomPaint(
                                    size: const Size(16, 16),
                                    painter: _PlusPainter(
                                      color: theme.colors.windowForeground,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdwTabThumbnailCard extends StatefulWidget {
  final AdwTabPage page;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onCloseOrUnpin;
  final VoidCallback? onIndicatorTap;
  final void Function(Offset globalPosition)? onContextMenu;

  const _AdwTabThumbnailCard({
    required this.page,
    required this.isSelected,
    required this.onSelect,
    required this.onCloseOrUnpin,
    this.onIndicatorTap,
    this.onContextMenu,
  });

  @override
  State<_AdwTabThumbnailCard> createState() => _AdwTabThumbnailCardState();
}

class _AdwTabThumbnailCardState extends State<_AdwTabThumbnailCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final fg = theme.colors.windowForeground;

    return ListenableBuilder(
      listenable: widget.page,
      builder: (context, _) {
        final previewColor =
            widget.page.thumbnailColor ?? theme.colors.cardBackground;
        final pillBg = previewColor.withValues(alpha: 0.78);

        return Listener(
          onPointerDown: (event) {
            if (event.buttons == kMiddleMouseButton && !widget.page.pinned) {
              widget.onCloseOrUnpin();
            } else if (event.buttons == kSecondaryMouseButton) {
              widget.onContextMenu?.call(event.position);
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: widget.onSelect,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? fg.withValues(alpha: 0.10)
                      : (_hovered
                          ? fg.withValues(alpha: 0.06)
                          : const Color(0x00000000)),
                  borderRadius: BorderRadius.circular(16),
                  border: widget.isSelected
                      ? Border.all(
                          color:
                              theme.colors.accentColor.withValues(alpha: 0.65),
                          width: 2,
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: previewColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: fg.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                widget.page.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.heading.copyWith(
                                  fontSize: 15,
                                  color: fg.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ),
                          if (widget.page.indicatorIcon != null)
                            Positioned(
                              left: 6,
                              top: 6,
                              child: _TabCircleIconButton(
                                backgroundColor: pillBg,
                                onTap: widget.page.indicatorActivates
                                    ? widget.onIndicatorTap
                                    : null,
                                child: IconTheme(
                                  data: IconThemeData(size: 14, color: fg),
                                  child: widget.page.indicatorIcon!,
                                ),
                              ),
                            ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: _TabCircleIconButton(
                              backgroundColor: pillBg,
                              onTap: widget.onCloseOrUnpin,
                              child: CustomPaint(
                                size: const Size(12, 12),
                                painter: widget.page.pinned
                                    ? _TabUnpinPainter(color: fg)
                                    : _TabCloseCrossPainter(color: fg),
                              ),
                            ),
                          ),
                          if (widget.page.needsAttention)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: theme.colors.accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.page.loading) ...[
                          _AdwMiniSpinner(color: fg),
                          const SizedBox(width: 6),
                        ] else if (widget.page.icon != null) ...[
                          IconTheme(
                            data: IconThemeData(size: 14, color: fg),
                            child: widget.page.icon!,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            widget.page.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: fg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdwMiniSpinner extends StatefulWidget {
  final Color color;

  const _AdwMiniSpinner({required this.color});

  @override
  State<_AdwMiniSpinner> createState() => _AdwMiniSpinnerState();
}

class _AdwMiniSpinnerState extends State<_AdwMiniSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: const Size(14, 14),
        painter: _SpinnerArcPainter(color: widget.color),
      ),
    );
  }
}

class _SpinnerArcPainter extends CustomPainter {
  final Color color;

  const _SpinnerArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    canvas.drawArc(rect.deflate(1.5), 0, math.pi * 2, false, track);
    canvas.drawArc(rect.deflate(1.5), -math.pi / 2, math.pi * 1.2, false, arc);
  }

  @override
  bool shouldRepaint(covariant _SpinnerArcPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TabCloseCrossPainter extends CustomPainter {
  final Color color;

  const _TabCloseCrossPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.22),
      Offset(size.width * 0.78, size.height * 0.78),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.22),
      Offset(size.width * 0.22, size.height * 0.78),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TabCloseCrossPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TabUnpinPainter extends CustomPainter {
  final Color color;

  const _TabUnpinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.36),
      size.width * 0.20,
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.56),
      Offset(size.width * 0.5, size.height * 0.86),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TabUnpinPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TabCounterFramePainter extends CustomPainter {
  final Color color;

  const _TabCounterFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 16.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(1.0 * u, 1.0 * u, 15.0 * u, 15.0 * u),
        Radius.circular(2.94 * u),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TabCounterFramePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _OverviewSearchIconPainter extends CustomPainter {
  final Color color;

  const _OverviewSearchIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width * 0.44, size.height * 0.44);
    canvas.drawCircle(center, size.width * 0.28, paint);
    canvas.drawLine(
      Offset(size.width * 0.65, size.height * 0.65),
      Offset(size.width * 0.88, size.height * 0.88),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _OverviewSearchIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PlusPainter extends CustomPainter {
  final Color color;

  const _PlusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.18),
      Offset(size.width * 0.5, size.height * 0.82),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.5),
      Offset(size.width * 0.82, size.height * 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PlusPainter oldDelegate) =>
      oldDelegate.color != color;
}

