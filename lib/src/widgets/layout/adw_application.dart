import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart'
    show LogicalKeyboardKey, MethodChannel, SystemNavigator;
import 'package:flutter/widgets.dart';

import '../../core/adw_insets.dart';
import '../../core/adw_scroll_behavior.dart';
import '../../theme/adw_colors.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_desktop_settings.dart';
import '../../theme/adw_style_manager.dart';
import '../../theme/adw_theme.dart';
import '../navigation/adw_navigation_transition.dart';
import '../navigation/adw_navigation_view.dart';
import 'adw_sub_window.dart';
import 'adw_window.dart';

/// Root application widget for applications built with Libadwaitter.
///
/// Sets up the widget tree, navigation, dual theme switching (light/dark),
/// brightness observer, desktop environment animation settings sync,
/// transversal [AdwScrollBehavior], and Adwaita typography.
class AdwApplication extends StatefulWidget {
  final String title;
  final Widget? home;
  final Map<String, WidgetBuilder> routes;
  final String? initialRoute;
  final RouteFactory? onGenerateRoute;
  final TransitionBuilder? builder;
  final AdwThemeData? theme;
  final AdwThemeData? darkTheme;
  final AdwThemeMode themeMode;
  final AdwAccentColor? accentColor;
  final ScrollBehavior? scrollBehavior;

  const AdwApplication({
    super.key,
    this.title = '',
    this.home,
    this.routes = const <String, WidgetBuilder>{},
    this.initialRoute,
    this.onGenerateRoute,
    this.builder,
    this.theme,
    this.darkTheme,
    this.themeMode = AdwThemeMode.system,
    this.accentColor,
    this.scrollBehavior,
  });

  @override
  State<AdwApplication> createState() => _AdwApplicationState();
}

class _AdwApplicationState extends State<AdwApplication> with WidgetsBindingObserver {
  final ValueNotifier<BorderRadius> _windowBorderRadius =
      ValueNotifier<BorderRadius>(BorderRadius.zero);
  AppLifecycleState? _appLifecycleState;
  FocusNode? _lastAutoScrolledFocus;

  @override
  void initState() {
    super.initState();
    _appLifecycleState = WidgetsBinding.instance.lifecycleState;
    AdwSubWindowManager.ensureInitialized();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onGlobalFocusChanged);
    AdwDesktopSettings.initialize();
    AdwStyleManager.initialize();
    AdwStyleManager.instance.addListener(_onStyleChanged);
    AdwDesktopSettings.contrastLevel.addListener(_onStyleChanged);
    AdwDesktopSettings.highTextContrast.addListener(_onStyleChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onGlobalFocusChanged);
    _windowBorderRadius.dispose();
    AdwDesktopSettings.contrastLevel.removeListener(_onStyleChanged);
    AdwDesktopSettings.highTextContrast.removeListener(_onStyleChanged);
    AdwStyleManager.instance.removeListener(_onStyleChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onGlobalFocusChanged() {
    if (FocusManager.instance.highlightMode != FocusHighlightMode.traditional) {
      return;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary == _lastAutoScrolledFocus) return;
    _lastAutoScrolledFocus = primary;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = primary.context;
      if (ctx == null || !ctx.mounted) return;
      final scrollable = Scrollable.maybeOf(ctx);
      if (scrollable == null) return;
      final itemBox = ctx.findRenderObject();
      final viewportBox = scrollable.context.findRenderObject();
      if (itemBox is! RenderBox ||
          viewportBox is! RenderBox ||
          !itemBox.attached ||
          !viewportBox.attached ||
          !itemBox.hasSize ||
          !viewportBox.hasSize) {
        return;
      }
      final topLeft =
          itemBox.localToGlobal(Offset.zero, ancestor: viewportBox);
      final bottomRight = itemBox.localToGlobal(
        itemBox.size.bottomRight(Offset.zero),
        ancestor: viewportBox,
      );
      const double margin = 12.0;
      ScrollPositionAlignmentPolicy? policy;
      if (topLeft.dy < margin) {
        policy = ScrollPositionAlignmentPolicy.keepVisibleAtStart;
      } else if (bottomRight.dy > viewportBox.size.height - margin) {
        policy = ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
      }
      if (policy != null) {
        Scrollable.ensureVisible(
          ctx,
          alignmentPolicy: policy,
          duration: AdwCurves.resolve(ctx, AdwCurves.shortDuration),
          curve: AdwCurves.standard,
        );
      }
    });
  }

  void _onStyleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      AdwStyleManager.instance.refreshSystemAppearance();
    }
  }

  @override
  void didChangePlatformBrightness() {
    AdwStyleManager.instance.handlePlatformBrightnessChanged();
    setState(() {});
  }

  static const MethodChannel _styleChannel = MethodChannel('libadwaitter/style');
  Color? _lastNativeBackground;

  /// Keeps the Android Activity window background equal to the Adwaita window
  /// background so no white frame is exposed while the surface is resized
  /// (virtual keyboard, popovers with search, etc.).
  void _syncNativeWindowBackground(Color color) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_lastNativeBackground == color) return;
    _lastNativeBackground = color;
    _styleChannel
        .invokeMethod<void>('setWindowBackground', <String, Object>{
      'color': color.toARGB32(),
    }).catchError((_) {});
  }

  bool _hasAnyPoppableNavigator() {
    final navContext = AdwSubWindowManager.instance.navigatorKey.currentContext;
    if (navContext == null) return false;
    bool found = false;
    void visit(Element element) {
      if (found) return;
      if (element is StatefulElement && element.state is NavigatorState) {
        final navState = element.state as NavigatorState;
        final adwObserver = navState.widget.observers
            .whereType<AdwNavigationViewObserver>()
            .firstOrNull;
        final bool canPop = adwObserver != null
            ? adwObserver.controller.canPop
            : navState.canPop();
        if (canPop) {
          found = true;
          return;
        }
      }
      element.visitChildren(visit);
    }

    navContext.visitChildElements(visit);
    return found;
  }

  bool _handleNavigationNotification(NavigationNotification notification) {
    switch (_appLifecycleState) {
      case null:
      case AppLifecycleState.detached:
        return true;
      case AppLifecycleState.inactive:
      case AppLifecycleState.resumed:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        final bool effectiveCanHandlePop =
            notification.canHandlePop || _hasAnyPoppableNavigator();
        SystemNavigator.setFrameworkHandlesBack(effectiveCanHandlePop);
        return true;
    }
  }

  bool _isDarkMode(BuildContext context) {
    switch (widget.themeMode) {
      case AdwThemeMode.dark:
        return true;
      case AdwThemeMode.light:
        return false;
      case AdwThemeMode.system:
        return AdwStyleManager.instance.isDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = widget.accentColor ?? AdwStyleManager.instance.accentColor;
    final Color? effectiveCustomAccent = widget.accentColor == null
        ? AdwStyleManager.instance.resolvedCustomAccentColor
        : null;

    return WidgetsApp(
      navigatorKey: AdwSubWindowManager.instance.navigatorKey,
      title: widget.title,
      color: effectiveCustomAccent ?? effectiveAccent.color,
      debugShowCheckedModeBanner: false,
      onNavigationNotification: _handleNavigationNotification,
      routes: widget.routes,
      initialRoute: widget.initialRoute,
      onGenerateRoute: widget.onGenerateRoute,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return AdwNavigationPageRoute<T>(
          settings: settings,
          builder: builder,
        );
      },
      home: widget.home,
      builder: (context, child) {
        final isDark = _isDarkMode(context);
        final baseTheme = isDark
            ? (widget.darkTheme ??
                AdwThemeData.dark(
                  accent: effectiveAccent,
                  accentColorOverride: effectiveCustomAccent,
                ))
            : (widget.theme ??
                AdwThemeData.light(
                  accent: effectiveAccent,
                  accentColorOverride: effectiveCustomAccent,
                ));
        final androidContrast = AdwDesktopSettings.contrastLevel.value;
        final androidHighText = AdwDesktopSettings.highTextContrast.value;
        final effectiveContrast = AdwStyleManager.instance.highContrast
            ? 1.0
            : androidContrast;
        final defaultTheme = (effectiveContrast >= 0.25 || androidHighText)
            ? baseTheme.withHighContrast(
                level: effectiveContrast,
                highTextContrast: androidHighText,
              )
            : baseTheme;
        _syncNativeWindowBackground(defaultTheme.colors.windowBackground);

        final clippedNavigator = ValueListenableBuilder<BorderRadius>(
          valueListenable: _windowBorderRadius,
          builder: (context, radius, navChild) {
            return _AdwWindowShadowFrame(
              radius: radius,
              isDark: defaultTheme.colors.isDark,
              child: navChild ?? const SizedBox.shrink(),
            );
          },
          child: child ?? const SizedBox.shrink(),
        );

        final content = DefaultTextStyle(
          style: defaultTheme.typography.body,
          child: clippedNavigator,
        );

        return ValueListenableBuilder<AdwAnimationSettings>(
          valueListenable: AdwDesktopSettings.animationSettings,
          builder: (context, animSettings, _) {
            return ValueListenableBuilder<double>(
              valueListenable: AdwDesktopSettings.textScalingFactor,
              builder: (context, textScale, _) {
                final Widget inner = widget.builder != null
                    ? widget.builder!(context, content)
                    : content;
                final MediaQueryData? mq = MediaQuery.maybeOf(context);
                final bool disableAnims = !animSettings.enableAnimations;
                final Widget scaledInner =
                    (mq != null && (textScale != 1.0 || disableAnims))
                        ? MediaQuery(
                            data: mq.copyWith(
                              textScaler: textScale != 1.0
                                  ? TextScaler.linear(textScale)
                                  : mq.textScaler,
                              disableAnimations:
                                  disableAnims || mq.disableAnimations,
                            ),
                            child: inner,
                          )
                        : inner;
                final themedChild = AdwTheme(
                  data: defaultTheme,
                  child: AdwAnimationScope(
                    settings: animSettings,
                    child: AdwWindowShapeScope(
                      borderRadiusNotifier: _windowBorderRadius,
                      child: ScrollConfiguration(
                        behavior:
                            widget.scrollBehavior ?? const AdwScrollBehavior(),
                        child: scaledInner,
                      ),
                    ),
                  ),
                );

            return ListenableBuilder(
              listenable: AdwSubWindowManager.instance,
              builder: (context, appSubtree) {
                final handles = AdwSubWindowManager.instance.windows
                    .where((handle) => handle.isNativeWindow);
                final popups = AdwSubWindowManager.instance.popups;
                final subViews = <Widget>[
                  ...handles.map((handle) {
                    return AdwSubWindowManager.buildWindowView(
                      handle: handle,
                      child: _AdwSubWindowHost(
                        handle: handle,
                        theme: defaultTheme,
                        animSettings: animSettings,
                        accentColor: effectiveAccent.color,
                        scrollBehavior:
                            widget.scrollBehavior ?? const AdwScrollBehavior(),
                      ),
                    );
                  }),
                  ...popups.map((entry) {
                    return AdwSubWindowManager.buildPopupView(
                      entry: entry,
                      child: _AdwPopupWindowHost(
                        entry: entry,
                        theme: defaultTheme,
                        animSettings: animSettings,
                        textDirection:
                            Directionality.maybeOf(context) ?? TextDirection.ltr,
                        scrollBehavior:
                            widget.scrollBehavior ?? const AdwScrollBehavior(),
                      ),
                    );
                  }),
                ];

                return ViewAnchor(
                  view: subViews.isEmpty
                      ? null
                      : ViewCollection(views: subViews),
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) =>
                        AdwSubWindowManager.instance.dismissAllPopups(),
                    child: appSubtree!,
                  ),
                );
              },
              child: themedChild,
            );
              },
            );
          },
        );
      },
    );
  }
}

class _AdwSubWindowHost extends StatefulWidget {
  final AdwSubWindowHandle handle;
  final AdwThemeData theme;
  final AdwAnimationSettings animSettings;
  final Color accentColor;
  final ScrollBehavior scrollBehavior;

  const _AdwSubWindowHost({
    required this.handle,
    required this.theme,
    required this.animSettings,
    required this.accentColor,
    required this.scrollBehavior,
  });

  @override
  State<_AdwSubWindowHost> createState() => _AdwSubWindowHostState();
}

class _AdwSubWindowHostState extends State<_AdwSubWindowHost> {
  final FocusScopeNode _windowFocusScope = FocusScopeNode(
    debugLabel: 'AdwSubWindow',
  );

  @override
  void initState() {
    super.initState();
    widget.handle.adwController.activeListenable?.addListener(_onActiveChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _windowFocusScope.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AdwSubWindowHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) {
      oldWidget.handle.adwController.activeListenable
          ?.removeListener(_onActiveChanged);
      widget.handle.adwController.activeListenable
          ?.addListener(_onActiveChanged);
    }
  }

  void _onActiveChanged() {
    if (mounted && widget.handle.adwController.isActive) {
      _windowFocusScope.requestFocus();
    }
  }

  @override
  void dispose() {
    widget.handle.adwController.activeListenable
        ?.removeListener(_onActiveChanged);
    _windowFocusScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: widget.handle.title,
      color: widget.accentColor,
      debugShowCheckedModeBanner: false,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return AdwNavigationPageRoute<T>(
          settings: settings,
          builder: builder,
        );
      },
      home: FocusScope(
        node: _windowFocusScope,
        autofocus: true,
        child: Builder(
          builder: (innerContext) => AdwBottomInsetConsumer(
            // Secondary/modal windows are not edge-to-edge with the system
            // navbar, so they must not reserve its inset.
            child: AdwWindow(
              controller: widget.handle.adwController,
              child: widget.handle.builder(innerContext, widget.handle),
            ),
          ),
        ),
      ),
      builder: (context, child) {
        final clippedNavigator = ValueListenableBuilder<BorderRadius>(
          valueListenable: widget.handle.borderRadiusNotifier,
          builder: (context, radius, navChild) {
            return _AdwWindowShadowFrame(
              radius: radius,
              isDark: widget.theme.colors.isDark,
              child: navChild ?? const SizedBox.shrink(),
            );
          },
          child: child ?? const SizedBox.shrink(),
        );

        final content = DefaultTextStyle(
          style: widget.theme.typography.body,
          child: clippedNavigator,
        );

        return AdwTheme(
          data: widget.theme,
          child: AdwAnimationScope(
            settings: widget.animSettings,
            child: AdwWindowShapeScope(
              borderRadiusNotifier: widget.handle.borderRadiusNotifier,
              child: ScrollConfiguration(
                behavior: widget.scrollBehavior,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) =>
                      AdwSubWindowManager.instance.dismissAllPopups(),
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdwPopupWindowHost extends StatelessWidget {
  final AdwPopupWindowEntry entry;
  final AdwThemeData theme;
  final AdwAnimationSettings animSettings;
  final TextDirection textDirection;
  final ScrollBehavior scrollBehavior;

  const _AdwPopupWindowHost({
    required this.entry,
    required this.theme,
    required this.animSettings,
    required this.textDirection,
    required this.scrollBehavior,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: textDirection,
      child: AdwTheme(
        data: theme,
        child: AdwAnimationScope(
          settings: animSettings,
          child: ScrollConfiguration(
            behavior: scrollBehavior,
            child: DefaultTextStyle(
              style: theme.typography.body,
              child: Shortcuts(
                shortcuts: WidgetsApp.defaultShortcuts,
                child: Actions(
                  actions: WidgetsApp.defaultActions,
                  child: CallbackShortcuts(
                    bindings: <ShortcutActivator, VoidCallback>{
                      const SingleActivator(LogicalKeyboardKey.escape):
                          entry.onDismiss,
                    },
                    child: FocusScope(
                      autofocus: true,
                      child: FocusTraversalGroup(
                        child: entry.child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal scope allowing [AdwWindow] to synchronize its rounded window clip
/// with the root [Navigator] overlay so modal scrims and popovers respect CSD corners.
class AdwWindowShapeScope extends InheritedWidget {
  final ValueNotifier<BorderRadius> borderRadiusNotifier;

  const AdwWindowShapeScope({
    super.key,
    required this.borderRadiusNotifier,
    required super.child,
  });

  static AdwWindowShapeScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdwWindowShapeScope>();
  }

  @override
  bool updateShouldNotify(covariant AdwWindowShapeScope oldWidget) {
    return borderRadiusNotifier != oldWidget.borderRadiusNotifier;
  }
}

/// Renders the transparent Linux CSD shadow margin and Libadwaita drop shadow
/// outside the rounded [ClipRRect] using a shared tiny 9-slice GPU texture
/// (matching GTK4/GSK `GskOutsetShadowNode`) instead of full-window blur
/// offscreen buffers, saving tens of megabytes of VRAM across windows.
class _AdwWindowShadowFrame extends StatelessWidget {
  static const double linuxShadowMargin = 24.0;

  final BorderRadius radius;
  final bool isDark;
  final Widget child;

  const _AdwWindowShadowFrame({
    required this.radius,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (radius == BorderRadius.zero) {
      return child;
    }

    final clipped = ClipRRect(
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.linux) {
      return clipped;
    }

    return CustomPaint(
      painter: _AdwWindowShadowPainter(
        radius: radius,
        isDark: isDark,
      ),
      child: Padding(
        padding: const EdgeInsets.all(linuxShadowMargin),
        child: clipped,
      ),
    );
  }
}

/// Shared 144x144 9-slice shadow texture cache (~82 KB VRAM per theme, reused
/// across main and child windows with zero full-window blur allocations).
class _AdwNineSliceShadowCache {
  static const int textureSize = 144;
  static const double margin = _AdwWindowShadowFrame.linuxShadowMargin;
  static const Rect centerSlice = Rect.fromLTRB(68, 68, 76, 76);

  static final Map<String, ui.Image> _cache = <String, ui.Image>{};

  static const List<BoxShadow> _darkShadows = [
    BoxShadow(
      color: Color(0x52000000),
      blurRadius: 24.0,
      spreadRadius: 0.0,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x30000000),
      blurRadius: 8.0,
      spreadRadius: 0.0,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> _lightShadows = [
    BoxShadow(
      color: Color(0x2E000006),
      blurRadius: 24.0,
      spreadRadius: 0.0,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x1A000006),
      blurRadius: 6.0,
      spreadRadius: 0.0,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x14000006),
      blurRadius: 1.0,
      spreadRadius: 0.5,
      offset: Offset.zero,
    ),
  ];

  static ui.Image getOrCreate({
    required BorderRadius radius,
    required bool isDark,
  }) {
    final key = '${isDark ? 'd' : 'l'}:${radius.topLeft.x.toStringAsFixed(1)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, textureSize.toDouble(), textureSize.toDouble()),
    );
    final innerRect = Rect.fromLTWH(
      margin,
      margin,
      textureSize - margin * 2,
      textureSize - margin * 2,
    );

    final shadows = isDark ? _darkShadows : _lightShadows;
    for (final shadow in shadows) {
      final shadowRect = innerRect
          .shift(shadow.offset)
          .inflate(shadow.spreadRadius);
      final rrect = radius.toRRect(shadowRect);
      final paint = Paint()..color = shadow.color;
      if (shadow.blurRadius > 0) {
        paint.maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          shadow.blurSigma,
        );
      }
      canvas.drawRRect(rrect, paint);
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(textureSize, textureSize);
    picture.dispose();
    _cache[key] = image;
    return image;
  }
}

class _AdwWindowShadowPainter extends CustomPainter {
  final BorderRadius radius;
  final bool isDark;

  const _AdwWindowShadowPainter({
    required this.radius,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final image = _AdwNineSliceShadowCache.getOrCreate(
      radius: radius,
      isDark: isDark,
    );
    final paint = Paint()..filterQuality = FilterQuality.low;
    canvas.drawImageNine(
      image,
      _AdwNineSliceShadowCache.centerSlice,
      Offset.zero & size,
      paint,
    );
  }

  @override
  bool shouldRepaint(_AdwWindowShadowPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.isDark != isDark;
}
