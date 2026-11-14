import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_theme.dart';
import '../layout/adw_window.dart';

/// Which side the sidebar is placed on in [AdwOverlaySplitView].
enum AdwSplitViewPosition {
  start,
  end,
}

/// Overlay / collapsible split view widget matching GNOME Libadwaita's
/// `AdwOverlaySplitView`.
class AdwOverlaySplitView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final duration = AdwCurves.resolve(context, AdwCurves.shortDuration);
    final isWindowActive = AdwWindowScope.maybeOf(context)?.isActive ?? true;
    final effectiveSidebarBg = isWindowActive
        ? theme.colors.sidebarBackground
        : theme.colors.sidebarBackdropBackground;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCollapsed =
            collapsed ?? (constraints.maxWidth < collapseBreakpoint);
        final isStart = sidebarPosition == AdwSplitViewPosition.start;

        final sidebarPane = Container(
          width: sidebarWidth,
          decoration: BoxDecoration(
            color: effectiveSidebarBg,
            border: Border(
              left: isStart
                  ? BorderSide.none
                  : BorderSide(color: theme.colors.sidebarBorder, width: 1.0),
              right: isStart
                  ? BorderSide(color: theme.colors.sidebarBorder, width: 1.0)
                  : BorderSide.none,
            ),
          ),
          child: sidebar,
        );

        if (!isCollapsed) {
          final animatedSidebar = ClipRect(
            child: AnimatedAlign(
              duration: duration,
              curve: AdwCurves.standard,
              alignment: isStart ? Alignment.centerRight : Alignment.centerLeft,
              widthFactor: showSidebar ? 1.0 : 0.0,
              child: sidebarPane,
            ),
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: isStart
                ? [animatedSidebar, Expanded(child: content)]
                : [Expanded(child: content), animatedSidebar],
          );
        }

        return Stack(
          children: [
            Positioned.fill(child: content),
            if (showSidebar)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => onShowSidebarChanged?.call(false),
                  child: AnimatedContainer(
                    duration: duration,
                    color: const Color(0x55000000),
                  ),
                ),
              ),
            AnimatedPositioned(
              duration: duration,
              curve: AdwCurves.standard,
              top: 0,
              bottom: 0,
              left: isStart ? (showSidebar ? 0 : -sidebarWidth) : null,
              right: !isStart ? (showSidebar ? 0 : -sidebarWidth) : null,
              width: sidebarWidth,
              child: sidebarPane,
            ),
          ],
        );
      },
    );
  }
}

