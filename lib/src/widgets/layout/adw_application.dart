import 'package:flutter/widgets.dart';

import '../../core/adw_scroll_behavior.dart';
import '../../theme/adw_colors.dart';
import '../../theme/adw_desktop_settings.dart';
import '../../theme/adw_style_manager.dart';
import '../../theme/adw_theme.dart';
import '../navigation/adw_navigation_transition.dart';
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

  @override
  void initState() {
    super.initState();
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
  void didChangePlatformBrightness() {
    AdwStyleManager.instance.handlePlatformBrightnessChanged();
    setState(() {});
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

    return WidgetsApp(
      title: widget.title,
      color: effectiveAccent.color,
      debugShowCheckedModeBanner: false,
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
            ? (widget.darkTheme ?? AdwThemeData.dark(accent: effectiveAccent))
            : (widget.theme ?? AdwThemeData.light(accent: effectiveAccent));

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
                final handles = AdwSubWindowManager.instance.windows;
                final subViews = handles.map((handle) {
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
                }).toList();

                return ViewAnchor(
                  view: subViews.isEmpty
                      ? null
                      : ViewCollection(views: subViews),
                  child: appSubtree!,
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
                child: content,
              ),
            ),
          ),
        );
      },
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
