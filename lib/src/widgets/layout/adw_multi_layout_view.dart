import 'package:flutter/widgets.dart';

/// A named layout definition for [AdwMultiLayoutView] (`AdwLayout`).
class AdwLayout {
  final String name;
  final Widget content;

  const AdwLayout({
    required this.name,
    required this.content,
  });
}

/// Placeholder slot inside an [AdwLayout] that renders the child widget
/// registered under [id] in the enclosing [AdwMultiLayoutView] (`AdwLayoutSlot`).
class AdwLayoutSlot extends StatelessWidget {
  final String id;

  const AdwLayoutSlot({
    super.key,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    final scope = _AdwMultiLayoutScope.maybeOf(context);
    return scope?.children[id] ?? const SizedBox.shrink();
  }
}

/// Container that switches between multiple [AdwLayout] definitions while
/// reusing named slot [children] across layouts (`AdwMultiLayoutView`).
class AdwMultiLayoutView extends StatelessWidget {
  final List<AdwLayout> layouts;
  final String? layoutName;
  final Map<String, Widget> children;

  const AdwMultiLayoutView({
    super.key,
    required this.layouts,
    this.layoutName,
    this.children = const <String, Widget>{},
  });

  @override
  Widget build(BuildContext context) {
    if (layouts.isEmpty) {
      return const SizedBox.shrink();
    }

    AdwLayout activeLayout = layouts.first;
    if (layoutName != null) {
      for (final layout in layouts) {
        if (layout.name == layoutName) {
          activeLayout = layout;
          break;
        }
      }
    }

    return _AdwMultiLayoutScope(
      children: children,
      child: activeLayout.content,
    );
  }
}

class _AdwMultiLayoutScope extends InheritedWidget {
  final Map<String, Widget> children;

  const _AdwMultiLayoutScope({
    required this.children,
    required super.child,
  });

  static _AdwMultiLayoutScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_AdwMultiLayoutScope>();
  }

  @override
  bool updateShouldNotify(_AdwMultiLayoutScope oldWidget) {
    return children != oldWidget.children;
  }
}
