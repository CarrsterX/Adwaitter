import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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
///   with top rounded corners, drag handle pill, and swipe-down dismissal.
class AdwDialog extends StatefulWidget {
  /// Preferred content width in logical pixels (defaults to `360`).
  final double contentWidth;

  /// Preferred content height in logical pixels (optional; sizes to child if null).
  final double? contentHeight;

  /// Optional accessible/window title for the dialog.
  final String? title;

  /// Whether pressing Escape or clicking outside/swiping down closes it.
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

class _AdwDialogState extends State<AdwDialog> {
  double _dragOffset = 0.0;
  bool _isDragging = false;

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.canClose) return;
    setState(() {
      _isDragging = true;
      _dragOffset = math.max(0.0, _dragOffset + details.delta.dy);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    final velocity = details.primaryVelocity ?? 0.0;
    if (_dragOffset >= 80.0 || velocity >= 400.0) {
      Navigator.of(context).maybePop();
    } else {
      setState(() {
        _isDragging = false;
        _dragOffset = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final isWindowActive = AdwWindowScope.maybeOf(context)?.isActive ?? true;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow =
            constraints.maxWidth <= 450.0 || constraints.maxHeight <= 360.0;
        final isBottomSheet = switch (widget.presentationMode) {
          AdwDialogPresentationMode.auto => isNarrow,
          AdwDialogPresentationMode.bottomSheet => true,
          AdwDialogPresentationMode.floating => false,
        };

        final radius = isBottomSheet
            ? const BorderRadius.vertical(
                top: Radius.circular(AdwMetrics.windowRadius),
              )
            : BorderRadius.circular(AdwMetrics.windowRadius);

        final maxFloatingWidth = math.max(240.0, constraints.maxWidth - 32.0);
        final effectiveWidth = isBottomSheet
            ? math.min(widget.contentWidth, constraints.maxWidth)
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
            border: isBottomSheet
                ? Border(
                    top: BorderSide(
                      color: theme.colors.windowOutline,
                      width: 1.0,
                    ),
                    left: BorderSide(
                      color: theme.colors.windowOutline,
                      width: 1.0,
                    ),
                    right: BorderSide(
                      color: theme.colors.windowOutline,
                      width: 1.0,
                    ),
                  )
                : Border.all(
                    color: theme.colors.windowOutline,
                    width: 1.0,
                  ),
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
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AdwDialogScope(
                    close: () => Navigator.of(context).maybePop(),
                    title: widget.title,
                    isBottomSheet: isBottomSheet,
                    child: widget.child,
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

        if (isBottomSheet) {
          return Stack(
            children: [
              if (widget.canClose)
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerUp: (_) => Navigator.of(context).maybePop(),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _handleDragUpdate,
                    onVerticalDragEnd: _handleDragEnd,
                    child: AnimatedContainer(
                      duration:
                          _isDragging ? Duration.zero : AdwCurves.normalDuration,
                      curve: AdwCurves.standard,
                      transform: Matrix4.translationValues(0, _dragOffset, 0),
                      child: sizedSheet,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Center(child: sizedSheet);
      },
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

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x66000000),
    transitionDuration: AdwCurves.resolve(
      context,
      initialBottomSheet ? AdwCurves.normalDuration : AdwCurves.shortDuration,
    ),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      Widget content = AdwTheme(
        data: theme,
        child: CallbackShortcuts(
          bindings: {
            if (dismissOnEscape)
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  Navigator.of(dialogContext).maybePop(),
          },
          child: Focus(
            autofocus: true,
            child: builder(dialogContext),
          ),
        ),
      );

      if (parentWindowScope != null) {
        final controller = parentWindowScope.controller;
        if (controller != null) {
          content = AdwWindowResizeOverlay(
            controller: controller,
            enabled: !parentWindowScope.isMaximized,
            child: content,
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
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AdwCurves.standard,
      );
      if (initialBottomSheet) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      }
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
