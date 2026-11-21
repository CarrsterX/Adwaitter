import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/adw_spring.dart';
import '../../core/adw_insets.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../layout/adw_window.dart';

/// Adaptive presentation mode for [AdwDialog], matching `AdwDialogPresentationMode`.
enum AdwDialogPresentationMode {
  /// Automatically switches between [floating] and [bottomSheet] based on
  /// available window size (`maxWidth <= 450` or `maxHeight <= 360`).
  auto,

  /// Always present as a centered floating sheet.
  floating,

  /// Always present as a full-width bottom sheet.
  bottomSheet,
}

/// Inherited scope provided by [AdwDialog] so descendant [AdwHeaderBar]s can
/// display a dialog close button and dismiss the dialog cleanly.
class AdwDialogScope extends InheritedWidget {
  final VoidCallback close;
  final String? title;
  final bool isBottomSheet;

  const AdwDialogScope({
    super.key,
    required this.close,
    this.title,
    this.isBottomSheet = false,
    required super.child,
  });

  static AdwDialogScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdwDialogScope>();
  }

  @override
  bool updateShouldNotify(covariant AdwDialogScope oldWidget) {
    return close != oldWidget.close ||
        title != oldWidget.title ||
        isBottomSheet != oldWidget.isBottomSheet;
  }
}

/// Adaptive modal dialog container matching GNOME Libadwaita's `AdwDialog`.
///
/// - On wide windows (`width > 450` and `height > 360`), renders as a centered
///   non-resizable floating sheet (`AdwFloatingSheet`).
/// - On narrow/mobile windows (`width <= 450` or `height <= 360`),
///   automatically transitions to a full-width bottom sheet (`AdwBottomSheet`)
///   with top rounded corners.
class AdwDialog extends StatefulWidget {
  /// Preferred content width in logical pixels (defaults to `360`).
  final double contentWidth;

  /// Preferred content height in logical pixels (optional; sizes to child if null).
  final double? contentHeight;

  /// Optional accessible/window title for the dialog.
  final String? title;

  /// Whether pressing Escape or clicking outside closes it.
  final bool canClose;

  /// Presentation mode (`auto`, `floating`, or `bottomSheet`).
  final AdwDialogPresentationMode presentationMode;

  /// Dialog body (typically an [AdwToolbarView] or [AdwNavigationView]).
  final Widget child;

  const AdwDialog({
    super.key,
    this.contentWidth = 360.0,
    this.contentHeight,
    this.title,
    this.canClose = true,
    this.presentationMode = AdwDialogPresentationMode.auto,
    required this.child,
  });

  @override
  State<AdwDialog> createState() => _AdwDialogState();
}

class _AdwDialogState extends State<AdwDialog> with WidgetsBindingObserver {
  final GlobalKey _childKey = GlobalKey();
  bool _isBottomSheet = false;
  bool _isSystemPredictiveBack = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  _AdwDialogRoute<dynamic>? get _dialogRoute {
    final route = ModalRoute.of(context);
    return route is _AdwDialogRoute ? route : null;
  }

  bool _hasPoppableDescendantNavigator() {
    if (!mounted) return false;
    final parentNav = _dialogRoute?.navigator;
    bool found = false;
    void visit(Element element) {
      if (found) return;
      if (element is StatefulElement && element.state is NavigatorState) {
        final navState = element.state as NavigatorState;
        if (navState != parentNav && navState.canPop()) {
          found = true;
          return;
        }
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (!_isBottomSheet || !widget.canClose) return false;
    final route = _dialogRoute;
    final controller = route?.dialogController;
    if (route == null || !route.isCurrent || controller == null) {
      return false;
    }
    if (route.popDisposition == RoutePopDisposition.doNotPop) {
      return false;
    }
    if (_hasPoppableDescendantNavigator()) {
      return false;
    }
    controller.stop();
    _isSystemPredictiveBack = true;
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (!_isSystemPredictiveBack) return;
    final controller = _dialogRoute?.dialogController;
    if (controller == null) return;
    controller.value = (1.0 - backEvent.progress).clamp(0.0, 1.0);
  }

  @override
  void handleCommitBackGesture() {
    if (!_isSystemPredictiveBack) return;
    _isSystemPredictiveBack = false;
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void handleCancelBackGesture() {
    if (!_isSystemPredictiveBack) return;
    _isSystemPredictiveBack = false;
    final controller = _dialogRoute?.dialogController;
    if (controller == null) return;
    final sim = AdwSpringParams.bottomSheet.createSimulation(
      start: controller.value,
      end: 1.0,
      velocity: 1.5,
    );
    controller.animateWith(sim).whenComplete(() {
      if (mounted && controller.value != 1.0) {
        controller.value = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final isWindowActive = AdwWindowScope.maybeOf(context)?.isActive ?? true;
    final windowSize = MediaQuery.sizeOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the un-shrunk window size for the narrow/bottomSheet threshold
        // so opening the mobile virtual keyboard (which reduces
        // constraints.maxHeight via Padding) never flips presentation mode.
        final isNarrow =
            windowSize.width <= 450.0 || windowSize.height <= 360.0;
        final isBottomSheet = switch (widget.presentationMode) {
          AdwDialogPresentationMode.auto => isNarrow,
          AdwDialogPresentationMode.bottomSheet => true,
          AdwDialogPresentationMode.floating => false,
        };
        _isBottomSheet = isBottomSheet;

        final radius = isBottomSheet
            ? const BorderRadius.vertical(
                top: Radius.circular(AdwMetrics.windowRadius),
              )
            : BorderRadius.circular(AdwMetrics.windowRadius);

        final maxFloatingWidth = math.max(240.0, constraints.maxWidth - 32.0);
        final effectiveWidth = isBottomSheet
            ? constraints.maxWidth
            : math.min(widget.contentWidth, maxFloatingWidth);

        final topPadding = isBottomSheet
            ? 30.0 +
                90.0 * ((constraints.maxHeight - 720.0) / 720.0).clamp(0.0, 1.0)
            : 32.0;
        final maxAvailableHeight =
            math.max(120.0, constraints.maxHeight - topPadding);
        final effectiveHeight = widget.contentHeight != null
            ? math.min(widget.contentHeight!, maxAvailableHeight)
            : null;

        final sheet = AnimatedContainer(
          duration: AdwCurves.shortDuration,
          decoration: BoxDecoration(
            color: theme.colors.windowBackground,
            borderRadius: radius,
            boxShadow: isWindowActive
                ? const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 28.0,
                      spreadRadius: 2.0,
                      offset: Offset(0, 10),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x28000000),
                      blurRadius: 12.0,
                      spreadRadius: 0.0,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: isBottomSheet
                ? Border(
                    top: BorderSide(
                      color: theme.colors.isDark
                          ? const Color(0xFF323235)
                          : theme.colors.windowOutline,
                      width: 1.0,
                    ),
                    left: BorderSide(
                      color: theme.colors.isDark
                          ? const Color(0xFF323235)
                          : theme.colors.windowOutline,
                      width: 1.0,
                    ),
                    right: BorderSide(
                      color: theme.colors.isDark
                          ? const Color(0xFF323235)
                          : theme.colors.windowOutline,
                      width: 1.0,
                    ),
                  )
                : Border.all(
                    color: theme.colors.isDark
                        ? const Color(0xFF323235)
                        : theme.colors.windowOutline,
                    width: 1.0,
                  ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AdwDialogScope(
                    close: () => Navigator.of(context).maybePop(),
                    title: widget.title,
                    isBottomSheet: isBottomSheet,
                    child: () {
                      final bool isMobile =
                          defaultTargetPlatform == TargetPlatform.android ||
                              defaultTargetPlatform == TargetPlatform.iOS;
                      // Floating (non bottom-sheet) dialogs never touch the
                      // system navbar, so they must not reserve its inset.
                      // Keep Padding + AdwBottomInsetConsumer unconditionally
                      // mounted so transitioning viewInsets (virtual keyboard
                      // open/close) never remounts child or drops focus.
                      final double navBottomInset = (isBottomSheet && isMobile)
                          ? adwBottomSystemInset(context)
                          : 0.0;
                      return Padding(
                        padding: EdgeInsets.only(bottom: navBottomInset),
                        child: AdwBottomInsetConsumer(
                          child: KeyedSubtree(
                            key: _childKey,
                            child: widget.child,
                          ),
                        ),
                      );
                    }(),
                  ),
                ),
                if (!isWindowActive)
                  IgnorePointer(
                    child: AnimatedContainer(
                      duration: AdwCurves.shortDuration,
                      color: const Color(0x18000000),
                    ),
                  ),
              ],
            ),
          ),
        );

        final sizedSheet = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: effectiveWidth,
            minWidth: isBottomSheet
                ? effectiveWidth
                : math.min(effectiveWidth, 280.0),
            maxHeight: effectiveHeight ?? maxAvailableHeight,
            minHeight: effectiveHeight ?? 0.0,
          ),
          child: SizedBox(
            width: effectiveWidth,
            height: effectiveHeight,
            child: sheet,
          ),
        );

        final anim = _AdwDialogAnimationScope.maybeOf(context)?.animation;

        if (isBottomSheet) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.canClose
                      ? () => Navigator.of(context).maybePop()
                      : () {},
                  onVerticalDragStart: (_) {},
                  onHorizontalDragStart: (_) {},
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedBuilder(
                  animation: anim ?? const AlwaysStoppedAnimation<double>(1.0),
                  builder: (context, child) {
                    final progress = anim?.value ?? 1.0;
                    final overshoot = math.max(0.0, progress - 1.0);
                    return FractionalTranslation(
                      translation: Offset(0.0, 1.0 - progress),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (overshoot > 0.0)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: -24,
                              height: 25,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: theme.colors.windowBackground,
                                  border: Border(
                                    left: BorderSide(
                                      color: theme.colors.windowOutline,
                                      width: 1.0,
                                    ),
                                    right: BorderSide(
                                      color: theme.colors.windowOutline,
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          child!,
                        ],
                      ),
                    );
                  },
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    child: sizedSheet,
                  ),
                ),
              ),
            ],
          );
        }

        return Center(
          child: AnimatedBuilder(
            animation: anim ?? const AlwaysStoppedAnimation<double>(1.0),
            builder: (context, child) {
              final progress = anim?.value ?? 1.0;
              final scale = 0.8 + 0.2 * progress;
              return Opacity(
                opacity: progress.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              );
            },
            child: sizedSheet,
          ),
        );
      },
    );
  }
}

class _AdwDialogAnimationScope extends InheritedWidget {
  final Animation<double> animation;

  const _AdwDialogAnimationScope({
    required this.animation,
    required super.child,
  });

  static _AdwDialogAnimationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_AdwDialogAnimationScope>();
  }

  @override
  bool updateShouldNotify(covariant _AdwDialogAnimationScope oldWidget) {
    return animation != oldWidget.animation;
  }
}

class _AdwDialogRoute<T> extends PopupRoute<T> {
  final WidgetBuilder pageBuilder;
  final bool _barrierDismissible;
  final bool initialBottomSheet;
  final Duration _transitionDuration;
  final Duration _reverseTransitionDuration;
  final bool reduceMotion;

  _AdwDialogRoute({
    required this.pageBuilder,
    required bool barrierDismissible,
    required this.initialBottomSheet,
    required Duration transitionDuration,
    required Duration reverseTransitionDuration,
    required this.reduceMotion,
  })  : _barrierDismissible = barrierDismissible,
        _transitionDuration = transitionDuration,
        _reverseTransitionDuration = reverseTransitionDuration;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => _transitionDuration;

  @override
  Duration get reverseTransitionDuration => _reverseTransitionDuration;

  AnimationController? get dialogController => controller;

  @override
  AnimationController createAnimationController() {
    return AnimationController(
      lowerBound: 0.0,
      upperBound: 1.5,
      value: 0.0,
      duration: transitionDuration,
      reverseDuration: reverseTransitionDuration,
      vsync: navigator!,
    );
  }

  @override
  TickerFuture didPush() {
    super.didPush();
    if (controller == null) {
      return TickerFuture.complete();
    }
    if (reduceMotion) {
      controller!.value = 1.0;
      return TickerFuture.complete();
    }
    controller!.value = 0.0;
    final spring = initialBottomSheet
        ? AdwSpringParams.bottomSheet
        : AdwSpringParams.floatingSheet;
    final sim = spring.createSimulation(start: 0.0, end: 1.0, velocity: 0.0);
    final springFuture = controller!.animateWith(sim);
    springFuture.whenComplete(() {
      if (controller != null && isCurrent && controller!.value != 1.0) {
        controller!.value = 1.0;
      }
    });
    return springFuture;
  }

  @override
  bool didPop(T? result) {
    if (controller != null && controller!.value > 1.0) {
      controller!.value = 1.0;
    }
    return super.didPop(result);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _AdwDialogAnimationScope(
      animation: animation,
      child: pageBuilder(context),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _barrierDismissible
                ? () => Navigator.of(context).maybePop()
                : () {},
            onVerticalDragStart: (_) {},
            onHorizontalDragStart: (_) {},
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final alpha = (0.4 * animation.value.clamp(0.0, 1.0));
                return ColoredBox(
                  color: Color.fromRGBO(0, 0, 0, alpha),
                );
              },
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Presents an [AdwDialog] modally over the current window, propagating
/// [AdwWindowScope] so dragging any [AdwHeaderBar] inside the dialog moves
/// the host window seamlessly.
Future<T?> showAdwDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
  bool dismissOnEscape = true,
}) {
  final parentWindowScope = AdwWindowScope.maybeOf(context);
  final theme = AdwTheme.of(context);
  final mediaSize = MediaQuery.sizeOf(context);
  final initialBottomSheet =
      mediaSize.width <= 450.0 || mediaSize.height <= 360.0;
  final reduceMotion =
      AdwCurves.resolve(context, AdwCurves.shortDuration) == Duration.zero;

  return Navigator.of(context, rootNavigator: true).push<T>(
    _AdwDialogRoute<T>(
      barrierDismissible: barrierDismissible,
      initialBottomSheet: initialBottomSheet,
      reduceMotion: reduceMotion,
      transitionDuration: AdwCurves.resolve(
        context,
        AdwCurves.normalDuration,
      ),
      reverseTransitionDuration: AdwCurves.resolve(
        context,
        AdwCurves.normalDuration,
      ),
      pageBuilder: (dialogContext) {
        Widget content = CallbackShortcuts(
          bindings: {
            if (dismissOnEscape)
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  Navigator.of(dialogContext).maybePop(),
          },
          child: Focus(
            autofocus: true,
            child: builder(dialogContext),
          ),
        );

        if (AdwTheme.maybeOf(dialogContext) == null) {
          content = AdwTheme(
            data: theme,
            child: content,
          );
        }

        if (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) {
          final double bottomInset =
              MediaQuery.viewInsetsOf(dialogContext).bottom;
          content = MediaQuery.removeViewInsets(
            context: dialogContext,
            removeBottom: true,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SafeArea(
                bottom: false,
                child: content,
              ),
            ),
          );
        }

        if (parentWindowScope != null) {
          final controller = parentWindowScope.controller;
          if (controller != null) {
            content = AdwWindowResizeOverlay(
              controller: controller,
              enabled: !parentWindowScope.isMaximized,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => controller.startDragging(),
                child: content,
              ),
            );
          }
          final activeListenable = controller?.activeListenable;
          if (activeListenable != null) {
            final innerContent = content;
            content = ValueListenableBuilder<bool>(
              valueListenable: activeListenable,
              builder: (_, isActive, __) => AdwWindowScope(
                controller: controller,
                isMaximized: parentWindowScope.isMaximized,
                isActive: isActive,
                child: innerContent,
              ),
            );
          } else {
            content = AdwWindowScope(
              controller: controller,
              isMaximized: parentWindowScope.isMaximized,
              isActive: parentWindowScope.isActive,
              child: content,
            );
          }
        }

        return content;
      },
    ),
  );
}
