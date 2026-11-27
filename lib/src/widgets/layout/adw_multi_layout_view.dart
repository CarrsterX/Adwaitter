import 'package:flutter/widgets.dart';

/// A named layout definition for [AdwMultiLayoutView] (`AdwLayout`).
///
/// {@category Layout}
class AdwLayout {
  /// Unique name identifying this layout (matched by [AdwMultiLayoutView.layoutName]).
  final String name;

  /// Widget tree containing [AdwLayoutSlot] placeholders for this layout.
  final Widget content;

  /// Creates a named layout definition.
  const AdwLayout({
    required this.name,
    required this.content,
  });
}

/// Placeholder slot inside an [AdwLayout] that renders the child widget
/// registered under [id] in the enclosing [AdwMultiLayoutView] (`AdwLayoutSlot`).
///
/// {@category Layout}
class AdwLayoutSlot extends StatelessWidget {
  /// Key matching an entry in [AdwMultiLayoutView.children].
  final String id;

  /// Creates a named slot placeholder inside an [AdwLayout].
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
///
/// ```dart
/// AdwMultiLayoutView(
///   layoutName: isWide ? 'wide' : 'compact',
///   children: const {'main': Text('Shared Child')},
///   layouts: const [
///     AdwLayout(name: 'wide', content: Row(children: [AdwLayoutSlot(id: 'main')])),
///     AdwLayout(name: 'compact', content: Column(children: [AdwLayoutSlot(id: 'main')])),
///   ],
/// )
/// ```
///
/// See also:
///
/// * [AdwBreakpointBin], for driving [layoutName] from viewport breakpoints.
///
/// {@category Layout}
class AdwMultiLayoutView extends StatelessWidget {
  /// Available named layout definitions.
  final List<AdwLayout> layouts;

  /// Active layout name matching one of [layouts]. Falls back to the first
  /// layout when `null` or unmatched.
  final String? layoutName;

  /// Shared child widgets indexed by slot ID and rendered via [AdwLayoutSlot].
  final Map<String, Widget> children;

  /// Creates a multi-layout container.
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
