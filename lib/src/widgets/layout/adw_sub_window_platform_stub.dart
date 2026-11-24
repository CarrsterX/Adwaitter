// ignore_for_file: invalid_use_of_internal_member, invalid_use_of_protected_member, implementation_imports

import 'package:flutter/src/widgets/_window.dart';
import 'package:flutter/widgets.dart';

void ensureLinuxWindowingOwner(WidgetsBinding binding) {}

bool registerLinuxRootWindowHandles(
  WidgetsBinding binding, {
  required int windowHandle,
  required int viewHandle,
  int? implicitViewId,
}) =>
    false;

WindowController? createLinuxSubWindow({
  required WidgetsBinding binding,
  required WindowControllerDelegate delegate,
  required Size size,
  required BoxConstraints? constraints,
  required String title,
  required int? parentViewId,
}) =>
    null;

void configureLinuxPopupWindow(PopupWindowController popupController) {}
