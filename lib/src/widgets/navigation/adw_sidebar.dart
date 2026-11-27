import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/adw_insets.dart';
import '../../core/adw_scrollbar.dart';
import '../../theme/adw_theme.dart';
import 'adw_navigation_split_view.dart';

/// A declarative section of items inside an [AdwSidebar], matching GNOME
/// Libadwaita 1.9+'s `AdwSidebarSection`.
///
/// {@category Navigation}
class AdwSidebarSection {
  /// Optional muted section header displayed above [items].
  final String? title;

  /// Sidebar entries (typically [AdwSidebarItem] widgets) in this section.
  final List<Widget> items;

  /// Creates a named or unnamed sidebar section.
  const AdwSidebarSection({
    this.title,
    required this.items,
  });
}

/// Declarative navigation sidebar container matching GNOME Libadwaita 1.9+'s
/// `AdwSidebar`.
///
/// Renders grouped [sections] with optional section headers, subtle dividers
/// between sections, roving keyboard focus, and an integrated [AdwScrollbar].
///
/// ```dart
/// const AdwSidebar(
///   sections: [
///     AdwSidebarSection(
///       title: 'Library',
///       items: [
///         AdwSidebarItem(title: Text('Recent'), isSelected: true),
///         AdwSidebarItem(title: Text('Starred')),
///       ],
///     ),
///   ],
/// )
/// ```
///
/// See also:
///
/// * [AdwSidebarSection], which groups related sidebar items.
/// * [AdwSidebarItem], an individual selectable sidebar entry.
/// * [AdwNavigationSplitView], which commonly hosts [AdwSidebar].
///
/// {@category Navigation}
class AdwSidebar extends StatefulWidget {
  /// Ordered list of sections rendered in the sidebar.
  final List<AdwSidebarSection> sections;

  /// Optional external [ScrollController] for the sidebar list.
  final ScrollController? controller;

  /// Vertical scroll padding around the sidebar sections.
  final EdgeInsetsGeometry padding;

  /// Creates a declarative GNOME navigation sidebar.
  const AdwSidebar({
    super.key,
    required this.sections,
    this.controller,
    this.padding = const EdgeInsets.symmetric(vertical: 6.0),
  });

  @override
  State<AdwSidebar> createState() => _AdwSidebarState();
}

/// Keyboard focus group for navigation sidebars (`GtkListBox` roving focus).
///
/// Treats the entire sidebar list as a single `Tab` stop: pressing `Tab` exits
/// to the content pane, `Shift+Tab` returns to headerbar controls, and
/// `ArrowUp` / `ArrowDown` navigate between sidebar items with auto-scroll.
///
/// {@category Navigation}
class AdwSidebarFocusGroup extends StatefulWidget {
  /// Sidebar subtree participating in roving arrow-key focus traversal.
  final Widget child;

  /// Creates a roving-focus wrapper for navigation sidebars.
  const AdwSidebarFocusGroup({
    super.key,
    required this.child,
  });

  @override
  State<AdwSidebarFocusGroup> createState() => _AdwSidebarFocusGroupState();
}

class _AdwSidebarFocusGroupState extends State<AdwSidebarFocusGroup> {
  final FocusNode _sidebarFocusNode = FocusNode(debugLabel: 'AdwSidebar');
  FocusNode? _lastFocusedNode;

  @override
  void dispose() {
    _sidebarFocusNode.dispose();
    super.dispose();
  }

  void _moveFocusBy(int delta) {
    final nodes = _sidebarFocusNode.traversalDescendants
        .where((n) => n is! FocusScopeNode && n.canRequestFocus && !n.skipTraversal)
        .toList(growable: false);
    if (nodes.isEmpty) return;
    final currentIndex = nodes.indexWhere((n) => n.hasPrimaryFocus);
    final nextIndex = currentIndex < 0
        ? (delta > 0 ? 0 : nodes.length - 1)
        : (currentIndex + delta).clamp(0, nodes.length - 1);
    final target = nodes[nextIndex];
    _lastFocusedNode = target;
    target.requestFocus();
    if (target.context != null) {
      Scrollable.ensureVisible(
        target.context!,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: const Duration(milliseconds: 120),
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveFocusBy(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveFocusBy(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isCollapsed =
        AdwNavigationSplitViewScope.maybeOf(context)?.isCollapsed ?? false;

    final focusWrapper = Focus(
      focusNode: _sidebarFocusNode,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          final primary = FocusManager.instance.primaryFocus;
          if (primary != null &&
              primary.ancestors.contains(_sidebarFocusNode)) {
            _lastFocusedNode = primary;
          }
        }
      },
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );

    if (isCollapsed) {
      return focusWrapper;
    }

    return FocusTraversalGroup(
      policy: _AdwSidebarTraversalPolicy(
        getPreferredNode: () => _lastFocusedNode,
      ),
      child: focusWrapper,
    );
  }
}

/// Roving-tabindex [FocusTraversalPolicy] for [AdwSidebarFocusGroup].
///
/// Exposes only a single entry (the currently focused or last-focused sidebar
/// item) to outer `Tab` / `Shift+Tab` traversal so the entire sidebar acts as
/// one Tab stop, while `ArrowUp` / `ArrowDown` navigate between items.
class _AdwSidebarTraversalPolicy extends FocusTraversalPolicy
    with DirectionalFocusTraversalPolicyMixin {
  final FocusNode? Function() getPreferredNode;

  _AdwSidebarTraversalPolicy({required this.getPreferredNode});

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    final list = descendants.toList(growable: false);
    if (list.isEmpty) return const <FocusNode>[];
    if (list.contains(currentNode)) {
      return <FocusNode>[currentNode];
    }
    final preferred = getPreferredNode();
    if (preferred != null && list.contains(preferred)) {
      return <FocusNode>[preferred];
    }
    return <FocusNode>[list.first];
  }
}

class _AdwSidebarState extends State<AdwSidebar> {
  ScrollController? _internalController;

  ScrollController get _controller =>
      widget.controller ?? (_internalController ??= ScrollController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final bottomInset = adwBottomSystemInset(context);
    final resolvedPadding = widget.padding
        .resolve(Directionality.of(context))
        .add(EdgeInsets.only(bottom: bottomInset));

    final children = <Widget>[];
    for (int i = 0; i < widget.sections.length; i++) {
      final section = widget.sections[i];
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
            child: Container(
              height: 1.0,
              color: theme.colors.dividerColor,
            ),
          ),
        );
      }
      if (section.title != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(18.0, 8.0, 18.0, 4.0),
            child: Text(
              section.title!,
              style: theme.typography.sectionTitle.copyWith(
                color: theme.colors.secondaryForeground,
              ),
            ),
          ),
        );
      }
      children.addAll(section.items);
    }

    return AdwSidebarFocusGroup(
      child: AdwScrollbar(
        axisDirection: AxisDirection.down,
        controller: _controller,
        child: ListView(
          controller: _controller,
          padding: resolvedPadding,
          children: children,
        ),
      ),
    );
  }
}
