import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../layout/adw_window.dart';

/// Inherited scope provided by [AdwDialog] so descendant [AdwHeaderBar]s can
/// display a dialog close button and dismiss the dialog cleanly.
class AdwDialogScope extends InheritedWidget {
  final VoidCallback close;
  final String? title;

  const AdwDialogScope({
    super.key,
    required this.close,
    this.title,
    required super.child,
  });

  static AdwDialogScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdwDialogScope>();
  }

  @override
  bool updateShouldNotify(covariant AdwDialogScope oldWidget) {
    return close != oldWidget.close || title != oldWidget.title;
  }
}

/// Non-resizable modal dialog container matching GNOME Libadwaita's `AdwDialog`.
///
/// Features rounded corners, subtle surface outline, soft drop shadow,
/// Esc-key / barrier dismissal when [canClose] is true, and seamless
/// [AdwHeaderBar] window-dragging when presented via [showAdwDialog].
class AdwDialog extends StatelessWidget {
  /// Preferred content width in logical pixels (defaults to `360`).
  final double contentWidth;

  /// Preferred content height in logical pixels (optional; sizes to child if null).
  final double? contentHeight;

  /// Optional accessible/window title for the dialog.
  final String? title;

  /// Whether pressing Escape or clicking outside the dialog closes it.
  final bool canClose;

  /// Dialog body (typically an [AdwToolbarView] or [AdwNavigationView]).
  final Widget child;

  const AdwDialog({
    super.key,
    this.contentWidth = 360.0,
    this.contentHeight,
    this.title,
    this.canClose = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final isWindowActive = AdwWindowScope.maybeOf(context)?.isActive ?? true;
    final radius = BorderRadius.circular(AdwMetrics.windowRadius);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: contentWidth,
          minWidth: contentWidth < 280 ? contentWidth : 280,
          maxHeight: contentHeight ?? double.infinity,
          minHeight: contentHeight ?? 0,
        ),
        child: SizedBox(
          width: contentWidth,
          height: contentHeight,
          child: AnimatedContainer(
            duration: AdwCurves.shortDuration,
            decoration: BoxDecoration(
              color: theme.colors.windowBackground,
              borderRadius: radius,
              border: Border.all(
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
                      title: title,
                      child: child,
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
          ),
        ),
      ),
    );
  }
}

/// Presents an [AdwDialog] modally over the current window, propagating
/// [AdwWindowScope] so dragging any [AdwHeaderBar] inside the dialog moves
/// the host window seamlessly.
Future<T?> showAdwDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final parentWindowScope = AdwWindowScope.maybeOf(context);
  final theme = AdwTheme.of(context);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x66000000),
    transitionDuration: AdwCurves.resolve(context, AdwCurves.shortDuration),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      Widget content = AdwTheme(
        data: theme,
        child: CallbackShortcuts(
          bindings: {
            if (barrierDismissible)
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
        final activeListenable = parentWindowScope.controller?.activeListenable;
        if (activeListenable != null) {
          final innerContent = content;
          content = ValueListenableBuilder<bool>(
            valueListenable: activeListenable,
            builder: (_, isActive, __) => AdwWindowScope(
              controller: parentWindowScope.controller,
              isMaximized: parentWindowScope.isMaximized,
              isActive: isActive,
              child: innerContent,
            ),
          );
        } else {
          content = AdwWindowScope(
            controller: parentWindowScope.controller,
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
