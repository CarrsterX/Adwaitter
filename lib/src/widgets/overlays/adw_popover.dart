// ignore_for_file: invalid_use_of_internal_member, implementation_imports

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/_window.dart';
import 'package:flutter/src/widgets/_window_linux.dart';
import 'package:flutter/src/widgets/_window_positioner.dart';
import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../layout/adw_sub_window.dart';
import '../layout/adw_window.dart';

/// Anchor points for positioning a floating [AdwPopoverSurface] relative to
/// an anchor rectangle in the parent window.
enum AdwPopoverAnchor {
  topLeft,
  top,
  topRight,
  left,
  center,
  right,
  bottomLeft,
  bottom,
  bottomRight,
}

WindowPositionerAnchor _toWindowPositionerAnchor(AdwPopoverAnchor anchor) {
  return switch (anchor) {
    AdwPopoverAnchor.topLeft => WindowPositionerAnchor.topLeft,
    AdwPopoverAnchor.top => WindowPositionerAnchor.top,
    AdwPopoverAnchor.topRight => WindowPositionerAnchor.topRight,
    AdwPopoverAnchor.left => WindowPositionerAnchor.left,
    AdwPopoverAnchor.center => WindowPositionerAnchor.center,
    AdwPopoverAnchor.right => WindowPositionerAnchor.right,
    AdwPopoverAnchor.bottomLeft => WindowPositionerAnchor.bottomLeft,
    AdwPopoverAnchor.bottom => WindowPositionerAnchor.bottom,
    AdwPopoverAnchor.bottomRight => WindowPositionerAnchor.bottomRight,
  };
}

/// Handle to an open floating popover menu/dialog.
class AdwPopoverHandle {
  static AdwPopoverHandle? _activePopover;
  static Object? _activeOwner;
  static Object? _lastDismissedOwner;
  static DateTime? _lastDismissedAt;

  PopupWindowController? _popupController;
  AdwPopupWindowEntry? _popupEntry;
  PopupRoute<void>? _popupRoute;
  OverlayEntry? _barrierEntry;
  VoidCallback? _onDismiss;
  VoidCallback? _onDisposePlacement;
  Object? _owner;
  bool _isDismissed = false;

  AdwPopoverHandle._({VoidCallback? onDismiss, Object? owner})
      : _onDismiss = onDismiss,
        _owner = owner;

  /// Whether this popover is currently visible.
  bool get isOpen => !_isDismissed;

  /// Whether this popover is backed by an independent native OS popup window
  /// (allowing it to extend outside the parent window bounds).
  bool get isNativePopupWindow => _popupController != null;

  /// Closes and disposes this popover.
  void dismiss() {
    if (_isDismissed) return;
    _isDismissed = true;
    final disposePlacement = _onDisposePlacement;
    _onDisposePlacement = null;
    disposePlacement?.call();

    if (identical(_activePopover, this)) {
      _lastDismissedOwner = _activeOwner ?? _owner;
      _lastDismissedAt = DateTime.now();
      _activePopover = null;
      _activeOwner = null;
    }

    final barrier = _barrierEntry;
    _barrierEntry = null;
    barrier?.remove();

    if (_popupEntry != null) {
      AdwSubWindowManager.instance.unregisterPopup(_popupEntry!);
      _popupEntry = null;
    }
    final ctrl = _popupController;
    _popupController = null;
    if (ctrl != null && !ctrl.isDestroyed) {
      ctrl.destroy();
    }

    final route = _popupRoute;
    _popupRoute = null;
    if (route != null && route.isActive) {
      route.navigator?.removeRoute(route);
    }

    final cb = _onDismiss;
    _onDismiss = null;
    cb?.call();
  }
}

class _AdwPopupWindowDelegate with PopupWindowControllerDelegate {
  final VoidCallback onDestroyedCallback;

  _AdwPopupWindowDelegate({required this.onDestroyedCallback});

  @override
  void onWindowDestroyed() {
    onDestroyedCallback();
  }
}

/// Shows a floating Libadwaita popover menu/dialog anchored to [anchorRect]
/// (in logical coordinates of the parent window).
///
/// On desktop Linux, this creates a native `PopupWindow` (`GTK_WINDOW_POPUP`
/// positioned with `gdk_window_move_to_rect`) so the floating menu is
/// independent of the parent window and can extend outside narrow windows.
/// On non-Linux platforms (or in headless tests), it falls back to a root
/// [OverlayEntry] positioned within the current window.
AdwPopoverHandle showAdwPopover({
  required BuildContext context,
  required Rect anchorRect,
  required Widget Function(BuildContext context, AdwPopoverHandle handle)
      builder,
  Object? owner,
  AdwPopoverAnchor parentAnchor = AdwPopoverAnchor.bottomRight,
  AdwPopoverAnchor childAnchor = AdwPopoverAnchor.topRight,
  Offset offset = const Offset(0, 6),
  BoxConstraints constraints = const BoxConstraints(
    minWidth: 120,
    maxWidth: 320,
    maxHeight: 420,
  ),
  VoidCallback? onDismiss,
}) {
  final Object effectiveOwner = owner ?? anchorRect;

  // Only one popover may be open at a time. Re-invoking for the same owner
  // toggles it closed instead of opening a duplicate.
  final active = AdwPopoverHandle._activePopover;
  if (active != null && active.isOpen) {
    final sameOwner = AdwPopoverHandle._activeOwner == effectiveOwner;
    active.dismiss();
    if (sameOwner) {
      AdwPopoverHandle._lastDismissedOwner = null;
      AdwPopoverHandle._lastDismissedAt = null;
      return AdwPopoverHandle._(owner: effectiveOwner).._isDismissed = true;
    }
  } else if (AdwPopoverHandle._lastDismissedOwner == effectiveOwner &&
      AdwPopoverHandle._lastDismissedAt != null &&
      DateTime.now().difference(AdwPopoverHandle._lastDismissedAt!) <
          const Duration(milliseconds: 350)) {
    // Native PopupWindow (or overlay barrier) may dismiss on pointer-down
    // right before the invoking button's onTap fires on pointer-up.
    AdwPopoverHandle._lastDismissedOwner = null;
    AdwPopoverHandle._lastDismissedAt = null;
    return AdwPopoverHandle._(owner: effectiveOwner).._isDismissed = true;
  }

  AdwPopoverHandle._lastDismissedOwner = null;
  AdwPopoverHandle._lastDismissedAt = null;

  final handle = AdwPopoverHandle._(
    onDismiss: onDismiss,
    owner: effectiveOwner,
  );
  AdwPopoverHandle._activePopover = handle;
  AdwPopoverHandle._activeOwner = effectiveOwner;

  if (AdwSubWindowManager.isNativeLinuxWindowingSupported) {
    final parentController =
        AdwSubWindowManager.instance.resolveParentController(context);
    if (parentController != null &&
        (AdwSubWindowManager.instance.isRootWindowRegistered ||
            parentController.rootView.viewId != 0)) {
      try {
          // Leave transparent padding around the popover surface so its soft
          // drop shadow renders cleanly without clipping at the popup edges.
          const EdgeInsets shadowInsets = EdgeInsets.fromLTRB(14, 8, 14, 18);
          final safeAnchorRect = Rect.fromLTWH(
            anchorRect.left,
            anchorRect.top,
            math.max(1.0, anchorRect.width),
            math.max(1.0, anchorRect.height),
          );
          final adjustedConstraints = BoxConstraints(
            minWidth: constraints.minWidth + shadowInsets.horizontal,
            maxWidth: constraints.maxWidth.isFinite
                ? constraints.maxWidth + shadowInsets.horizontal
                : double.infinity,
            minHeight: constraints.minHeight + shadowInsets.vertical,
            maxHeight: constraints.maxHeight.isFinite
                ? constraints.maxHeight + shadowInsets.vertical
                : double.infinity,
          );

          final positioner = WindowPositioner(
            parentAnchor: _toWindowPositionerAnchor(parentAnchor),
            childAnchor: _toWindowPositionerAnchor(childAnchor),
            offset: offset + _shadowAnchorOffset(childAnchor, shadowInsets),
            constraintAdjustment: const WindowPositionerConstraintAdjustment(
              flipX: true,
              flipY: true,
              slideX: true,
              slideY: true,
            ),
          );

          final popupController = PopupWindowController(
            parent: parentController,
            anchorRect: safeAnchorRect,
            positioner: positioner,
            constraints: adjustedConstraints,
            delegate: _AdwPopupWindowDelegate(
              onDestroyedCallback: handle.dismiss,
            ),
          );

          if (popupController is PopupWindowControllerLinux) {
            popupController.setAppPaintable(true);
            popupController.setBackgroundColor(const Color(0x00000000));
            AdwNativeWindowController.attachPopupWindow(
              windowHandle: popupController.windowHandle.address,
            );
          }

          final linuxPlacement = _AdwPopoverPlacement();
          void syncLinuxPlacement() {
            if (!handle.isOpen) return;
            final Offset offsetFromParent = popupController.offsetFromParent;
            if (offsetFromParent == Offset.zero &&
                safeAnchorRect.topLeft != Offset.zero) {
              return;
            }
            final double popupLeft = offsetFromParent.dx + shadowInsets.left;
            final double popupTop = offsetFromParent.dy + shadowInsets.top;
            final double nextArrowX = safeAnchorRect.center.dx - popupLeft;
            if (linuxPlacement.arrowCenterX != nextArrowX) {
              linuxPlacement.arrowCenterX = nextArrowX;
              linuxPlacement.notifyArrowRepaint();
            }

            if (parentAnchor == AdwPopoverAnchor.bottom &&
                popupTop + 2.0 < safeAnchorRect.top) {
              linuxPlacement.updateArrowSide(AdwPopoverArrowSide.bottom);
            } else if (parentAnchor == AdwPopoverAnchor.top &&
                popupTop > safeAnchorRect.bottom - 2.0) {
              linuxPlacement.updateArrowSide(AdwPopoverArrowSide.top);
            } else {
              linuxPlacement.updateArrowSide(null);
            }
          }

          popupController.addListener(syncLinuxPlacement);
          handle._onDisposePlacement = () {
            popupController.removeListener(syncLinuxPlacement);
            linuxPlacement.dispose();
          };

          final entry = AdwPopupWindowEntry(
            controller: popupController,
            onDismiss: handle.dismiss,
            child: _AdwPopoverPlacementScope(
              placement: linuxPlacement,
              child: Padding(
                padding: shadowInsets,
                child: ConstrainedBox(
                  constraints: constraints,
                  child: Builder(
                    builder: (popupContext) => builder(popupContext, handle),
                  ),
                ),
              ),
            ),
          );

          handle._popupController = popupController;
          handle._popupEntry = entry;
          AdwSubWindowManager.instance.registerPopup(entry);

          final rootOverlay = Overlay.maybeOf(context, rootOverlay: true);
          if (rootOverlay != null) {
            final barrier = OverlayEntry(
              builder: (_) => Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => handle.dismiss(),
                onPointerSignal: (_) {},
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: handle.dismiss,
                  onVerticalDragStart: (_) {},
                  onHorizontalDragStart: (_) {},
                  child: const SizedBox.expand(),
                ),
              ),
            );
            handle._barrierEntry = barrier;
            rootOverlay.insert(barrier);
          }

          return handle;
        } catch (_) {
          // Fall through to in-window OverlayEntry fallback.
        }
    }
  }

  if (!context.mounted || handle._isDismissed) {
    return handle;
  }

  final themeData = AdwTheme.maybeOf(context);
  final nav = Navigator.of(context, rootNavigator: true);
  final placement = _AdwPopoverPlacement();
  handle._onDisposePlacement = placement.dispose;

  final route = _AdwPopoverRoute(
    onPopped: handle.dismiss,
    pageBuilder: (routeContext) {
      final Widget popoverChild = GestureDetector(
        onTap: () {},
        child: ConstrainedBox(
          constraints: constraints,
          child: Builder(
            builder: (ctx) => builder(ctx, handle),
          ),
        ),
      );

      Widget content = _AdwPopoverPlacementScope(
        placement: placement,
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): handle.dismiss,
          },
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerSignal: (_) {},
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: handle.dismiss,
              onVerticalDragStart: (_) {},
              onHorizontalDragStart: (_) {},
              child: _AdwOverlayPopoverPositioner(
                anchorRect: anchorRect,
                parentAnchor: parentAnchor,
                childAnchor: childAnchor,
                offset: offset,
                placement: placement,
                child: popoverChild,
              ),
            ),
          ),
        ),
      );

      if (AdwTheme.maybeOf(routeContext) == null && themeData != null) {
        content = AdwTheme(data: themeData, child: content);
      }

      return content;
    },
  );

  handle._popupRoute = route;
  nav.push<void>(route);
  return handle;
}

class _AdwPopoverRoute extends PopupRoute<void> {
  final WidgetBuilder pageBuilder;
  final VoidCallback onPopped;

  _AdwPopoverRoute({
    required this.pageBuilder,
    required this.onPopped,
  });

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return pageBuilder(context);
  }

  @override
  bool didPop(void result) {
    final popped = super.didPop(result);
    if (popped) {
      onPopped();
    }
    return popped;
  }
}

Offset _shadowAnchorOffset(
  AdwPopoverAnchor childAnchor,
  EdgeInsets shadowInsets,
) {
  final double dx = switch (childAnchor) {
    AdwPopoverAnchor.topLeft ||
    AdwPopoverAnchor.left ||
    AdwPopoverAnchor.bottomLeft =>
      -shadowInsets.left,
    AdwPopoverAnchor.topRight ||
    AdwPopoverAnchor.right ||
    AdwPopoverAnchor.bottomRight =>
      shadowInsets.right,
    AdwPopoverAnchor.top ||
    AdwPopoverAnchor.center ||
    AdwPopoverAnchor.bottom =>
      0.0,
  };
  final double dy = switch (childAnchor) {
    AdwPopoverAnchor.topLeft ||
    AdwPopoverAnchor.top ||
    AdwPopoverAnchor.topRight =>
      -shadowInsets.top,
    AdwPopoverAnchor.bottomLeft ||
    AdwPopoverAnchor.bottom ||
    AdwPopoverAnchor.bottomRight =>
      shadowInsets.bottom,
    AdwPopoverAnchor.left ||
    AdwPopoverAnchor.center ||
    AdwPopoverAnchor.right =>
      0.0,
  };
  return Offset(dx, dy);
}

class _AdwPopoverPlacement {
  double? arrowCenterX;
  final ValueNotifier<AdwPopoverArrowSide?> resolvedArrowSide =
      ValueNotifier<AdwPopoverArrowSide?>(null);
  final _ArrowRepaintNotifier arrowRepaint = _ArrowRepaintNotifier();

  void updateArrowSide(AdwPopoverArrowSide? side) {
    if (resolvedArrowSide.value == side) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      resolvedArrowSide.value = side;
    });
  }

  void notifyArrowRepaint() {
    arrowRepaint.notify();
  }

  void dispose() {
    resolvedArrowSide.dispose();
    arrowRepaint.dispose();
  }
}

class _ArrowRepaintNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _AdwPopoverPlacementScope extends InheritedWidget {
  final _AdwPopoverPlacement placement;

  const _AdwPopoverPlacementScope({
    required this.placement,
    required super.child,
  });

  static _AdwPopoverPlacement? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_AdwPopoverPlacementScope>()
        ?.placement;
  }

  @override
  bool updateShouldNotify(covariant _AdwPopoverPlacementScope oldWidget) {
    return placement != oldWidget.placement;
  }
}

class _AdwOverlayPopoverPositioner extends StatelessWidget {
  final Rect anchorRect;
  final AdwPopoverAnchor parentAnchor;
  final AdwPopoverAnchor childAnchor;
  final Offset offset;
  final _AdwPopoverPlacement placement;
  final Widget child;

  const _AdwOverlayPopoverPositioner({
    required this.anchorRect,
    required this.parentAnchor,
    required this.childAnchor,
    required this.offset,
    required this.placement,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return CustomSingleChildLayout(
      delegate: _OverlayPopoverLayoutDelegate(
        anchorRect: anchorRect,
        parentAnchor: parentAnchor,
        childAnchor: childAnchor,
        offset: offset,
        bottomInset: bottomInset,
        placement: placement,
      ),
      child: child,
    );
  }
}

class _OverlayPopoverLayoutDelegate extends SingleChildLayoutDelegate {
  final Rect anchorRect;
  final AdwPopoverAnchor parentAnchor;
  final AdwPopoverAnchor childAnchor;
  final Offset offset;
  final double bottomInset;
  final _AdwPopoverPlacement? placement;

  _OverlayPopoverLayoutDelegate({
    required this.anchorRect,
    required this.parentAnchor,
    required this.childAnchor,
    required this.offset,
    this.bottomInset = 0.0,
    this.placement,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: math.max(0.0, constraints.maxWidth - 16),
      maxHeight: math.max(0.0, constraints.maxHeight - bottomInset - 16),
    );
  }

  Offset _anchorPoint(Rect rect, AdwPopoverAnchor anchor) {
    return switch (anchor) {
      AdwPopoverAnchor.topLeft => rect.topLeft,
      AdwPopoverAnchor.top => rect.topCenter,
      AdwPopoverAnchor.topRight => rect.topRight,
      AdwPopoverAnchor.left => rect.centerLeft,
      AdwPopoverAnchor.center => rect.center,
      AdwPopoverAnchor.right => rect.centerRight,
      AdwPopoverAnchor.bottomLeft => rect.bottomLeft,
      AdwPopoverAnchor.bottom => rect.bottomCenter,
      AdwPopoverAnchor.bottomRight => rect.bottomRight,
    };
  }

  Offset _childOffset(Size size, AdwPopoverAnchor anchor) {
    return switch (anchor) {
      AdwPopoverAnchor.topLeft => Offset.zero,
      AdwPopoverAnchor.top => Offset(-size.width / 2, 0),
      AdwPopoverAnchor.topRight => Offset(-size.width, 0),
      AdwPopoverAnchor.left => Offset(0, -size.height / 2),
      AdwPopoverAnchor.center => Offset(-size.width / 2, -size.height / 2),
      AdwPopoverAnchor.right => Offset(-size.width, -size.height / 2),
      AdwPopoverAnchor.bottomLeft => Offset(0, -size.height),
      AdwPopoverAnchor.bottom => Offset(-size.width / 2, -size.height),
      AdwPopoverAnchor.bottomRight => Offset(-size.width, -size.height),
    };
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const double margin = 8.0;
    final raw = _anchorPoint(anchorRect, parentAnchor) +
        _childOffset(childSize, childAnchor) +
        offset;

    final double effectiveHeight = math.max(0.0, size.height - bottomInset);
    double dx = raw.dx;
    double dy = raw.dy;
    AdwPopoverArrowSide? flippedSide;

    if (dy + childSize.height > effectiveHeight - margin &&
        anchorRect.top - childSize.height - offset.dy >= margin) {
      dy = anchorRect.top - childSize.height - offset.dy;
      flippedSide = AdwPopoverArrowSide.bottom;
    } else if (dy < margin &&
        anchorRect.bottom + childSize.height + offset.dy <=
            effectiveHeight - margin) {
      dy = anchorRect.bottom + offset.dy;
      flippedSide = AdwPopoverArrowSide.top;
    }

    dx = dx.clamp(
      margin,
      math.max(margin, size.width - childSize.width - margin),
    );
    dy = dy.clamp(
      margin,
      math.max(margin, effectiveHeight - childSize.height - margin),
    );
    if (placement != null) {
      placement!.arrowCenterX = anchorRect.center.dx - dx;
      placement!.updateArrowSide(flippedSide);
    }
    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(covariant _OverlayPopoverLayoutDelegate oldDelegate) {
    return anchorRect != oldDelegate.anchorRect ||
        parentAnchor != oldDelegate.parentAnchor ||
        childAnchor != oldDelegate.childAnchor ||
        offset != oldDelegate.offset ||
        bottomInset != oldDelegate.bottomInset;
  }
}

/// Which edge of an [AdwPopoverSurface] displays the pointer triangle.
enum AdwPopoverArrowSide {
  none,
  top,
  bottom,
}

/// Styled Libadwaita popover container (`popover.background > contents`).
class AdwPopoverSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final AdwPopoverArrowSide arrowSide;
  final double arrowWidth;
  final double arrowHeight;
  final double? arrowOffset;
  final bool isOsd;

  const AdwPopoverSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(6),
    this.arrowSide = AdwPopoverArrowSide.none,
    this.arrowWidth = 18.0,
    this.arrowHeight = 9.0,
    this.arrowOffset,
    this.isOsd = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final effectiveBg =
        isOsd ? theme.colors.osdBackground : theme.colors.popoverBackground;
    final effectiveFg =
        isOsd ? theme.colors.osdForeground : theme.colors.popoverForeground;

    final content = _AdwPopoverMenuScope(
      child: DefaultTextStyle(
        style: theme.typography.body.copyWith(
          color: effectiveFg,
        ),
        child: child,
      ),
    );

    if (arrowSide == AdwPopoverArrowSide.none) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(AdwMetrics.cardRadius),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 0,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Color(0x17000000),
              blurRadius: 5,
              spreadRadius: 1,
              offset: Offset(0, 1),
            ),
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 14,
              spreadRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: content,
      );
    }

    final placement = _AdwPopoverPlacementScope.maybeOf(context);

    Widget buildWithArrowSide(AdwPopoverArrowSide effectiveArrowSide) {
      final arrowInset = EdgeInsets.only(
        top: effectiveArrowSide == AdwPopoverArrowSide.top ? arrowHeight : 0,
        bottom:
            effectiveArrowSide == AdwPopoverArrowSide.bottom ? arrowHeight : 0,
      );

      return CustomPaint(
        painter: _AdwPopoverSurfacePainter(
          backgroundColor: effectiveBg,
          borderColor: isOsd ? const Color(0x1AFFFFFF) : null,
          radius: AdwMetrics.cardRadius,
          arrowSide: effectiveArrowSide,
          arrowWidth: arrowWidth,
          arrowHeight: arrowHeight,
          arrowOffset: arrowOffset,
          placement: placement,
        ),
        child: Padding(
          padding: arrowInset,
          child: Padding(
            padding: padding,
            child: content,
          ),
        ),
      );
    }

    if (placement == null) {
      return buildWithArrowSide(arrowSide);
    }

    return ValueListenableBuilder<AdwPopoverArrowSide?>(
      valueListenable: placement.resolvedArrowSide,
      builder: (context, overriddenSide, _) {
        return buildWithArrowSide(overriddenSide ?? arrowSide);
      },
    );
  }
}

class _AdwPopoverSurfacePainter extends CustomPainter {
  final Color backgroundColor;
  final Color? borderColor;
  final double radius;
  final AdwPopoverArrowSide arrowSide;
  final double arrowWidth;
  final double arrowHeight;
  final double? arrowOffset;
  final _AdwPopoverPlacement? placement;

  _AdwPopoverSurfacePainter({
    required this.backgroundColor,
    this.borderColor,
    required this.radius,
    required this.arrowSide,
    required this.arrowWidth,
    required this.arrowHeight,
    this.arrowOffset,
    this.placement,
  }) : super(repaint: placement?.arrowRepaint);

  Path _buildPath(Size size) {
    final topInset = arrowSide == AdwPopoverArrowSide.top ? arrowHeight : 0.0;
    final bottomInset =
        arrowSide == AdwPopoverArrowSide.bottom ? arrowHeight : 0.0;
    final bodyRect = Rect.fromLTRB(
      0,
      topInset,
      size.width,
      size.height - bottomInset,
    );

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(radius)));

    final halfW = arrowWidth / 2;
    final double rawCenterX =
        arrowOffset ?? placement?.arrowCenterX ?? (size.width / 2);
    final double minCenterX = radius + halfW + 2.0;
    final double maxCenterX =
        math.max(minCenterX, size.width - radius - halfW - 2.0);
    final double centerX = rawCenterX.clamp(minCenterX, maxCenterX);
    if (arrowSide == AdwPopoverArrowSide.top) {
      final arrowPath = Path()
        ..moveTo(centerX - halfW, topInset + 1)
        ..lineTo(centerX, 0)
        ..lineTo(centerX + halfW, topInset + 1)
        ..close();
      return Path.combine(PathOperation.union, path, arrowPath);
    } else if (arrowSide == AdwPopoverArrowSide.bottom) {
      final baseY = size.height - bottomInset - 1;
      final arrowPath = Path()
        ..moveTo(centerX - halfW, baseY)
        ..lineTo(centerX, size.height)
        ..lineTo(centerX + halfW, baseY)
        ..close();
      return Path.combine(PathOperation.union, path, arrowPath);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // Outer ambient shadow (0 2px 14px 3px rgb(0 0 0 / 5%))
    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = const Color(0x0D000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // Key shadow (0 1px 5px 1px rgb(0 0 0 / 9%))
    canvas.drawPath(
      path.shift(const Offset(0, 1)),
      Paint()
        ..color = const Color(0x17000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );

    // Subtle 1px rim (0 0 0 1px rgb(0 0 0 / 5%))
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x0D000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Popover surface fill
    canvas.drawPath(
      path,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.fill,
    );

    if (borderColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = borderColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AdwPopoverSurfacePainter oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor ||
        radius != oldDelegate.radius ||
        arrowSide != oldDelegate.arrowSide ||
        arrowWidth != oldDelegate.arrowWidth ||
        arrowHeight != oldDelegate.arrowHeight ||
        arrowOffset != oldDelegate.arrowOffset ||
        placement != oldDelegate.placement;
  }
}

class _AdwPopoverMenuScope extends StatefulWidget {
  final Widget child;

  const _AdwPopoverMenuScope({required this.child});

  static _AdwPopoverMenuScopeData? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_AdwPopoverMenuScopeData>();
  }

  @override
  State<_AdwPopoverMenuScope> createState() => _AdwPopoverMenuScopeState();
}

class _AdwPopoverMenuScopeState extends State<_AdwPopoverMenuScope> {
  Object? _highlightedToken;

  bool _claimInitial(Object token) {
    _highlightedToken ??= token;
    return _highlightedToken == token;
  }

  void _setHighlighted(Object token) {
    if (_highlightedToken != token) {
      setState(() => _highlightedToken = token);
    }
  }

  void _clearHighlighted(Object token) {
    if (_highlightedToken == token) {
      setState(() => _highlightedToken = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdwPopoverMenuScopeData(
      highlightedToken: _highlightedToken,
      claimInitial: _claimInitial,
      setHighlighted: _setHighlighted,
      clearHighlighted: _clearHighlighted,
      child: widget.child,
    );
  }
}

class _AdwPopoverMenuScopeData extends InheritedWidget {
  final Object? highlightedToken;
  final bool Function(Object token) claimInitial;
  final void Function(Object token) setHighlighted;
  final void Function(Object token) clearHighlighted;

  const _AdwPopoverMenuScopeData({
    required this.highlightedToken,
    required this.claimInitial,
    required this.setHighlighted,
    required this.clearHighlighted,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant _AdwPopoverMenuScopeData oldWidget) {
    return highlightedToken != oldWidget.highlightedToken;
  }
}

/// Selectable menu item inside an [AdwPopoverSurface].
class AdwPopoverMenuItem extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isHighlighted;
  final ValueChanged<bool>? onHoverChanged;

  const AdwPopoverMenuItem({
    super.key,
    required this.label,
    this.onTap,
    this.trailing,
    this.isHighlighted = false,
    this.onHoverChanged,
  });

  @override
  State<AdwPopoverMenuItem> createState() => _AdwPopoverMenuItemState();
}

class _AdwPopoverMenuItemState extends State<AdwPopoverMenuItem> {
  final Object _itemToken = Object();
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final menuScope = _AdwPopoverMenuScope.maybeOf(context);
    final isEnabled = widget.onTap != null;
    final isScopeHighlighted =
        isEnabled && menuScope != null && menuScope.claimInitial(_itemToken);
    final isHighlighted = widget.isHighlighted || isScopeHighlighted;
    final hoverFill = theme.colors.isDark
        ? const Color(0xFF4A4A4D)
        : const Color(0xFFEBEBEB);

    Color bg = hoverFill.withValues(alpha: 0.0);
    if (isEnabled) {
      if (_isPressed) {
        bg = theme.colors.activeColor;
      } else if (_isHovered || isHighlighted) {
        bg = hoverFill;
      }
    }

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isEnabled) {
          setState(() => _isHovered = true);
          menuScope?.setHighlighted(_itemToken);
          widget.onHoverChanged?.call(true);
        }
      },
      onExit: (_) {
        if (isEnabled) {
          setState(() {
            _isHovered = false;
            _isPressed = false;
          });
          menuScope?.clearHighlighted(_itemToken);
          widget.onHoverChanged?.call(false);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel:
            isEnabled ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AdwCurves.shortDuration,
          curve: AdwCurves.standard,
          alignment: Alignment.centerLeft,
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  style: theme.typography.body.copyWith(
                    height: 1.0,
                    leadingDistribution: TextLeadingDistribution.even,
                    color: isEnabled
                        ? theme.colors.popoverForeground
                        : theme.colors.popoverForeground.withValues(alpha: 0.45),
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 12),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal separator inside an [AdwPopoverSurface].
class AdwPopoverDivider extends StatelessWidget {
  const AdwPopoverDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        height: 1,
        color: theme.colors.borderColor,
      ),
    );
  }
}
