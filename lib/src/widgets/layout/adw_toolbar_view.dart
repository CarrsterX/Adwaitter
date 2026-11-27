import 'package:flutter/widgets.dart';

import '../../core/adw_insets.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_theme.dart';
import '../navigation/adw_carousel.dart';

/// Visual style for top/bottom bars in [AdwToolbarView] (`AdwToolbarStyle`).
///
/// {@category Layout}
enum AdwToolbarStyle {
  /// Flat bar with no background or border.
  flat,

  /// Raised bar with headerbar background, top border, and subtle shadow.
  raised,

  /// Raised bar with headerbar background and a crisp border without shadow.
  raisedBorder,
}

/// Structured toolbar and content layout container (`AdwToolbarView`).
///
/// Coordinates top bars (such as [AdwHeaderBar]), central scrollable content,
/// and optional bottom action bars in alignment with the Libadwaita 1.4+
/// architecture, including automatic scroll-under (`undershoot`) shadows.
///
/// ```dart
/// const AdwToolbarView(
///   topBar: AdwHeaderBar(
///     titleWidget: AdwWindowTitle(title: 'Inbox'),
///   ),
///   content: AdwStatusPage(title: Text('No messages')),
/// )
/// ```
///
/// See also:
///
/// * [AdwHeaderBar], typically passed as [topBar].
/// * [AdwToolbarStyle], controlling flat vs raised bar styling.
///
/// {@category Layout}
class AdwToolbarView extends StatefulWidget {
  /// Optional top bar widget (commonly [AdwHeaderBar] or a column containing
  /// [AdwHeaderBar] + [AdwSearchBar] / [AdwBanner]).
  final Widget? topBar;

  /// Main body content displayed between [topBar] and [bottomBar].
  final Widget content;

  /// Optional bottom bar widget (e.g. [AdwViewSwitcherBar] or an action bar).
  final Widget? bottomBar;

  /// Visual style applied to [topBar]. Defaults to [AdwToolbarStyle.flat].
  final AdwToolbarStyle topBarStyle;

  /// Visual style applied to [bottomBar]. Defaults to [AdwToolbarStyle.flat].
  final AdwToolbarStyle bottomBarStyle;

  /// Whether to render a scroll-undershoot shadow below [topBar] when content
  /// is scrolled past the top edge. Defaults to `true`.
  final bool topBarScrollShadow;

  /// Whether to render a scroll-undershoot shadow above [bottomBar] when
  /// content extends past the bottom edge. Defaults to `false`.
  final bool bottomBarScrollShadow;

  /// Whether [content] reserves bottom safe-area padding for the system navbar
  /// when [bottomBar] is absent. Set to `false` for scrollable pages that
  /// should scroll edge-to-edge behind a transparent system navigation bar.
  final bool bottomSafeArea;

  /// Creates a Libadwaita toolbar-and-content view.
  const AdwToolbarView({
    super.key,
    this.topBar,
    required this.content,
    this.bottomBar,
    this.topBarStyle = AdwToolbarStyle.flat,
    this.bottomBarStyle = AdwToolbarStyle.flat,
    this.topBarScrollShadow = true,
    this.bottomBarScrollShadow = false,
    this.bottomSafeArea = true,
  });

  @override
  State<AdwToolbarView> createState() => _AdwToolbarViewState();
}

class _AdwToolbarViewState extends State<AdwToolbarView> {
  bool _isScrolledUnderTop = false;
  bool _isScrolledUnderBottom = false;

  @override
  void didUpdateWidget(covariant AdwToolbarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content.key != oldWidget.content.key) {
      _isScrolledUnderTop = false;
      _isScrolledUnderBottom = false;
    }
  }

  bool _isFromCarousel(BuildContext? notificationContext) {
    if (notificationContext == null) return false;
    return notificationContext.findAncestorWidgetOfExactType<AdwCarousel>() !=
        null;
  }

  void _updateFromMetrics(ScrollMetrics metrics, BuildContext? notifContext) {
    if (metrics.axis != Axis.vertical) return;
    if (_isFromCarousel(notifContext)) return;

    final bool underTop = metrics.pixels > 0.5;
    final bool underBottom = metrics.maxScrollExtent - metrics.pixels > 0.5;

    if (underTop != _isScrolledUnderTop ||
        underBottom != _isScrolledUnderBottom) {
      setState(() {
        _isScrolledUnderTop = underTop;
        _isScrolledUnderBottom = underBottom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final Color shadeColor = theme.colors.toolbarShadeColor;
    final Color shadeTransparent = theme.colors.shadeTransparent;

    Widget body = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _updateFromMetrics(notification.metrics, notification.context);
        return false;
      },
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          _updateFromMetrics(notification.metrics, notification.context);
          return false;
        },
        child: widget.content,
      ),
    );

    if (widget.topBar != null || widget.bottomBar != null) {
      body = Stack(
        children: [
          Positioned.fill(child: body),
          if (widget.topBar != null &&
              widget.topBarScrollShadow &&
              theme.colors.isHighContrast &&
              _isScrolledUnderTop)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 1.0,
                  color: theme.colors.borderColor,
                ),
              ),
            ),
          if (widget.topBar != null && widget.topBarScrollShadow)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
                  curve: AdwCurves.standard,
                  opacity: _isScrolledUnderTop ? 1.0 : 0.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(height: 1, color: shadeColor),
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [shadeColor, shadeTransparent],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (widget.bottomBar != null && widget.bottomBarScrollShadow)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
                  curve: AdwCurves.standard,
                  opacity: _isScrolledUnderBottom ? 1.0 : 0.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [shadeColor, shadeTransparent],
                          ),
                        ),
                      ),
                      Container(height: 1, color: shadeColor),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    Widget? resolvedTopBar = widget.topBar;
    if (resolvedTopBar != null &&
        widget.topBarStyle != AdwToolbarStyle.flat) {
      final raisedShade = shadeColor.withValues(alpha: shadeColor.a * 0.5);
      resolvedTopBar = Container(
        decoration: BoxDecoration(
          color: theme.colors.headerBarBackground,
          border: widget.topBarStyle == AdwToolbarStyle.raisedBorder
              ? Border(
                  bottom: BorderSide(color: shadeColor, width: 1.0),
                )
              : null,
          boxShadow: widget.topBarStyle == AdwToolbarStyle.raised
              ? [
                  BoxShadow(
                    color: raisedShade,
                    blurRadius: 0.0,
                    offset: const Offset(0, 1),
                  ),
                  BoxShadow(
                    color: raisedShade,
                    blurRadius: 4.0,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: resolvedTopBar,
      );
    }

    Widget? resolvedBottomBar = widget.bottomBar;
    if (resolvedBottomBar != null &&
        widget.bottomBarStyle != AdwToolbarStyle.flat) {
      final raisedShade = shadeColor.withValues(alpha: shadeColor.a * 0.5);
      resolvedBottomBar = Container(
        decoration: BoxDecoration(
          color: theme.colors.headerBarBackground,
          border: widget.bottomBarStyle == AdwToolbarStyle.raisedBorder
              ? Border(
                  top: BorderSide(color: shadeColor, width: 1.0),
                )
              : null,
          boxShadow: widget.bottomBarStyle == AdwToolbarStyle.raised
              ? [
                  BoxShadow(
                    color: raisedShade,
                    blurRadius: 0.0,
                    offset: const Offset(0, -1),
                  ),
                  BoxShadow(
                    color: raisedShade,
                    blurRadius: 4.0,
                    offset: const Offset(0, -2),
                  ),
                ]
              : null,
        ),
        child: resolvedBottomBar,
      );
    }

    // Paint topBar last (VerticalDirection.up) so raised headerbar shadows
    // cast cleanly onto the content area below it, while preserving logical
    // top -> content -> bottom keyboard Tab order.
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        verticalDirection: VerticalDirection.up,
        children: [
          if (resolvedBottomBar != null)
            FocusTraversalOrder(
              order: const NumericFocusOrder(3.0),
              child: _BottomInsetPadding(child: resolvedBottomBar),
            ),
          Expanded(
            child: FocusTraversalOrder(
              order: const NumericFocusOrder(2.0),
              child: (widget.bottomBar == null && widget.bottomSafeArea)
                  ? _BottomInsetPadding(child: body)
                  : body,
            ),
          ),
          if (resolvedTopBar != null)
            FocusTraversalOrder(
              order: const NumericFocusOrder(1.0),
              child: resolvedTopBar,
            ),
        ],
      ),
    );
  }
}


/// Reserves the system navigation bar inset below [child] and marks it as
/// consumed so nested widgets do not pad twice.
class _BottomInsetPadding extends StatelessWidget {
  final Widget child;

  const _BottomInsetPadding({required this.child});

  @override
  Widget build(BuildContext context) {
    final double inset = adwBottomSystemInset(context);
    if (inset <= 0.0) return child;
    final data = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: MediaQuery(
        data: data.copyWith(
          padding: data.padding.copyWith(bottom: 0.0),
          viewPadding: data.viewPadding.copyWith(bottom: 0.0),
        ),
        child: child,
      ),
    );
  }
}
