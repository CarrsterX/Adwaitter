import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart'
    show LogicalKeyboardKey, MethodChannel, SystemNavigator;
import 'package:flutter/widgets.dart';

import '../../core/adw_scroll_behavior.dart';
import '../../theme/adw_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _appLifecycleState = WidgetsBinding.instance.lifecycleState;
    AdwSubWindowManager.ensureInitialized();
    WidgetsBinding.instance.addObserver(this);
    AdwDesktopSettings.initialize();
    AdwStyleManager.initialize();
    AdwStyleManager.instance.addListener(_onStyleChanged);
  }

  @override
  void dispose() {
    _windowBorderRadius.dispose();
    AdwStyleManager.instance.removeListener(_onStyleChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        final defaultTheme = isDark
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
        _syncNativeWindowBackground(defaultTheme.colors.windowBackground);

        final clippedNavigator = ValueListenableBuilder<BorderRadius>(
          valueListenable: _windowBorderRadius,
          builder: (context, radius, navChild) {
            if (radius == BorderRadius.zero) {
              return navChild ?? const SizedBox.shrink();
            }
            return ClipRRect(
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: navChild,
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
            final themedChild = AdwTheme(
              data: defaultTheme,
              child: AdwAnimationScope(
                settings: animSettings,
                child: AdwWindowShapeScope(
                  borderRadiusNotifier: _windowBorderRadius,
                  child: ScrollConfiguration(
                    behavior: widget.scrollBehavior ?? const AdwScrollBehavior(),
                    child: widget.builder != null
                        ? widget.builder!(context, content)
                        : content,
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
  }
}

class _AdwSubWindowHost extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: handle.title,
      color: accentColor,
      debugShowCheckedModeBanner: false,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return AdwNavigationPageRoute<T>(
          settings: settings,
          builder: builder,
        );
      },
      home: Builder(
        builder: (innerContext) => AdwWindow(
          controller: handle.adwController,
          child: handle.builder(innerContext, handle),
        ),
      ),
      builder: (context, child) {
        final clippedNavigator = ValueListenableBuilder<BorderRadius>(
          valueListenable: handle.borderRadiusNotifier,
          builder: (context, radius, navChild) {
            if (radius == BorderRadius.zero) {
              return navChild ?? const SizedBox.shrink();
            }
            return ClipRRect(
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: navChild,
            );
          },
          child: child ?? const SizedBox.shrink(),
        );

        final content = DefaultTextStyle(
          style: theme.typography.body,
          child: clippedNavigator,
        );

        return AdwTheme(
          data: theme,
          child: AdwAnimationScope(
            settings: animSettings,
            child: AdwWindowShapeScope(
              borderRadiusNotifier: handle.borderRadiusNotifier,
              child: ScrollConfiguration(
                behavior: scrollBehavior,
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
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.escape):
                      entry.onDismiss,
                },
                child: FocusScope(
                  autofocus: true,
                  child: entry.child,
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
