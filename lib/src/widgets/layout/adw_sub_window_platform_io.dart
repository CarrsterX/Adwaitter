// ignore_for_file: invalid_use_of_internal_member, invalid_use_of_protected_member, implementation_imports

import 'dart:ffi' as ffi;

import 'package:flutter/src/widgets/_window.dart';
import 'package:flutter/src/widgets/_window_linux.dart';
import 'package:flutter/widgets.dart';

import 'adw_window.dart';

void ensureLinuxWindowingOwner(WidgetsBinding binding) {
  if (binding.windowingOwner is! WindowingOwnerLinux) {
    binding.windowingOwner = createDefaultWindowingOwner();
  }
}

bool registerLinuxRootWindowHandles(
  WidgetsBinding binding, {
  required int windowHandle,
  required int viewHandle,
  int? implicitViewId,
}) {
  final owner = binding.windowingOwner;
  if (owner is! WindowingOwnerLinux) return false;
  final winPtr = ffi.Pointer<ffi.Void>.fromAddress(windowHandle);
  final viewPtr = ffi.Pointer<ffi.Void>.fromAddress(viewHandle);
  owner.registrar.register(
    viewId: 0,
    windowHandle: winPtr,
    viewHandle: viewPtr,
  );
  if (implicitViewId != null && implicitViewId != 0) {
    owner.registrar.register(
      viewId: implicitViewId,
      windowHandle: winPtr,
      viewHandle: viewPtr,
    );
  }
  return true;
}

WindowController? createLinuxSubWindow({
  required WidgetsBinding binding,
  required WindowControllerDelegate delegate,
  required Size size,
  required BoxConstraints? constraints,
  required String title,
  required int? parentViewId,
}) {
  final owner = binding.windowingOwner as WindowingOwnerLinux;
  final linuxController = WindowControllerLinux(
    owner: owner,
    delegate: delegate,
    size: size,
    constraints: constraints,
    title: title,
    decorated: false,
  );
  owner.registrar.register(
    viewId: linuxController.rootView.viewId,
    windowHandle: linuxController.windowHandle.cast(),
    viewHandle: linuxController.flutterViewHandle.cast(),
  );
  linuxController.setAppPaintable(true);
  linuxController.setBackgroundColor(const Color(0x00000000));
  AdwNativeWindowController.attachSubWindow(
    windowHandle: linuxController.windowHandle.address,
    viewHandle: linuxController.flutterViewHandle.address,
    viewId: linuxController.rootView.viewId,
    parentViewId: parentViewId,
  );
  return linuxController;
}

void configureLinuxPopupWindow(PopupWindowController popupController) {
  if (popupController is PopupWindowControllerLinux) {
    popupController.setAppPaintable(true);
    popupController.setBackgroundColor(const Color(0x00000000));
    AdwNativeWindowController.attachPopupWindow(
      windowHandle: popupController.windowHandle.address,
    );
  }
}
