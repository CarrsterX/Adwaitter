import 'package:flutter/widgets.dart';

import '../../core/adw_spring.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_theme.dart';
import '../layout/adw_window.dart';

/// Which side the sidebar is placed on in [AdwOverlaySplitView].
enum AdwSplitViewPosition {
  start,
  end,
}

/// Overlay / collapsible split view widget matching GNOME Libadwaita's
/// `AdwOverlaySplitView` with upstream `AdwSpringAnimation` physics.
class AdwOverlaySplitView extends StatefulWidget {
  final Widget sidebar;
  final Widget content;
  final bool showSidebar;
  final bool? collapsed;
  final double collapseBreakpoint;
  final double sidebarWidth;
  final AdwSplitViewPosition sidebarPosition;
  final ValueChanged<bool>? onShowSidebarChanged;

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

