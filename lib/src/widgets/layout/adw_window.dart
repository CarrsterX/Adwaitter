import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'
    show TargetPlatform, ValueListenable, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show kPrimaryMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../navigation/adw_navigation_split_view.dart';
import 'adw_application.dart';

/// Window edge identifiers for native border resize operations.
enum AdwWindowEdge {
  top,
  bottom,
  left,
  right,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// Decoupled interface for native Client-Side Decorations (CSD) / frameless window control.
abstract class AdwWindowController {
  bool get isMaximized;
  bool get isFullscreen => false;
  bool get isTiled => false;
  bool get isActive;
  ValueListenable<bool>? get activeListenable;
  Listenable? get windowStateListenable => null;
  void close();
  void minimize();
  void maximize();
  void toggleFullscreen() {}
  void setFullscreen(bool fullscreen) {}
  void setShadowMargin(int margin) {}
  void startDragging();
  void beginResizeDrag(AdwWindowEdge edge);
}

/// Native implementation delegating to the desktop platform channel (`libadwaitter/window`).
class AdwNativeWindowController implements AdwWindowController {
  static const MethodChannel _channel = MethodChannel('libadwaitter/window');
  static final Map<int, AdwNativeWindowController> _controllersByViewId =
      <int, AdwNativeWindowController>{};
  static bool _handlerRegistered = false;

  final int viewId;
  final VoidCallback? onCloseOverride;
  final ValueNotifier<bool> _maximizedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _fullscreenNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _tiledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _activeNotifier = ValueNotifier<bool>(true);
  late final Listenable _stateListenable = Listenable.merge([
    _maximizedNotifier,
    _fullscreenNotifier,
    _tiledNotifier,
  ]);

  AdwNativeWindowController({
    this.viewId = 0,
    this.onCloseOverride,
  }) {
    _controllersByViewId[viewId] = this;
    _ensureChannelHandler();
    _init();
  }

  void dispose() {
    if (_controllersByViewId[viewId] == this) {
      _controllersByViewId.remove(viewId);
    }
    _maximizedNotifier.dispose();
    _fullscreenNotifier.dispose();
    _tiledNotifier.dispose();
    _activeNotifier.dispose();
  }

  static Future<void> attachSubWindow({
    required int windowHandle,
    required int viewHandle,
    required int viewId,
    int? parentViewId,
  }) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('attachSubWindow', <String, Object>{
        'windowHandle': windowHandle,
        'viewHandle': viewHandle,
        'viewId': viewId,
        if (parentViewId != null) 'parentViewId': parentViewId,
      });
    } catch (_) {}
  }

  static Future<({int windowHandle, int viewHandle, int viewId})?>
      getWindowHandles({int viewId = 0}) async {
    if (kIsWeb) return null;
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getWindowHandles',
        <String, Object>{'viewId': viewId},
      );
      if (result == null) return null;
      final windowHandle = result['windowHandle'] as int?;
      final viewHandle = result['viewHandle'] as int?;
      final resolvedViewId = (result['viewId'] as int?) ?? viewId;
      if (windowHandle == null || viewHandle == null || windowHandle == 0 || viewHandle == 0) {
        return null;
      }
      return (
        windowHandle: windowHandle,
        viewHandle: viewHandle,
        viewId: resolvedViewId,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> attachPopupWindow({required int windowHandle}) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('attachPopupWindow', <String, Object>{
        'windowHandle': windowHandle,
      });
    } catch (_) {}
  }

  static void _ensureChannelHandler() {
    if (kIsWeb || _handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWindowActiveChanged') {
        final args = call.arguments;
        if (args is bool) {
          _controllersByViewId[0]?._activeNotifier.value = args;
        } else if (args is Map) {
          final targetId = (args['viewId'] as int?) ?? 0;
          final active = args['isActive'] as bool?;
          if (active != null) {
            _controllersByViewId[targetId]?._activeNotifier.value = active;
          }
        }
      } else if (call.method == 'onWindowStateChanged') {
        final Map? map = call.arguments as Map?;
        if (map != null) {
          final targetId = (map['viewId'] as int?) ?? 0;
          final target = _controllersByViewId[targetId];
          if (target != null) {
            final isMax = map['isMaximized'] as bool?;
            final isFull = map['isFullscreen'] as bool?;
            final isTiled = map['isTiled'] as bool?;
            if (isMax != null) target._maximizedNotifier.value = isMax;
            if (isFull != null) target._fullscreenNotifier.value = isFull;
            if (isTiled != null) target._tiledNotifier.value = isTiled;
          }
        }
      }
    });
  }

  void _init() async {
    if (kIsWeb) return;
    final args = <String, Object>{'viewId': viewId};
    try {
      final bool? isMax = await _channel.invokeMethod<bool>('isMaximized', args);
      if (isMax != null) {
        _maximizedNotifier.value = isMax;
      }
      final bool? isFull =
          await _channel.invokeMethod<bool>('isFullscreen', args);
      if (isFull != null) {
        _fullscreenNotifier.value = isFull;
      }
      final bool? tiled = await _channel.invokeMethod<bool>('isTiled', args);
      if (tiled != null) {
        _tiledNotifier.value = tiled;
      }
      final bool? active = await _channel.invokeMethod<bool>('isActive', args);
      if (active != null) {
        _activeNotifier.value = active;
      }
    } catch (_) {}
  }

  @override
  bool get isMaximized => _maximizedNotifier.value;

  @override
  bool get isFullscreen => _fullscreenNotifier.value;

  @override
  bool get isTiled => _tiledNotifier.value;

  @override
  bool get isActive => _activeNotifier.value;

  @override
  ValueListenable<bool> get activeListenable => _activeNotifier;

  @override
  Listenable get windowStateListenable => _stateListenable;

  @override
  void close() {
    if (onCloseOverride != null) {
      onCloseOverride!();
      return;
    }
    if (kIsWeb) return;
    _channel.invokeMethod('close', <String, Object>{'viewId': viewId}).catchError((_) {});
  }

  @override
  void minimize() {
    if (kIsWeb) return;
    _channel.invokeMethod('minimize', <String, Object>{'viewId': viewId}).catchError((_) {});
  }

  @override
  void maximize() {
    if (kIsWeb) return;
    _maximizedNotifier.value = !_maximizedNotifier.value;
    _channel.invokeMethod('maximize', <String, Object>{'viewId': viewId}).catchError((_) {});
  }

  @override
  void toggleFullscreen() {
    setFullscreen(!_fullscreenNotifier.value);
  }

  @override
  void setFullscreen(bool fullscreen) {
    if (kIsWeb) return;
    _fullscreenNotifier.value = fullscreen;
    _channel.invokeMethod(
      'setFullscreen',
      <String, Object>{'viewId': viewId, 'fullscreen': fullscreen},
    ).catchError((_) {});
  }

  int? _lastShadowMargin;

  @override
  void setShadowMargin(int margin) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.linux) return;
    if (_lastShadowMargin == margin) return;
    _lastShadowMargin = margin;
    _channel.invokeMethod(
      'setShadowMargin',
      <String, Object>{'viewId': viewId, 'margin': margin},
    ).catchError((_) {});
  }

  @override
  void startDragging() {
    if (kIsWeb) return;
    _channel.invokeMethod('startDragging', <String, Object>{'viewId': viewId}).catchError((_) {});
  }

  @override
  void beginResizeDrag(AdwWindowEdge edge) {
    if (kIsWeb) return;
    _channel.invokeMethod('beginResizeDrag', <String, Object>{
      'edge': edge.name,
      'viewId': viewId,
    }).catchError((_) {});
  }
}

/// Inherited scope providing window state and [AdwWindowController] down the widget tree.
class AdwWindowScope extends InheritedWidget {
  final AdwWindowController? controller;
  final bool isMaximized;
  final bool isActive;
  final bool isDevel;
  final bool applyTopSafeArea;
  final double bottomSafeInset;

  const AdwWindowScope({
    super.key,
    this.controller,
    required this.isMaximized,
    this.isActive = true,
    this.isDevel = false,
    this.applyTopSafeArea = true,
    this.bottomSafeInset = 0.0,
    required super.child,
  });

  static AdwWindowScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdwWindowScope>();
  }

  static AdwWindowScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(
        scope != null, 'No AdwWindowScope found in the current BuildContext.');
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant AdwWindowScope oldWidget) {
    return controller != oldWidget.controller ||
        isMaximized != oldWidget.isMaximized ||
        isActive != oldWidget.isActive ||
        isDevel != oldWidget.isDevel ||
        applyTopSafeArea != oldWidget.applyTopSafeArea ||
        bottomSafeInset != oldWidget.bottomSafeInset;
  }
}

/// Top-level application window container (`AdwWindow` / `AdwApplicationWindow`).
///
/// Implements GNOME Client-Side Decorations (CSD):
/// - 15px corner radius ([AdwMetrics.windowRadius]) when floating.
/// - Transitions automatically to square corners (0px) and removes shadows when maximized.
/// - Subtle Mutter-style window drop shadow.
/// - 1px adaptive hairline border.
/// - Transparent edge/corner hit test zones enabling native Mutter/Wayland window resizing.
class AdwWindow extends StatefulWidget {
  /// Global reactive toggle for the `.devel` window style class (`window.devel`).
  static final ValueNotifier<bool> develMode = ValueNotifier<bool>(false);

  final AdwWindowController? controller;
  final bool? isMaximized;
  final bool isDevel;
  final Widget? headerBar;
  final Widget child;
  final bool showShadow;
  final bool showBorder;
  final bool resizeToAvoidBottomInset;
  final bool bottomSafeArea;
  final bool delegateSafeAreaToChild;

  const AdwWindow({
    super.key,
    this.controller,
    this.isMaximized,
    this.isDevel = false,
    this.headerBar,
    required this.child,
    this.showShadow = true,
    this.showBorder = true,
    this.resizeToAvoidBottomInset = true,
    this.bottomSafeArea = false,
    this.delegateSafeAreaToChild = false,
  });

  @override
  State<AdwWindow> createState() => _AdwWindowState();
}

class _AdwWindowState extends State<AdwWindow> with WidgetsBindingObserver {
  static const MethodChannel _styleChannel = MethodChannel('libadwaitter/style');
  late final AdwWindowController _effectiveController;
  bool _isActive = true;
  bool _isAndroidDesktopWindow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _effectiveController = widget.controller ?? _createDefaultController();
    _isActive = _effectiveController.isActive;
    _effectiveController.activeListenable?.addListener(_onActiveChanged);
    _effectiveController.windowStateListenable
        ?.addListener(_onWindowStateChanged);
    _refreshAndroidWindowMode();
  }

  Future<void> _refreshAndroidWindowMode() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final bool? inMultiWindow =
          await _styleChannel.invokeMethod<bool>('isInMultiWindowMode');
      if (mounted && inMultiWindow != null && inMultiWindow != _isAndroidDesktopWindow) {
        setState(() => _isAndroidDesktopWindow = inMultiWindow);
      }
    } catch (_) {}
  }

  @override
  void didChangeMetrics() {
    _refreshAndroidWindowMode();
  }

  @override
  void dispose() {
    _effectiveController.activeListenable?.removeListener(_onActiveChanged);
    _effectiveController.windowStateListenable
        ?.removeListener(_onWindowStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onActiveChanged() {
    if (mounted) {
      setState(() => _isActive = _effectiveController.isActive);
    }
  }

  void _onWindowStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Fallback backdrop detection for platforms without native GTK focus bridge
    if (_effectiveController.activeListenable == null && mounted) {
      setState(() => _isActive = state == AppLifecycleState.resumed);
    }
  }

  AdwWindowController _createDefaultController() {
    if (!kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      return AdwNativeWindowController();
    }
    return _NoopWindowController();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final bool isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final effectiveIsMaximized =
        widget.isMaximized ?? (isMobile ? true : _effectiveController.isMaximized);
    final effectiveIsFullscreen = _effectiveController.isFullscreen;
    final isSquareCorners = isMobile ||
        effectiveIsMaximized ||
        effectiveIsFullscreen ||
        _effectiveController.isTiled;

    final borderRadius = isSquareCorners
        ? BorderRadius.zero
        : BorderRadius.circular(AdwMetrics.windowRadius);

    final shapeScope = AdwWindowShapeScope.maybeOf(context);
    if (shapeScope != null && shapeScope.borderRadiusNotifier.value != borderRadius) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          shapeScope.borderRadiusNotifier.value = borderRadius;
        }
      });
    }

    final int expectedShadowMargin = (!kIsWeb &&
            defaultTargetPlatform == TargetPlatform.linux &&
            !isSquareCorners &&
            widget.showShadow)
        ? 24
        : 0;
    _effectiveController.setShadowMargin(expectedShadowMargin);

    final effectiveIsActive = _isActive;

    // When hosted inside AdwApplication (shapeScope != null), the outer
    // _AdwWindowShadowFrame paints the unclipped CSD shadow outside ClipRRect.
    final List<BoxShadow> shadows =
        (shapeScope == null && !isSquareCorners && widget.showShadow)
        ? (effectiveIsActive
            ? [
                const BoxShadow(
                  color: Color(0x38000000),
                  blurRadius: 18,
                  spreadRadius: 0,
                  offset: Offset(0, 6),
                ),
                const BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 4,
                  spreadRadius: 0,
                  offset: Offset(0, 1),
                ),
              ]
            : [
                const BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: Offset(0, 3),
                ),
              ])
        : const [];

    Widget windowContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.headerBar != null) widget.headerBar!,
        Expanded(child: widget.child),
      ],
    );

    double effectiveBottom = 0.0;
    final bool delegateSafeAreaToSplitView = isMobile &&
        widget.headerBar == null &&
        (widget.child is AdwNavigationSplitView ||
            widget.delegateSafeAreaToChild);

    if (isMobile) {
      final double bottomInset = widget.resizeToAvoidBottomInset
          ? MediaQuery.viewInsetsOf(context).bottom
          : 0.0;
      // Edge-to-edge: only pad the window for the virtual keyboard, never for
      // the system navbar (fixed bottom bars/sheets handle navbar insets).
      effectiveBottom = bottomInset;

      if (!delegateSafeAreaToSplitView) {
        windowContent = MediaQuery.removeViewInsets(
          context: context,
          removeBottom: widget.resizeToAvoidBottomInset,
          child: Padding(
            padding: EdgeInsets.only(bottom: effectiveBottom),
            child: SafeArea(
              top: !_isAndroidDesktopWindow,
              bottom: widget.bottomSafeArea,
              child: windowContent,
            ),
          ),
        );
      }
    }

    final Widget windowContentWithResizers = isMobile
        ? windowContent
        : AdwWindowResizeOverlay(
            controller: _effectiveController,
            enabled: !effectiveIsMaximized,
            child: windowContent,
          );

    return AdwWindowScope(
      controller: _effectiveController,
      isMaximized: effectiveIsMaximized,
      isActive: effectiveIsActive,
      isDevel: widget.isDevel,
      applyTopSafeArea: !_isAndroidDesktopWindow,
      bottomSafeInset: effectiveBottom,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.windowBackground,
          borderRadius: borderRadius,
          border: widget.showBorder && !isSquareCorners && theme.colors.isDark
              ? Border.all(
                  color: theme.colors.windowOutline,
                  width: 1,
                )
              : null,
          boxShadow: shadows,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              windowContentWithResizers,
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: (isMobile && !_isAndroidDesktopWindow
                        ? MediaQuery.paddingOf(context).top
                        : 0.0) +
                    AdwMetrics.headerBarHeight,
                child: IgnorePointer(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: AdwWindow.develMode,
                    builder: (context, globalDevel, _) {
                      if (!globalDevel && !widget.isDevel) {
                        return const SizedBox.shrink();
                      }
                      return CustomPaint(
                        painter: _AdwDevelStripesPainter(
                          color: theme.colors.headerBarForeground,
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (widget.showBorder && !isSquareCorners && theme.colors.isDark)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        border: Border.all(
                          color: theme.colors.windowInnerBorder,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: AdwCurves.shortDuration,
                    color: effectiveIsActive
                        ? const Color(0x00000000)
                        : (theme.colors.isDark
                            ? const Color(0x14000000)
                            : const Color(0x0AFFFFFF)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlays transparent edge/corner resize hit-test handles onto [child] so
/// both [AdwWindow] and modal routes (`showAdwDialog`) keep window resizing
/// active when the window is not maximized.
class AdwWindowResizeOverlay extends StatelessWidget {
  final AdwWindowController controller;
  final bool enabled;
  final Widget child;

  const AdwWindowResizeOverlay({
    super.key,
    required this.controller,
    this.enabled = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (enabled) ...[
          Positioned(
            top: 0,
            left: 14,
            right: 14,
            height: 6,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeUp,
              edge: AdwWindowEdge.top,
              onResize: () => controller.beginResizeDrag(AdwWindowEdge.top),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 14,
            right: 14,
            height: 6,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeDown,
              edge: AdwWindowEdge.bottom,
              onResize: () => controller.beginResizeDrag(AdwWindowEdge.bottom),
            ),
          ),
          Positioned(
            top: 14,
            bottom: 14,
            left: 0,
            width: 6,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeLeft,
              edge: AdwWindowEdge.left,
              onResize: () => controller.beginResizeDrag(AdwWindowEdge.left),
            ),
          ),
          Positioned(
            top: 14,
            bottom: 14,
            right: 0,
            width: 6,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeRight,
              edge: AdwWindowEdge.right,
              onResize: () => controller.beginResizeDrag(AdwWindowEdge.right),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            width: 14,
            height: 14,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeUpLeft,
              edge: AdwWindowEdge.topLeft,
              onResize: () => controller.beginResizeDrag(AdwWindowEdge.topLeft),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            width: 14,
            height: 14,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeUpRight,
              edge: AdwWindowEdge.topRight,
              onResize: () =>
                  controller.beginResizeDrag(AdwWindowEdge.topRight),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            width: 14,
            height: 14,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeDownLeft,
              edge: AdwWindowEdge.bottomLeft,
              onResize: () =>
                  controller.beginResizeDrag(AdwWindowEdge.bottomLeft),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            width: 14,
            height: 14,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeDownRight,
              edge: AdwWindowEdge.bottomRight,
              onResize: () =>
                  controller.beginResizeDrag(AdwWindowEdge.bottomRight),
            ),
          ),
        ],
      ],
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  final MouseCursor cursor;
  final AdwWindowEdge edge;
  final VoidCallback onResize;

  const _ResizeHandle({
    required this.cursor,
    required this.edge,
    required this.onResize,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.buttons == kPrimaryMouseButton) {
            onResize();
          }
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _NoopWindowController implements AdwWindowController {
  @override
  bool get isMaximized => false;
  @override
  bool get isFullscreen => false;
  @override
  bool get isTiled => false;
  @override
  bool get isActive => true;
  @override
  ValueListenable<bool>? get activeListenable => null;
  @override
  Listenable? get windowStateListenable => null;
  @override
  void close() {}
  @override
  void minimize() {}
  @override
  void maximize() {}
  @override
  void toggleFullscreen() {}
  @override
  void setFullscreen(bool fullscreen) {}
  @override
  void setShadowMargin(int margin) {}
  @override
  void startDragging() {}
  @override
  void beginResizeDrag(AdwWindowEdge edge) {}
}

/// Renders the upstream `assets/devel-stripes.svg` (`64x64` repeating tile with
/// `5%` foreground opacity fading out vertically across the top bar & safe zone).
class _AdwDevelStripesPainter extends CustomPainter {
  final Color color;

  const _AdwDevelStripesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final double fadeHeight = size.height < 50.207 ? 50.207 : size.height;
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.05),
        color.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, fadeHeight));

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill;

    final double h = size.height;
    final double dx = h * 0.5;
    final path = Path();
    for (double x = -64.0; x < size.width + dx + 64.0; x += 64.0) {
      path
        ..moveTo(x, 0)
        ..lineTo(x + 32.0, 0)
        ..lineTo(x + 32.0 - dx, h)
        ..lineTo(x - dx, h)
        ..close();
    }
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AdwDevelStripesPainter oldDelegate) =>
      oldDelegate.color != color;
}
