import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';

import '../../theme/adw_theme.dart';
import '../layout/adw_window.dart';
import 'adw_navigation_view.dart';

/// Inherited scope exposed by [AdwNavigationSplitView] so descendant widgets
/// (such as sidebar items) can trigger content navigation when collapsed.
///
/// {@category Navigation}
class AdwNavigationSplitViewScope extends InheritedWidget {
  /// Whether the enclosing [AdwNavigationSplitView] is currently collapsed.
  final bool isCollapsed;

  /// Navigates to the content pane when collapsed.
  final VoidCallback showContentPage;

  /// Navigates back to the sidebar pane when collapsed.
  final VoidCallback showSidebarPage;

  /// Creates a navigation split view scope.
  const AdwNavigationSplitViewScope({
    super.key,
    required this.isCollapsed,
    required this.showContentPage,
    required this.showSidebarPage,
    required super.child,
  });

  /// Returns the nearest [AdwNavigationSplitViewScope], or `null` if absent.
  static AdwNavigationSplitViewScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdwNavigationSplitViewScope>();
  }

  @override
  bool updateShouldNotify(covariant AdwNavigationSplitViewScope oldWidget) {
    return isCollapsed != oldWidget.isCollapsed ||
        showContentPage != oldWidget.showContentPage ||
        showSidebarPage != oldWidget.showSidebarPage;
  }
}

/// Adaptive navigation split view (`AdwNavigationSplitView`).
///
/// Displays [sidebar] and [content] side by side when `width >= breakpoint`,
/// and automatically collapses into an [AdwNavigationView] stack on narrow
/// viewports with Libadwaita's predictive swipe-back gesture.
///
/// ```dart
/// const AdwNavigationSplitView(
///   sidebar: AdwSidebar(sections: []),
///   content: AdwToolbarView(
///     topBar: AdwHeaderBar(titleWidget: AdwWindowTitle(title: 'Content')),
///     content: AdwStatusPage(title: Text('Select an item')),
///   ),
/// )
/// ```
///
/// See also:
///
/// * [AdwOverlaySplitView], for an overlay/drawer-style sidebar split view.
/// * [AdwNavigationView], the underlying navigation stack used when collapsed.
///
/// {@category Navigation}
class AdwNavigationSplitView extends StatefulWidget {
  /// Navigation sidebar pane displayed on the start side.
  final Widget sidebar;

  /// Primary detail/content pane displayed on the end side.
  final Widget content;

  /// Optional fixed sidebar width override. When `null` (default), the sidebar
  /// width dynamically tracks [sidebarWidthFraction] of the available width,
  /// clamped between [minSidebarWidth] and [maxSidebarWidth] — matching
  /// upstream Libadwaita `AdwNavigationSplitView`.
  final double? sidebarWidth;

  /// Minimum sidebar width in logical pixels (upstream default: `180.0`).
  final double minSidebarWidth;

  /// Maximum sidebar width in logical pixels (upstream default: `280.0`).
  final double maxSidebarWidth;

  /// Fraction of total width allocated to the sidebar (upstream default: `0.25`).
  final double sidebarWidthFraction;

  /// Viewport width threshold below which the split view collapses into a
  /// single-pane navigation stack. Defaults to `540.0`.
  final double breakpoint;

  /// Optional explicit override forcing collapsed (`true`) or expanded (`false`).
  final bool? collapsed;

  /// Whether the sidebar pane is visible when expanded. Defaults to `true`.
  final bool showSidebar;

  /// Whether the content pane is initially pushed when collapsed. Defaults to `true`.
  final bool showContent;

  /// Whether to draw the 1px vertical separator between [sidebar] and [content].
  /// Defaults to `true`.
  final bool showBorder;

  /// Title assigned to the sidebar route when collapsed.
  final String sidebarTitle;

  /// Title assigned to the content route when collapsed.
  final String contentTitle;

  /// Creates an adaptive Libadwaita navigation split view.
  const AdwNavigationSplitView({
    super.key,
    required this.sidebar,
    required this.content,
    this.sidebarWidth,
    this.minSidebarWidth = 180.0,
    this.maxSidebarWidth = 280.0,
    this.sidebarWidthFraction = 0.25,
    this.breakpoint = 540.0,
    this.collapsed,
    this.showSidebar = true,
    this.showContent = true,
    this.showBorder = true,
    this.sidebarTitle = '',
    this.contentTitle = '',
  });

  @override
  State<AdwNavigationSplitView> createState() => _AdwNavigationSplitViewState();
}

class _AdwNavigationSplitViewState extends State<AdwNavigationSplitView> {
  final _SlotNotifier _slotNotifier = _SlotNotifier();
  AdwNavigationViewController? _collapsedNavController;
  late bool _preferContentOnCollapse;

  @override
  void initState() {
    super.initState();
    _preferContentOnCollapse = widget.showContent;
  }

  @override
  void didUpdateWidget(covariant AdwNavigationSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _slotNotifier.notify();
  }

  @override
  void dispose() {
    _collapsedNavController?.dispose();
    _slotNotifier.dispose();
    super.dispose();
  }

  AdwNavigationPage _buildSidebarPage() {
    return AdwNavigationPage(
      tag: 'sidebar',
      title: widget.sidebarTitle,
      canPop: true,
      child: AnimatedBuilder(
        animation: _slotNotifier,
        builder: (context, _) {
          final theme = AdwTheme.of(context);
          // When collapsed into a navigation stack page, Libadwaita uses standard
          // windowBackground rather than sidebarBackground.
          return ColoredBox(
            color: theme.colors.windowBackground,
            child: widget.sidebar,
          );
        },
      ),
    );
  }

  AdwNavigationPage _buildContentPage() {
    return AdwNavigationPage(
      tag: 'content',
      title: widget.contentTitle,
      canPop: true,
      onShown: () => _preferContentOnCollapse = true,
      onPopped: () => _preferContentOnCollapse = false,
      child: AnimatedBuilder(
        animation: _slotNotifier,
        builder: (context, _) {
          final theme = AdwTheme.of(context);
          return ColoredBox(
            color: theme.colors.windowBackground,
            child: widget.content,
          );
        },
      ),
    );
  }

  void _showContentPage() {
    _preferContentOnCollapse = true;
    final nav = _collapsedNavController;
    if (nav == null) return;
    if (nav.visiblePage?.tag != 'content') {
      nav.push(_buildContentPage());
    }
  }

  void _showSidebarPage() {
    final nav = _collapsedNavController;
    if (nav == null) return;
    if (nav.canPop) {
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final windowScope = AdwWindowScope.maybeOf(context);
    final isWindowActive = windowScope?.isActive ?? true;
    final bool isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final bool applyTop = windowScope?.applyTopSafeArea ?? true;
    final double bottomInset = windowScope?.bottomSafeInset ?? 0.0;
    final effectiveSidebarBg = isWindowActive
        ? theme.colors.sidebarBackground
        : theme.colors.sidebarBackdropBackground;

    Widget wrapPaneSafeArea(Widget child, {bool left = true, bool right = true}) {
      if (!isMobile) return child;
      return MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            top: applyTop,
            bottom: false,
            left: left,
            right: right,
            child: child,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isAutoCollapsed = constraints.maxWidth < widget.breakpoint;
        final isEffectiveCollapsed = widget.collapsed ?? isAutoCollapsed;

        if (isEffectiveCollapsed) {
          _collapsedNavController ??= AdwNavigationViewController();
          final sidebarPage = _buildSidebarPage();
          final initialPages = _preferContentOnCollapse
              ? <AdwNavigationPage>[sidebarPage, _buildContentPage()]
              : <AdwNavigationPage>[sidebarPage];

          return AdwNavigationSplitViewScope(
            isCollapsed: true,
            showContentPage: _showContentPage,
            showSidebarPage: _showSidebarPage,
            child: wrapPaneSafeArea(
              AdwNavigationView(
                key: const ValueKey('adw_split_collapsed_nav'),
                controller: _collapsedNavController,
                initialPage: sidebarPage,
                initialPages: initialPages,
              ),
            ),
          );
        }

        // Dispose collapsed controller when returning to expanded dual-pane layout
        if (_collapsedNavController != null) {
          _collapsedNavController!.dispose();
          _collapsedNavController = null;
        }

        final double computedSidebarWidth = widget.sidebarWidth ??
            (constraints.maxWidth * widget.sidebarWidthFraction)
                .clamp(widget.minSidebarWidth, widget.maxSidebarWidth);

        return AdwNavigationSplitViewScope(
          isCollapsed: false,
          showContentPage: () {},
          showSidebarPage: () {},
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showSidebar)
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1.0),
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) => _preferContentOnCollapse = false,
                      child: Container(
                        width: computedSidebarWidth +
                            (isMobile ? MediaQuery.paddingOf(context).left : 0.0),
                        decoration: BoxDecoration(
                          color: effectiveSidebarBg,
                          border: widget.showBorder
                              ? Border(
                                  right: BorderSide(
                                    color: theme.colors.sidebarBorder,
                                    width: 1,
                                  ),
                                )
                              : null,
                        ),
                        child: FocusTraversalGroup(
                          child: wrapPaneSafeArea(widget.sidebar, right: false),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(2.0),
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) => _preferContentOnCollapse = true,
                      child: Container(
                        color: theme.colors.windowBackground,
                        child: FocusTraversalGroup(
                          child: wrapPaneSafeArea(widget.content, left: false),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SlotNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
