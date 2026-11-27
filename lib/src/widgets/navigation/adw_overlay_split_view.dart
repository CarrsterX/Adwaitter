import 'package:flutter/widgets.dart';

import '../../core/adw_spring.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_theme.dart';
import '../layout/adw_window.dart';

/// Which side the sidebar is placed on in [AdwOverlaySplitView].
///
/// {@category Navigation}
enum AdwSplitViewPosition {
  /// Places the sidebar on the leading edge (left in LTR).
  start,

  /// Places the sidebar on the trailing edge (right in LTR).
  end,
}

/// Overlay / collapsible split view widget matching GNOME Libadwaita's
/// `AdwOverlaySplitView` with upstream [AdwSpringParams] physics.
///
/// Shows [sidebar] alongside [content] on wide screens and overlays it with a
/// dimming scrim on narrow screens (`width < collapseBreakpoint`).
///
/// ```dart
/// AdwOverlaySplitView(
///   showSidebar: isSidebarOpen,
///   sidebar: const AdwSidebar(sections: []),
///   content: const AdwStatusPage(title: Text('Main Content')),
///   onShowSidebarChanged: (open) {},
/// )
/// ```
///
/// See also:
///
/// * [AdwNavigationSplitView], for two-pane navigation that collapses into a stack.
/// * [AdwSplitViewPosition], controlling start vs end sidebar placement.
///
/// {@category Navigation}
class AdwOverlaySplitView extends StatefulWidget {
  /// Collapsible sidebar widget.
  final Widget sidebar;

  /// Main content widget displayed beside or underneath [sidebar].
  final Widget content;

  /// Whether the sidebar is currently revealed. Defaults to `true`.
  final bool showSidebar;

  /// Optional explicit override forcing overlay (`true`) or side-by-side (`false`).
  final bool? collapsed;

  /// Viewport width threshold below which the sidebar switches to overlay mode.
  /// Defaults to `400.0`.
  final double collapseBreakpoint;

  /// Width of the sidebar pane in logical pixels. Defaults to `240.0`.
  final double sidebarWidth;

  /// Edge on which the sidebar is anchored. Defaults to [AdwSplitViewPosition.start].
  final AdwSplitViewPosition sidebarPosition;

  /// Called when the user dismisses or toggles the overlay sidebar.
  final ValueChanged<bool>? onShowSidebarChanged;

  /// Creates an adaptive overlay split view.
  const AdwOverlaySplitView({
    super.key,
    required this.sidebar,
    required this.content,
    this.showSidebar = true,
    this.collapsed,
    this.collapseBreakpoint = 400.0,
    this.sidebarWidth = 240.0,
    this.sidebarPosition = AdwSplitViewPosition.start,
    this.onShowSidebarChanged,
  });

  @override
  State<AdwOverlaySplitView> createState() => _AdwOverlaySplitViewState();
}

class _AdwOverlaySplitViewState extends State<AdwOverlaySplitView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _lastCollapsed;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: widget.showSidebar ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant AdwOverlaySplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showSidebar != widget.showSidebar) {
      final target = widget.showSidebar ? 1.0 : 0.0;
      final resolved = AdwCurves.resolve(context, AdwCurves.normalDuration);
      if (resolved == Duration.zero) {
        _controller.value = target;
      } else {
        final simulation = AdwSpringParams.splitView.createSimulation(
          start: _controller.value,
          end: target,
          velocity: _controller.velocity,
        );
        _controller.animateWith(simulation);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final isWindowActive = AdwWindowScope.maybeOf(context)?.isActive ?? true;
    final effectiveSidebarBg = isWindowActive
        ? theme.colors.sidebarBackground
        : theme.colors.sidebarBackdropBackground;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCollapsed =
            widget.collapsed ?? (constraints.maxWidth < widget.collapseBreakpoint);
        if (_lastCollapsed != isCollapsed) {
          final isInitial = _lastCollapsed == null;
          _lastCollapsed = isCollapsed;
          if (isCollapsed && widget.showSidebar) {
            if (isInitial) {
              _controller.value = 0.0;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && widget.showSidebar) {
                widget.onShowSidebarChanged?.call(false);
              }
            });
          }
        }
        final isStart = widget.sidebarPosition == AdwSplitViewPosition.start;

        final sidebarPane = Container(
          width: widget.sidebarWidth,
          decoration: BoxDecoration(
            color: effectiveSidebarBg,
            border: BorderDirectional(
              start: isStart
                  ? BorderSide.none
                  : BorderSide(color: theme.colors.sidebarBorder, width: 1.0),
              end: isStart
                  ? BorderSide(color: theme.colors.sidebarBorder, width: 1.0)
                  : BorderSide.none,
            ),
          ),
          child: FocusTraversalGroup(
            child: widget.sidebar,
          ),
        );

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _controller.value.clamp(0.0, 1.0);

            if (!isCollapsed) {
              final animatedSidebar = ClipRect(
                child: Align(
                  alignment: isStart
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  widthFactor: progress,
                  child: sidebarPane,
                ),
              );

              final contentPane = Expanded(
                child: FocusTraversalGroup(child: widget.content),
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: isStart
                    ? [animatedSidebar, contentPane]
                    : [contentPane, animatedSidebar],
              );
            }

            final offset = (progress - 1.0) * widget.sidebarWidth;
            return Stack(
              children: [
                Positioned.fill(child: widget.content),
                if (progress > 0.0)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => widget.onShowSidebarChanged?.call(false),
                      child: ColoredBox(
                        color: Color.fromRGBO(0, 0, 0, 0.33 * progress),
                      ),
                    ),
                  ),
                if (progress > 0.0)
                  PositionedDirectional(
                    top: 0,
                    bottom: 0,
                    start: isStart ? offset : null,
                    end: !isStart ? offset : null,
                    width: widget.sidebarWidth,
                    child: sidebarPane,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

