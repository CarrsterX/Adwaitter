import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';

/// Controller coordinating page transitions and position tracking for [AdwCarousel].
///
/// Follows upstream Libadwaita `AdwCarousel` API:
/// https://gitlab.gnome.org/GNOME/libadwaita/-/blob/main/src/adw-carousel.c
class AdwCarouselController extends ChangeNotifier {
  late final PageController _pageController;
  final bool _ownsController;
  int _itemCount = 0;
  double? _lastKnownPage;
  VoidCallback? _onProgrammaticNavigation;

  AdwCarouselController({int initialPage = 0})
      : _pageController = PageController(initialPage: initialPage),
        _ownsController = true {
    _pageController.addListener(_onPageControllerNotify);
  }

  /// Internal constructor wrapping an external [PageController].
  AdwCarouselController.fromPageController(PageController pageController)
      : _pageController = pageController,
        _ownsController = false {
    _pageController.addListener(_onPageControllerNotify);
  }

  void _onPageControllerNotify() {
    if (_pageController.hasClients &&
        _pageController.positions.length == 1 &&
        _pageController.position.hasContentDimensions) {
      _lastKnownPage = _pageController.page;
    }
    notifyListeners();
  }

  /// Access underlying [PageController].
  PageController get pageController => _pageController;

  /// Total count of pages currently registered in the carousel.
  int get itemCount => _itemCount;

  /// Internal setter invoked by [AdwCarousel].
  void updateItemCount(int count) {
    if (_itemCount != count) {
      _itemCount = count;
      notifyListeners();
    }
  }

  /// Current continuous scroll position as a double.
  double get page {
    if (!_pageController.hasClients ||
        _pageController.positions.length != 1 ||
        !_pageController.position.hasContentDimensions) {
      return _lastKnownPage ?? _pageController.initialPage.toDouble();
    }
    return _pageController.page ??
        _lastKnownPage ??
        _pageController.initialPage.toDouble();
  }

  /// Current discrete rounded page index.
  int get currentPage =>
      page.round().clamp(0, _itemCount > 0 ? _itemCount - 1 : 0);

  /// Animate smoothly to a specific target [page] index.
  Future<void> animateToPage(
    int page, {
    Duration duration = AdwCurves.normalDuration,
    Curve curve = AdwCurves.standard,
  }) {
    if (!_pageController.hasClients) return Future.value();
    _onProgrammaticNavigation?.call();
    final target = page.clamp(0, _itemCount > 0 ? _itemCount - 1 : 0);
    return _pageController.animateToPage(target,
        duration: duration, curve: curve);
  }

  /// Advance to the next page if available.
  Future<void> nextPage({
    Duration duration = AdwCurves.normalDuration,
    Curve curve = AdwCurves.standard,
  }) {
    return animateToPage(currentPage + 1, duration: duration, curve: curve);
  }

  /// Retreat to the previous page if available.
  Future<void> previousPage({
    Duration duration = AdwCurves.normalDuration,
    Curve curve = AdwCurves.standard,
  }) {
    return animateToPage(currentPage - 1, duration: duration, curve: curve);
  }

  /// Jump immediately to the given [page] without animation.
  void jumpToPage(int page) {
    if (!_pageController.hasClients) return;
    _onProgrammaticNavigation?.call();
    final target = page.clamp(0, _itemCount > 0 ? _itemCount - 1 : 0);
    _pageController.jumpToPage(target);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageControllerNotify);
    if (_ownsController) {
      _pageController.dispose();
    }
    super.dispose();
  }
}

/// Libadwaita paginated carousel widget (`AdwCarousel`).
///
/// Implements upstream GNOME Libadwaita specifications:
/// - GitLab source: `https://gitlab.gnome.org/GNOME/libadwaita/-/blob/main/src/adw-carousel.c`
/// - CSS selector: `carousel`
///
/// Supports interactive swiping, mouse drag, keyboard traversal, and optional overlay
/// previous/next navigation arrow buttons.
class AdwCarousel extends StatefulWidget {
  /// The list of widgets to display in sequential pages.
  final List<Widget> children;

  /// External controller for orchestrating animations and monitoring positions.
  final AdwCarouselController? controller;

  /// Invoked whenever the active page changes.
  final ValueChanged<int>? onPageChanged;

  /// Scroll axis of the carousel (`Axis.horizontal` or `Axis.vertical`).
  final Axis scrollDirection;

  /// Whether mouse scroll wheel events change pages.
  final bool allowScrollWheel;

  /// Whether a fast/long swipe can jump across multiple pages at once.
  final bool allowLongSwipes;

  /// Spacing between consecutive carousel items in logical pixels.
  final double spacing;

  /// Fraction of viewport allocated per page (default 1.0 for full-bleed pages).
  final double viewportFraction;

  /// Whether to display overlay floating navigation arrow buttons on hover.
  final bool showNavigationButtons;

  /// Whether touch and mouse dragging are enabled.
  final bool interactive;

  const AdwCarousel({
    super.key,
    required this.children,
    this.controller,
    this.onPageChanged,
    this.scrollDirection = Axis.horizontal,
    this.allowScrollWheel = true,
    this.allowLongSwipes = false,
    this.spacing = 0.0,
    this.viewportFraction = 1.0,
    this.showNavigationButtons = false,
    this.interactive = true,
  });

  @override
  State<AdwCarousel> createState() => _AdwCarouselState();

  /// Returns `true` when an interactive horizontal [AdwCarousel] under
  /// [globalPosition] is not at its leftmost item (`page > 0.01`), so outer
  /// navigation swipe-back gestures yield priority to the carousel.
  static bool shouldBlockParentSwipeBack(Offset globalPosition) {
    for (final state in _AdwCarouselState._activeCarousels) {
      if (state._shouldBlockSwipeBackAt(globalPosition)) {
        return true;
      }
    }
    return false;
  }
}

class _CarouselDragSession {
  int? startPage;
  bool isTrackpad = false;
  bool isDragging = false;
  bool allowLongSwipes = false;
}

class _AdwCarouselState extends State<AdwCarousel> {
  static final Set<_AdwCarouselState> _activeCarousels = <_AdwCarouselState>{};

  late AdwCarouselController _controller;
  bool _isLocalController = false;
  bool _isHovered = false;
  DateTime _lastWheelStep = DateTime.fromMillisecondsSinceEpoch(0);
  double _wheelAccumulator = 0.0;
  final _CarouselDragSession _dragSession = _CarouselDragSession();

  @override
  void initState() {
    super.initState();
    _activeCarousels.add(this);
    _dragSession.allowLongSwipes = widget.allowLongSwipes;
    _initController();
  }

  bool _shouldBlockSwipeBackAt(Offset globalPosition) {
    if (!mounted ||
        !widget.interactive ||
        widget.scrollDirection != Axis.horizontal ||
        widget.children.length <= 1) {
      return false;
    }
    if (_controller.page <= 0.01) {
      return false;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        !renderObject.attached) {
      return false;
    }
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    return rect.contains(globalPosition);
  }

  void _initController() {
    if (widget.controller != null) {
      _controller = widget.controller!;
      _isLocalController = false;
    } else {
      _controller = AdwCarouselController();
      _isLocalController = true;
    }
    _controller._onProgrammaticNavigation = () {
      _dragSession.startPage = null;
      _dragSession.isTrackpad = false;
      _dragSession.isDragging = false;
    };
    _controller.updateItemCount(widget.children.length);
  }

  @override
  void didUpdateWidget(covariant AdwCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _dragSession.allowLongSwipes = widget.allowLongSwipes;
    if (widget.controller != oldWidget.controller) {
      if (_isLocalController) {
        _controller.dispose();
      }
      _initController();
    } else {
      _controller.updateItemCount(widget.children.length);
    }
  }

  @override
  void dispose() {
    _activeCarousels.remove(this);
    _controller._onProgrammaticNavigation = null;
    if (_isLocalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!widget.interactive || !widget.allowScrollWheel) return;
    if (event is! PointerScrollEvent) return;
    if (_dragSession.isDragging ||
        _dragSession.isTrackpad ||
        event.kind == PointerDeviceKind.trackpad) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastWheelStep).inMilliseconds < 240) return;

    final delta = widget.scrollDirection == Axis.horizontal
        ? (event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
            ? event.scrollDelta.dx
            : event.scrollDelta.dy)
        : event.scrollDelta.dy;

    if (delta.abs() < 0.5) return;

    // Accumulate fine-grained smooth scroll deltas (e.g. high-res mice)
    // so a single light touch doesn't fire multiple page jumps.
    if ((_wheelAccumulator > 0 && delta < 0) ||
        (_wheelAccumulator < 0 && delta > 0)) {
      _wheelAccumulator = 0.0;
    }
    _wheelAccumulator += delta;

    if (_wheelAccumulator.abs() < 32.0) return;

    final stepPositive = _wheelAccumulator > 0;
    _wheelAccumulator = 0.0;
    _lastWheelStep = now;

    final duration = AdwCurves.resolve(context, AdwCurves.normalDuration);
    if (stepPositive) {
      _controller.nextPage(duration: duration);
    } else {
      _controller.previousPage(duration: duration);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.children.length;
    _dragSession.allowLongSwipes = widget.allowLongSwipes;

    Widget pageView = Listener(
      onPointerDown: (_) {
        _dragSession.startPage = _controller.currentPage;
        _dragSession.isTrackpad = false;
      },
      onPointerUp: (_) {
        if (!_dragSession.isDragging) {
          _dragSession.startPage = null;
        }
      },
      onPointerCancel: (_) {
        if (!_dragSession.isDragging) {
          _dragSession.startPage = null;
        }
      },
      onPointerPanZoomStart: (_) {
        _dragSession.startPage = _controller.currentPage;
        _dragSession.isTrackpad = true;
      },
      onPointerPanZoomEnd: (_) {
        if (!_dragSession.isDragging) {
          _dragSession.startPage = null;
          _dragSession.isTrackpad = false;
        }
      },
      onPointerSignal: _handlePointerSignal,
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: (notification) {
          notification.disallowIndicator();
          return true;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.depth != 0) return false;
            if (notification is ScrollStartNotification) {
              if (notification.dragDetails != null) {
                _dragSession.isDragging = true;
                _dragSession.isTrackpad =
                    notification.dragDetails!.kind == PointerDeviceKind.trackpad;
                _dragSession.startPage ??= _controller.currentPage;
              }
            } else if (notification is ScrollEndNotification) {
              _dragSession.isDragging = false;
              _dragSession.startPage = null;
              _dragSession.isTrackpad = false;
            }
            return false;
          },
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
              overscroll: false,
              dragDevices: const <PointerDeviceKind>{
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
                PointerDeviceKind.trackpad,
              },
            ),
            child: PageView.builder(
              scrollDirection: widget.scrollDirection,
              controller: _controller.pageController,
              pageSnapping: false,
              physics: widget.interactive
                  ? _AdwCarouselScrollPhysics(
                      allowLongSwipes: widget.allowLongSwipes,
                      dragSession: _dragSession,
                    )
                  : const NeverScrollableScrollPhysics(),
              onPageChanged: widget.onPageChanged,
              itemCount: count,
              itemBuilder: (context, index) {
                final page = Center(child: widget.children[index]);
                if (widget.spacing == 0.0) {
                  return page;
                }
                return Padding(
                  padding: widget.scrollDirection == Axis.horizontal
                      ? EdgeInsets.symmetric(horizontal: widget.spacing / 2)
                      : EdgeInsets.symmetric(vertical: widget.spacing / 2),
                  child: page,
                );
              },
            ),
          ),
        ),
      ),
    );

    if (!widget.showNavigationButtons || count <= 1) {
      return pageView;
    }

    final duration = AdwCurves.resolve(context, AdwCurves.shortDuration);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        alignment: Alignment.center,
        children: [
          pageView,
          // Previous button overlay
          Positioned(
            left: 12,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final canGoBack = _controller.currentPage > 0;
                final isVisible = _isHovered && canGoBack;

                return AnimatedOpacity(
                  opacity: isVisible ? 1.0 : 0.0,
                  duration: duration,
                  curve: AdwCurves.standard,
                  child: IgnorePointer(
                    ignoring: !isVisible,
                    child: _CarouselNavButton(
                      direction: _NavDirection.previous,
                      onPressed: () => _controller.previousPage(
                        duration: AdwCurves.resolve(
                            context, AdwCurves.normalDuration),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Next button overlay
          Positioned(
            right: 12,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final canGoForward = _controller.currentPage < count - 1;
                final isVisible = _isHovered && canGoForward;

                return AnimatedOpacity(
                  opacity: isVisible ? 1.0 : 0.0,
                  duration: duration,
                  curve: AdwCurves.standard,
                  child: IgnorePointer(
                    ignoring: !isVisible,
                    child: _CarouselNavButton(
                      direction: _NavDirection.next,
                      onPressed: () => _controller.nextPage(
                        duration: AdwCurves.resolve(
                            context, AdwCurves.normalDuration),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _NavDirection { previous, next }

class _CarouselNavButton extends StatefulWidget {
  final _NavDirection direction;
  final VoidCallback onPressed;

  const _CarouselNavButton({
    required this.direction,
    required this.onPressed,
  });

  @override
  State<_CarouselNavButton> createState() => _CarouselNavButtonState();
}

class _CarouselNavButtonState extends State<_CarouselNavButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final duration = AdwCurves.resolve(context, AdwCurves.shortDuration);

    Color bg = const Color(0x80000000);
    if (_isPressed) {
      bg = const Color(0xCC000000);
    } else if (_isHovered) {
      bg = const Color(0xA6000000);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: duration,
          curve: AdwCurves.standard,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(12, 12),
              painter: _ChevronPainter(
                direction: widget.direction,
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  final _NavDirection direction;
  final Color color;

  const _ChevronPainter({
    required this.direction,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (direction == _NavDirection.previous) {
      path.moveTo(size.width * 0.7, size.height * 0.1);
      path.lineTo(size.width * 0.3, size.height * 0.5);
      path.lineTo(size.width * 0.7, size.height * 0.9);
    } else {
      path.moveTo(size.width * 0.3, size.height * 0.1);
      path.lineTo(size.width * 0.7, size.height * 0.5);
      path.lineTo(size.width * 0.3, size.height * 0.9);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter oldDelegate) {
    return direction != oldDelegate.direction || color != oldDelegate.color;
  }
}

class _AdwCarouselScrollPhysics extends PageScrollPhysics {
  final bool allowLongSwipes;
  final _CarouselDragSession? dragSession;

  const _AdwCarouselScrollPhysics({
    super.parent,
    this.allowLongSwipes = false,
    this.dragSession,
  });

  @override
  _AdwCarouselScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _AdwCarouselScrollPhysics(
      parent: buildParent(ancestor),
      allowLongSwipes: allowLongSwipes,
      dragSession: dragSession,
    );
  }

  @override
  bool shouldUpdate(covariant _AdwCarouselScrollPhysics old) {
    if (allowLongSwipes != old.allowLongSwipes ||
        dragSession != old.dragSession) {
      return true;
    }
    return super.shouldUpdate(old);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final effectiveAllowLongSwipes =
        allowLongSwipes || (dragSession?.allowLongSwipes ?? false);
    final startPage = dragSession?.startPage;
    if (!effectiveAllowLongSwipes && startPage != null) {
      final viewport = position.viewportDimension;
      if (viewport > 0) {
        final minAllowed = math.max(
          position.minScrollExtent,
          (startPage - 1) * viewport,
        );
        final maxAllowed = math.min(
          position.maxScrollExtent,
          (startPage + 1) * viewport,
        );
        if (value < position.pixels && position.pixels <= minAllowed) {
          return value - position.pixels;
        }
        if (maxAllowed <= position.pixels && position.pixels < value) {
          return value - position.pixels;
        }
        if (value < minAllowed && minAllowed < position.pixels) {
          return value - minAllowed;
        }
        if (position.pixels < maxAllowed && maxAllowed < value) {
          return value - maxAllowed;
        }
        return 0.0;
      }
    }
    return super.applyBoundaryConditions(position, value);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (dragSession?.isTrackpad ?? false) {
      final viewport = math.max(1.0, position.viewportDimension);
      // Keep physical touchpad travel per page consistent on narrow mobile viewports.
      final double scale = 0.31 * (viewport / math.max(viewport, 680.0));
      return super.applyPhysicsToUserOffset(position, offset * scale);
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final isTrackpad = dragSession?.isTrackpad ?? false;
    final effectiveVelocity = isTrackpad ? velocity * 0.31 : velocity;
    final effectiveAllowLongSwipes =
        allowLongSwipes || (dragSession?.allowLongSwipes ?? false);

    if ((effectiveVelocity <= 0.0 &&
            position.pixels <= position.minScrollExtent) ||
        (effectiveVelocity >= 0.0 &&
            position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, effectiveVelocity);
    }

    final tolerance = toleranceFor(position);
    final viewport = math.max(1.0, position.viewportDimension);
    final currentPageDouble = position.pixels / viewport;

    int targetPage;
    if (!effectiveAllowLongSwipes) {
      double page = currentPageDouble;
      if (effectiveVelocity < -tolerance.velocity) {
        page -= 0.5;
      } else if (effectiveVelocity > tolerance.velocity) {
        page += 0.5;
      }
      targetPage = page.round();
      final startPage = dragSession?.startPage;
      if (startPage != null) {
        targetPage = targetPage.clamp(startPage - 1, startPage + 1);
      }
    } else {
      if (effectiveVelocity.abs() <= tolerance.velocity) {
        targetPage = currentPageDouble.round();
      } else {
        final projectionTime = isTrackpad ? 0.16 : 0.25;
        final projectedPage =
            (position.pixels + effectiveVelocity * projectionTime) / viewport;
        if (effectiveVelocity > tolerance.velocity) {
          targetPage = math.max(
            projectedPage.round(),
            (currentPageDouble + 0.5).round(),
          );
        } else {
          targetPage = math.min(
            projectedPage.round(),
            (currentPageDouble - 0.5).round(),
          );
        }
      }
    }

    final targetPixels = (targetPage * viewport)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    if ((targetPixels - position.pixels).abs() < tolerance.distance &&
        effectiveVelocity.abs() < tolerance.velocity) {
      return null;
    }

    if (targetPixels != position.pixels ||
        effectiveVelocity.abs() >= tolerance.velocity) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        targetPixels,
        effectiveVelocity,
        tolerance: tolerance,
      );
    }
    return null;
  }
}
