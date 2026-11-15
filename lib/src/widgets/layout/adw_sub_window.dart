// ignore_for_file: invalid_use_of_internal_member, implementation_imports

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter/src/foundation/_features.dart' as flutter_features;
import 'package:flutter/src/widgets/_window.dart';
import 'package:flutter/src/widgets/_window_linux.dart';
import 'package:flutter/widgets.dart';

import 'adw_window.dart';

/// Builder signature for content hosted inside a native secondary [AdwWindow].
typedef AdwSubWindowBuilder = Widget Function(
  BuildContext context,
  AdwSubWindowHandle window,
);

/// Active handle to a native secondary window managed by [AdwSubWindowManager].
class AdwSubWindowHandle {
  final WindowController windowController;
  final AdwNativeWindowController adwController;
  final ValueNotifier<BorderRadius> borderRadiusNotifier =
      ValueNotifier<BorderRadius>(BorderRadius.zero);
  final AdwSubWindowBuilder builder;
  final VoidCallback? onClosed;
  bool _isClosed = false;

  AdwSubWindowHandle._({
    required this.windowController,
    required this.adwController,
    required this.builder,
    this.onClosed,
  });

  int get viewId => windowController.rootView.viewId;

  String get title => windowController.title;

  void setTitle(String title) {
    if (!_isClosed && !windowController.isDestroyed) {
      windowController.setTitle(title);
    }
  }

  void activate() {
    if (!_isClosed && !windowController.isDestroyed) {
      windowController.activate();
    }
  }

  void close() {
    AdwSubWindowManager.instance.closeWindow(this);
  }
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

/// Manages native secondary desktop windows using Flutter's multi-window engine
/// (`WindowController` / `Window` / `ViewCollection`) paired with Libadwaitter's
/// CSD pipeline (`AdwWindow`, `AdwNativeWindowController`).
class AdwSubWindowManager extends ChangeNotifier {
  AdwSubWindowManager._();

  static final AdwSubWindowManager instance = AdwSubWindowManager._();

  final List<AdwSubWindowHandle> _windows = <AdwSubWindowHandle>[];

  List<AdwSubWindowHandle> get windows =>
      List<AdwSubWindowHandle>.unmodifiable(_windows);

  /// Ensures Flutter's native windowing subsystem is enabled.
  static void ensureInitialized() {
    flutter_features.isWindowingEnabled = true;
    final binding = WidgetsBinding.instance;
    if (!kIsWeb &&
        Platform.isLinux &&
        binding.windowingOwner is! WindowingOwnerLinux) {
      binding.windowingOwner = createDefaultWindowingOwner();
    }
  }

  /// Opens a new native top-level secondary [AdwWindow] sharing the current
  /// Dart isolate and theme state.
  AdwSubWindowHandle openWindow({
    Size size = const Size(800, 600),
    BoxConstraints? constraints = const BoxConstraints(
      minWidth: 360,
      minHeight: 294,
    ),
    String title = '',
    int? parentViewId = 0,
    required AdwSubWindowBuilder builder,
    VoidCallback? onClosed,
  }) {
    ensureInitialized();

    late final AdwSubWindowHandle handle;
    final delegate = _AdwSubWindowDelegate(
      onDestroyedCallback: () {
        closeWindow(handle);
      },
    );

    final WindowController controller;
    if (!kIsWeb && Platform.isLinux) {
      final owner =
          WidgetsBinding.instance.windowingOwner as WindowingOwnerLinux;
      final linuxController = WindowControllerLinux(
        owner: owner,
        delegate: delegate,
        size: size,
        constraints: constraints,
        title: title,
        decorated: false,
      );
      linuxController.setAppPaintable(true);
      linuxController.setBackgroundColor(const Color(0x00000000));
      AdwNativeWindowController.attachSubWindow(
        windowHandle: linuxController.windowHandle.address,
        viewHandle: linuxController.flutterViewHandle.address,
        viewId: linuxController.rootView.viewId,
        parentViewId: parentViewId,
      );
      controller = linuxController;
    } else {
      controller = WindowController(
        size: size,
        constraints: constraints,
        title: title,
        delegate: delegate,
      );
    }

    final adwController = AdwNativeWindowController(
      viewId: controller.rootView.viewId,
      onCloseOverride: () => closeWindow(handle),
    );

    handle = AdwSubWindowHandle._(
      windowController: controller,
      adwController: adwController,
      builder: builder,
      onClosed: onClosed,
    );

    _windows.add(handle);
    notifyListeners();
    return handle;
  }

  /// Closes and destroys an active secondary window.
  void closeWindow(AdwSubWindowHandle handle) {
    if (handle._isClosed) return;
    handle._isClosed = true;
    _windows.remove(handle);
    handle.adwController.dispose();
    handle.borderRadiusNotifier.dispose();
    if (!handle.windowController.isDestroyed) {
      handle.windowController.destroy();
    }
    handle.onClosed?.call();
    notifyListeners();
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
      controller: handle.windowController,
      child: child,
    );
  }
}

