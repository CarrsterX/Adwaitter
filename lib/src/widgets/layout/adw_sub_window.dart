// ignore_for_file: invalid_use_of_internal_member, invalid_use_of_protected_member, implementation_imports

import 'dart:ui' show Display, FlutterView;

import 'package:flutter/foundation.dart'
    show
        ChangeNotifier,
        TargetPlatform,
        ValueListenable,
        defaultTargetPlatform,
        kIsWeb;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/src/foundation/_features.dart' as flutter_features;
import 'package:flutter/src/widgets/_window.dart';
import 'package:flutter/widgets.dart';

import '../navigation/adw_navigation_transition.dart';
import 'adw_sub_window_platform_stub.dart'
    if (dart.library.io) 'adw_sub_window_platform_io.dart'
    as sub_window_platform;
import 'adw_window.dart';

/// Builder signature for content hosted inside a native secondary [AdwWindow]
/// or fallback additional screen on non-Linux platforms.
typedef AdwSubWindowBuilder = Widget Function(
  BuildContext context,
  AdwSubWindowHandle window,
);

/// Active handle to a secondary window (native on Linux, or an additional
/// pushed screen on non-Linux platforms) managed by [AdwSubWindowManager].
class AdwSubWindowHandle {
  final WindowController? windowController;
  final AdwWindowController adwController;
  final ValueNotifier<BorderRadius> borderRadiusNotifier =
      ValueNotifier<BorderRadius>(BorderRadius.zero);
  final AdwSubWindowBuilder builder;
  final VoidCallback? onClosed;
  final int _fallbackViewId;
  Route<void>? _fallbackRoute;
  bool _isClosed = false;

  AdwSubWindowHandle._({
    required this.windowController,
    required this.adwController,
    required this.builder,
    required int fallbackViewId,
    this.onClosed,
  }) : _fallbackViewId = fallbackViewId;

  bool get isNativeWindow => windowController != null;

  int get viewId => windowController?.rootView.viewId ?? _fallbackViewId;

  String get title => windowController?.title ?? '';

  void setTitle(String title) {
    if (!_isClosed &&
        windowController != null &&
        !windowController!.isDestroyed) {
      windowController!.setTitle(title);
    }
  }

  void activate() {
    if (!_isClosed &&
        windowController != null &&
        !windowController!.isDestroyed) {
      windowController!.activate();
    }
  }

  void close() {
    AdwSubWindowManager.instance.closeWindow(this);
  }
}

/// Entry for a native floating popup window managed by [AdwSubWindowManager].
class AdwPopupWindowEntry {
  final PopupWindowController controller;
  final Widget child;
  final VoidCallback onDismiss;

  AdwPopupWindowEntry({
    required this.controller,
    required this.child,
    required this.onDismiss,
  });
}

class _AdwSubWindowDelegate with WindowControllerDelegate {
  final void Function() onDestroyedCallback;

  _AdwSubWindowDelegate({required this.onDestroyedCallback});

  @override
  void onWindowCloseRequested(WindowController controller) {
    onDestroyedCallback();
  }

  @override
  void onWindowDestroyed() {
    onDestroyedCallback();
  }
}

class _RootWindowController extends WindowController {
  _RootWindowController(FlutterView view) : super.empty() {
    rootView = view;
  }

  @override
  void activate() {}

  @override
  Size get contentSize =>
      rootView.physicalSize / rootView.devicePixelRatio;

  @override
  void destroy() {}

  @override
  bool get isActivated => true;

  @override
  bool get isDestroyed => false;

  @override
  bool get isFullscreen => false;

  @override
  bool get isMaximized => false;

  @override
  bool get isMinimized => false;

  @override
  void setConstraints(BoxConstraints constraints) {}

  @override
  void setFullscreen(bool fullscreen, {Display? display}) {}

  @override
  void setMaximized(bool maximized) {}

  @override
  void setMinimized(bool minimized) {}

  @override
  void setSize(Size size) {}

  @override
  void setTitle(String title) {}

  @override
  String get title => '';
}

class _ScreenWindowController implements AdwWindowController {
  final VoidCallback onClose;

  _ScreenWindowController({required this.onClose});

  @override
  bool get isMaximized => true;

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
  void close() => onClose();

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

/// Manages native secondary desktop windows and popup windows on Linux using
/// Flutter's multi-window engine (`WindowController` / `PopupWindowController`
/// / `ViewCollection`), and automatically falls back to additional in-app
/// screens (`AdwNavigationPageRoute`) on non-Linux platforms.
class AdwSubWindowManager extends ChangeNotifier {
  AdwSubWindowManager._();

  static final AdwSubWindowManager instance = AdwSubWindowManager._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final List<AdwSubWindowHandle> _windows = <AdwSubWindowHandle>[];
  final List<AdwPopupWindowEntry> _popups = <AdwPopupWindowEntry>[];

  int _nextFallbackViewId = -1;
  _RootWindowController? _rootWindowController;
  Future<bool>? _rootRegistrationFuture;
  bool _rootWindowRegistered = false;
  static bool _nativeWindowingUnavailable = false;

  List<AdwSubWindowHandle> get windows =>
      List<AdwSubWindowHandle>.unmodifiable(_windows);

  List<AdwPopupWindowEntry> get popups =>
      List<AdwPopupWindowEntry>.unmodifiable(_popups);

  bool get isRootWindowRegistered => _rootWindowRegistered;

  static bool get isNativeLinuxWindowingSupported =>
      !_nativeWindowingUnavailable &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.linux &&
      WidgetsBinding.instance.platformDispatcher.engineId != null;

  /// Ensures Flutter's native windowing subsystem is enabled on Linux.
  static void ensureInitialized() {
    if (!isNativeLinuxWindowingSupported) return;
    flutter_features.isWindowingEnabled = true;
    final binding = WidgetsBinding.instance;
    sub_window_platform.ensureLinuxWindowingOwner(binding);
    instance._ensureRootController();
    instance.ensureRootWindowRegistered();
  }

  void _ensureRootController() {
    final implicitView = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (implicitView != null && _rootWindowController == null) {
      _rootWindowController = _RootWindowController(implicitView);
    }
  }

  /// Ensures the primary Linux GTK window (`viewId == 0`) is registered in
  /// `WindowingOwnerLinux.registrar` so `PopupWindowController` can anchor to it.
  Future<bool> ensureRootWindowRegistered() async {
    if (!isNativeLinuxWindowingSupported) return false;
    if (_rootWindowRegistered) return true;
    if (_rootRegistrationFuture != null) {
      return _rootRegistrationFuture!;
    }
    _rootRegistrationFuture = () async {
      final handles = await AdwNativeWindowController.getWindowHandles(viewId: 0);
      if (handles == null) return false;
      final registered = sub_window_platform.registerLinuxRootWindowHandles(
        WidgetsBinding.instance,
        windowHandle: handles.windowHandle,
        viewHandle: handles.viewHandle,
        implicitViewId:
            WidgetsBinding.instance.platformDispatcher.implicitView?.viewId,
      );
      if (!registered) return false;
      _rootWindowRegistered = true;
      return true;
    }();
    final result = await _rootRegistrationFuture!;
    if (!result) {
      _rootRegistrationFuture = null;
    }
    return result;
  }

  /// Resolves the [BaseWindowController] for the window containing [context].
  BaseWindowController? resolveParentController(BuildContext context) {
    if (!isNativeLinuxWindowingSupported) return null;
    ensureInitialized();
    return WindowScope.maybeOf(context) ?? _rootWindowController;
  }

  /// Opens a secondary [AdwWindow]. On Linux this creates a native OS window;
  /// on non-Linux platforms (or when native windowing is unavailable) it pushes
  /// an additional full screen onto the app's root navigator.
  AdwSubWindowHandle openWindow({
    Size size = const Size(800, 600),
    BoxConstraints? constraints = const BoxConstraints(
      minWidth: 360,
      minHeight: 294,
    ),
    String title = '',
    int? parentViewId = 0,
    BuildContext? context,
    required AdwSubWindowBuilder builder,
    VoidCallback? onClosed,
  }) {
    if (isNativeLinuxWindowingSupported) {
      try {
        ensureInitialized();

        late final AdwSubWindowHandle handle;
        final delegate = _AdwSubWindowDelegate(
          onDestroyedCallback: () {
            closeWindow(handle);
          },
        );

        final linuxController = sub_window_platform.createLinuxSubWindow(
          binding: WidgetsBinding.instance,
          delegate: delegate,
          size: size,
          constraints: constraints,
          title: title,
          parentViewId: parentViewId,
        );
        if (linuxController == null) {
          throw UnsupportedError('Linux sub-window creation unavailable.');
        }

        final adwController = AdwNativeWindowController(
          viewId: linuxController.rootView.viewId,
          onCloseOverride: () => closeWindow(handle),
        );

        handle = AdwSubWindowHandle._(
          windowController: linuxController,
          adwController: adwController,
          fallbackViewId: linuxController.rootView.viewId,
          builder: builder,
          onClosed: onClosed,
        );

        _windows.add(handle);
        notifyListeners();
        return handle;
      } catch (_) {
        _nativeWindowingUnavailable = true;
      }
    }

    // Non-Linux / fallback: present the secondary window as an additional screen.
    late final AdwSubWindowHandle handle;
    final fallbackId = _nextFallbackViewId--;
    final screenController = _ScreenWindowController(
      onClose: () => closeWindow(handle),
    );
    handle = AdwSubWindowHandle._(
      windowController: null,
      adwController: screenController,
      fallbackViewId: fallbackId,
      builder: builder,
      onClosed: onClosed,
    );

    final nav = navigatorKey.currentState ??
        (context != null ? Navigator.maybeOf(context, rootNavigator: true) : null);
    if (nav != null) {
      final route = AdwNavigationPageRoute<void>(
        builder: (routeContext) => AdwWindow(
          controller: handle.adwController,
          showShadow: false,
          showBorder: false,
          child: handle.builder(routeContext, handle),
        ),
      );
      handle._fallbackRoute = route;
      _windows.add(handle);
      nav.push(route).whenComplete(() {
        if (!handle._isClosed) {
          handle._isClosed = true;
          _windows.remove(handle);
          handle.borderRadiusNotifier.dispose();
          handle.onClosed?.call();
          notifyListeners();
        }
      });
    } else {
      _windows.add(handle);
      notifyListeners();
    }

    return handle;
  }

  /// Closes and destroys an active secondary window or pops its fallback screen.
  void closeWindow(AdwSubWindowHandle handle) {
    if (handle._isClosed) return;
    handle._isClosed = true;
    _windows.remove(handle);
    final adwCtrl = handle.adwController;
    if (adwCtrl is AdwNativeWindowController) {
      adwCtrl.dispose();
    }
    handle.borderRadiusNotifier.dispose();
    final winCtrl = handle.windowController;
    if (winCtrl != null && !winCtrl.isDestroyed) {
      winCtrl.destroy();
    } else if (handle._fallbackRoute != null) {
      final route = handle._fallbackRoute!;
      handle._fallbackRoute = null;
      if (route.isActive) {
        route.navigator?.removeRoute(route);
      }
    }
    handle.onClosed?.call();
    notifyListeners();
  }

  bool _deferredNotifyScheduled = false;

  void _notifyListenersSafely() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      if (_deferredNotifyScheduled) return;
      _deferredNotifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _deferredNotifyScheduled = false;
        notifyListeners();
      });
      return;
    }
    notifyListeners();
  }

  /// Registers a floating native [PopupWindow] entry to be rendered in [AdwApplication].
  void registerPopup(AdwPopupWindowEntry entry) {
    _popups.add(entry);
    _notifyListenersSafely();
  }

  /// Unregisters a floating native [PopupWindow] entry.
  void unregisterPopup(AdwPopupWindowEntry entry) {
    if (_popups.remove(entry)) {
      _notifyListenersSafely();
    }
  }

  /// Dismisses all active native floating popups.
  void dismissAllPopups() {
    if (_popups.isEmpty) return;
    final copy = List<AdwPopupWindowEntry>.from(_popups);
    for (final entry in copy) {
      entry.onDismiss();
    }
  }

  /// Builds the [Window] view widget for a [handle] to be placed inside a
  /// [ViewCollection].
  static Widget buildWindowView({
    required AdwSubWindowHandle handle,
    required Widget child,
  }) {
    ensureInitialized();
    return Window(
      key: ValueKey<int>(handle.viewId),
      controller: handle.windowController!,
      child: child,
    );
  }

  /// Builds the [PopupWindow] view widget for a [popup] entry to be placed
  /// inside a [ViewCollection].
  static Widget buildPopupView({
    required AdwPopupWindowEntry entry,
    required Widget child,
  }) {
    ensureInitialized();
    return PopupWindow(
      key: ValueKey<int>(entry.controller.rootView.viewId),
      controller: entry.controller,
      child: child,
    );
  }
}

