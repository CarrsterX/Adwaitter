import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/adw_spring.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import 'adw_dialog.dart';

/// Inherited scope provided by [AdwBottomSheet] to its [sheet] subtree so
/// descendant [AdwHeaderBar]s suppress their title when a drag handle is shown
/// and display a close button wired to the sheet.
class AdwBottomSheetScope extends InheritedWidget {
  final bool hideTitle;
  final bool canClose;
  final VoidCallback close;

  const AdwBottomSheetScope({
    super.key,
    required this.hideTitle,
    required this.canClose,
    required this.close,
    required super.child,
  });

  static AdwBottomSheetScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdwBottomSheetScope>();
  }

  @override
  bool updateShouldNotify(covariant AdwBottomSheetScope oldWidget) {
    return hideTitle != oldWidget.hideTitle ||
        canClose != oldWidget.canClose ||
        close != oldWidget.close;
  }
}

/// Persistent or modal bottom sheet with an optional bottom bar, matching
/// GNOME Libadwaita's `AdwBottomSheet`.
///
/// Displays [content] persistently, [bottomBar] along the bottom edge when
/// closed, and [sheet] above [content] when opened via tap, vertical drag
/// (mouse click-and-drag or touch), or [open].
class AdwBottomSheet extends StatefulWidget {
  /// Persistent background content.
  final Widget content;

  /// Content displayed inside the expanded bottom sheet.
  final Widget sheet;

  /// Optional bar displayed along the bottom edge when the sheet is closed.
  final Widget? bottomBar;

  /// Controlled open state. When `null`, [AdwBottomSheet] manages its own
  /// open/closed state starting from [initialOpen].
  final bool? open;

  /// Initial open state when [open] is `null`.
  final bool initialOpen;

  /// Called when the sheet is opened or closed by user interaction.
  final ValueChanged<bool>? onOpenChanged;

  /// Horizontal alignment along the bottom edge when [fullWidth] is `false`.
  final double align;

  /// Maximum width of the sheet when [fullWidth] is `false`.
  final double? maxWidth;

  /// Whether the sheet spans the full available width.
  final bool fullWidth;

  /// Whether to show the overlaid drag-handle pill at the top of the sheet.
  final bool showDragHandle;

  /// Whether opening the sheet dims [content] and blocks pointer events to it.
  final bool modal;

  /// Whether user interactions can open the sheet.
  final bool canOpen;

  /// Whether user interactions can close the sheet.
  final bool canClose;

  /// Whether [bottomBar] is revealed when the sheet is closed.
  final bool revealBottomBar;

  /// Preferred height of [bottomBar] when revealed (defaults to `46.0` px,
  /// matching GNOME Libadwaita's standard `.toolbar` bottom bar).
  final double bottomBarHeight;

  /// Optional preferred height of [sheet] when expanded. When `null`, expands
  /// up to the available height minus adaptive top padding.
  final double? sheetHeight;

  const AdwBottomSheet({
    super.key,
    required this.content,
    required this.sheet,
    this.bottomBar,
    this.open,
    this.initialOpen = false,
    this.onOpenChanged,
    this.align = 0.5,
    this.maxWidth,
    this.fullWidth = true,
    this.showDragHandle = true,
    this.modal = true,
    this.canOpen = true,
    this.canClose = true,
    this.revealBottomBar = true,
    this.bottomBarHeight = 46.0,
    this.sheetHeight,
  });

  @override
  State<AdwBottomSheet> createState() => _AdwBottomSheetState();
}

class _AdwBottomSheetState extends State<AdwBottomSheet>
    with SingleTickerProviderStateMixin {
  static const double _topPaddingMinHeight = 720.0;
  static const double _topPaddingMinValue = 30.0;
  static const double _topPaddingTargetHeight = 1440.0;
  static const double _topPaddingTargetValue = 120.0;
  static const double _childSwitchThreshold = 0.15;

  late final AnimationController _controller;
  late bool _isOpen;
  bool _isDragging = false;
  bool _isBottomBarHovered = false;
  bool _isBottomBarPressed = false;
  double _lastTravelDistance = 400.0;
  double _rawDragProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _isOpen = widget.open ?? widget.initialOpen;
    _controller = AnimationController(
      lowerBound: -0.2,
      upperBound: 1.5,
      value: _isOpen ? 1.0 : 0.0,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant AdwBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != null && widget.open != _isOpen) {
      _setOpen(widget.open!, notify: false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setOpen(bool nextOpen, {double velocity = 0.0, bool notify = true}) {
    final target = nextOpen ? 1.0 : 0.0;
    if (_isOpen == nextOpen &&
        !_isDragging &&
        (_controller.value - target).abs() < 0.0001 &&
        !_controller.isAnimating) {
      return;
    }
    _isOpen = nextOpen;
    if (notify) {
      widget.onOpenChanged?.call(nextOpen);
    }

    final reduceMotion =
        AdwCurves.resolve(context, AdwCurves.shortDuration) == Duration.zero;

    if (reduceMotion) {
      _controller.value = target;
      return;
    }

    final sim = AdwSpringParams.bottomSheet.createSimulation(
      start: _controller.value,
      end: target,
      velocity: velocity,
    );
    _controller.animateWith(sim).whenComplete(() {
      if (mounted && !_isDragging) {
        _controller.value = target;
      }
    });
  }

  double _adjustForOvershoot(double amount) {
    final d = math.max(1.0, _lastTravelDistance * 0.1);
    return (1.0 - 1.0 / (1.0 + amount * d)) / d;
  }

  void _handleDragStart(DragStartDetails details) {
    if (_isOpen && !widget.canClose) return;
    if (!_isOpen && !(widget.canOpen && widget.bottomBar != null)) return;
    _controller.stop();
    setState(() {
      _isDragging = true;
      _isBottomBarPressed = false;
      _rawDragProgress = _controller.value;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final travel = math.max(1.0, _lastTravelDistance);
    final delta = -details.delta.dy / travel;
    _rawDragProgress += delta;

    double effectiveProgress = _rawDragProgress;
    if (effectiveProgress < 0.0) {
      if (widget.bottomBar != null) {
        effectiveProgress = -_adjustForOvershoot(-effectiveProgress);
      } else {
        effectiveProgress = _rawDragProgress = 0.0;
      }
    } else if (effectiveProgress > 1.0) {
      effectiveProgress = 1.0 + _adjustForOvershoot(effectiveProgress - 1.0);
    }

    _controller.value = effectiveProgress.clamp(-0.2, 1.5);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    setState(() => _isDragging = false);
    final travel = math.max(1.0, _lastTravelDistance);
    double velocity = -details.velocity.pixelsPerSecond.dy / travel;

    if (_rawDragProgress < 0.0 && widget.bottomBar != null) {
      final overshoot = -_rawDragProgress;
      if (overshoot > 0.0) {
        velocity *= _adjustForOvershoot(overshoot) / overshoot;
      }
    } else if (_rawDragProgress > 1.0) {
      final overshoot = _rawDragProgress - 1.0;
      if (overshoot > 0.0) {
        velocity *= _adjustForOvershoot(overshoot) / overshoot;
      }
    }

    final bool targetOpen;
    if (velocity > 0.8) {
      targetOpen = widget.canOpen;
    } else if (velocity < -0.8) {
      targetOpen = !widget.canClose;
    } else {
      targetOpen = _controller.value >= 0.5;
    }
    _setOpen(targetOpen, velocity: velocity);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final hasBottomBar = widget.bottomBar != null && widget.revealBottomBar;
    final effectiveBottomBarHeight = hasBottomBar ? widget.bottomBarHeight : 0.0;

    return CallbackShortcuts(
      bindings: {
        if (_isOpen && widget.canClose)
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              _setOpen(false),
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          final topPadding = _topPaddingMinValue +
              (_topPaddingTargetValue - _topPaddingMinValue) *
                  ((height - _topPaddingMinHeight) /
                          (_topPaddingTargetHeight - _topPaddingMinHeight))
                      .clamp(0.0, 1.0);

          final maxSheetHeight = math.max(120.0, height - topPadding);
          final sheetHeight = widget.sheetHeight != null
              ? widget.sheetHeight!.clamp(120.0, maxSheetHeight).toDouble()
              : maxSheetHeight;
          final sheetWidth = widget.fullWidth
              ? width
              : math.min(width, widget.maxWidth ?? width);
          final sheetX = ((width - sheetWidth) * widget.align)
              .clamp(0.0, math.max(0.0, width - sheetWidth))
              .toDouble();
          final flushLeft = sheetX <= 0.5;
          final flushRight = (sheetX + sheetWidth) >= width - 0.5;

          _lastTravelDistance = math.max(1.0, sheetHeight - effectiveBottomBarHeight);

          final sheetChild = AdwDialogScope(
            close: () {
              if (widget.canClose) _setOpen(false);
            },
            isBottomSheet: true,
            child: AdwBottomSheetScope(
              hideTitle: widget.showDragHandle,
              canClose: widget.canClose,
              close: () {
                if (widget.canClose) _setOpen(false);
              },
              child: Stack(
                children: [
                  Positioned.fill(child: widget.sheet),
                  if (widget.showDragHandle)
                    Positioned(
                      top: 15.0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 54.0,
                            height: 6.0,
                            decoration: BoxDecoration(
                              color:
                                  theme.colors.foreground.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(99.0),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );

          final bottomBarChild = widget.bottomBar == null
              ? const SizedBox.shrink()
              : MouseRegion(
                  cursor: widget.canOpen
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  onEnter: (_) => setState(() => _isBottomBarHovered = true),
                  onExit: (_) => setState(() {
                    _isBottomBarHovered = false;
                    _isBottomBarPressed = false;
                  }),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: widget.canOpen
                        ? (_) => setState(() => _isBottomBarPressed = true)
                        : null,
                    onTapUp: widget.canOpen
                        ? (_) => setState(() => _isBottomBarPressed = false)
                        : null,
                    onTapCancel: () =>
                        setState(() => _isBottomBarPressed = false),
                    onTap: widget.canOpen ? () => _setOpen(true) : null,
                    child: AnimatedContainer(
                      duration: AdwCurves.shortDuration,
                      height: effectiveBottomBarHeight,
                      color: _isBottomBarPressed
                          ? theme.colors.foreground.withValues(alpha: 0.16)
                          : _isBottomBarHovered
                              ? theme.colors.foreground.withValues(alpha: 0.07)
                              : const Color(0x00000000),
                      child: widget.bottomBar,
                    ),
                  ),
                );

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(child: widget.content),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = _controller.value;
                  final dimmingAlpha =
                      widget.modal ? 0.4 * progress.clamp(0.0, 1.0) : 0.0;
                  final blockContent =
                      widget.modal && (_isOpen || progress > 0.01);

                  return Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !blockContent,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.canClose ? () => _setOpen(false) : null,
                        child: ColoredBox(
                          color: Color.fromRGBO(0, 0, 0, dimmingAlpha),
                        ),
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = _controller.value;
                  final visibleHeight = lerpDouble(
                    effectiveBottomBarHeight,
                    sheetHeight,
                    progress,
                  )!
                      .clamp(0.0, height)
                      .toDouble();

                  if (visibleHeight <= 0.5) {
                    return const SizedBox.shrink();
                  }

                  final showSheet = progress >= _childSwitchThreshold;
                  final sheetRadius = BorderRadius.only(
                    topLeft: (!showSheet && flushLeft)
                        ? Radius.zero
                        : const Radius.circular(AdwMetrics.windowRadius),
                    topRight: (!showSheet && flushRight)
                        ? Radius.zero
                        : const Radius.circular(AdwMetrics.windowRadius),
                  );

                  final bool canDrag =
                      (widget.showDragHandle || widget.bottomBar != null) &&
                          ((_isOpen && widget.canClose) ||
                              (!_isOpen && widget.canOpen));

                  final topShadeColor = theme.colors.isDark
                      ? const Color(0xFF18181C)
                      : const Color(0x14000000);
                  final topBorderColor = theme.colors.isDark
                      ? const Color(0xFF323235)
                      : theme.colors.windowOutline;

                  return Positioned(
                    left: sheetX,
                    bottom: 0,
                    width: sheetWidth,
                    height: visibleHeight,
                    child: RawGestureDetector(
                      behavior: HitTestBehavior.opaque,
                      gestures: canDrag
                          ? <Type, GestureRecognizerFactory>{
                              VerticalDragGestureRecognizer:
                                  GestureRecognizerFactoryWithHandlers<
                                      VerticalDragGestureRecognizer>(
                                () => VerticalDragGestureRecognizer(
                                  supportedDevices: const <PointerDeviceKind>{
                                    PointerDeviceKind.mouse,
                                    PointerDeviceKind.touch,
                                    PointerDeviceKind.stylus,
                                  },
                                ),
                                (VerticalDragGestureRecognizer instance) {
                                  instance.onStart = _handleDragStart;
                                  instance.onUpdate = _handleDragUpdate;
                                  instance.onEnd = _handleDragEnd;
                                  instance.onCancel = () {
                                    if (_isDragging) {
                                      _handleDragEnd(DragEndDetails());
                                    }
                                  };
                                },
                              ),
                            }
                          : const <Type, GestureRecognizerFactory>{},
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colors.windowBackground,
                          borderRadius: sheetRadius,
                          boxShadow: showSheet
                              ? [
                                  BoxShadow(
                                    color: topShadeColor,
                                    blurRadius: 0.0,
                                    spreadRadius: 0.0,
                                    offset: const Offset(0, -1),
                                  ),
                                  const BoxShadow(
                                    color: Color(0x45000000),
                                    blurRadius: 16.0,
                                    spreadRadius: 2.0,
                                    offset: Offset(0, -2),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: topShadeColor,
                                    blurRadius: 0.0,
                                    spreadRadius: 0.0,
                                    offset: const Offset(0, -1),
                                  ),
                                  const BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 8.0,
                                    spreadRadius: 1.0,
                                    offset: Offset(0, -1),
                                  ),
                                ],
                        ),
                        child: ClipRRect(
                          borderRadius: sheetRadius,
                          child: Stack(
                            children: [
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: showSheet
                                    ? math.max(sheetHeight, visibleHeight)
                                    : effectiveBottomBarHeight,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 100),
                                  child: showSheet
                                      ? KeyedSubtree(
                                          key: const ValueKey('sheet'),
                                          child: sheetChild,
                                        )
                                      : KeyedSubtree(
                                          key: const ValueKey('bottomBar'),
                                          child: bottomBarChild,
                                        ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: sheetRadius,
                                      border: Border(
                                        top: BorderSide(
                                          color: topBorderColor,
                                          width: 1.0,
                                        ),
                                        left: flushLeft
                                            ? BorderSide.none
                                            : BorderSide(
                                                color:
                                                    theme.colors.windowOutline,
                                                width: 1.0,
                                              ),
                                        right: flushRight
                                            ? BorderSide.none
                                            : BorderSide(
                                                color:
                                                    theme.colors.windowOutline,
                                                width: 1.0,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
