import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../layout/adw_window.dart';

/// Modern Libadwaita alert dialog (`AdwAlertDialog`).
///
/// Replaces legacy GTK dialogs with a clean, centered layout,
/// 14px rounded corners ([AdwMetrics.dialogRadius]), and styled response action buttons.
class AdwAlertDialog extends StatelessWidget {
  final Widget? heading;
  final Widget? body;
  final Widget? content;
  final List<Widget> actions;
  final VoidCallback? onStartDrag;

  const AdwAlertDialog({
    super.key,
    this.heading,
    this.body,
    this.content,
    this.actions = const <Widget>[],
    this.onStartDrag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 280,
          maxWidth: 380,
        ),
        child: Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colors.dialogBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colors.isDark
                  ? const Color(0x14FFFFFF)
                  : theme.colors.borderColor,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D000000),
                blurRadius: 24,
                spreadRadius: 2,
                offset: Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) => (onStartDrag ??
                    AdwWindowScope.maybeOf(context)?.controller?.startDragging)
                ?.call(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 32, 22, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (heading != null)
                        DefaultTextStyle(
                          style: theme.typography.title2,
                          textAlign: TextAlign.center,
                          child: heading!,
                        ),
                      if (body != null) ...[
                        const SizedBox(height: 10),
                        DefaultTextStyle(
                          style: theme.typography.body,
                          textAlign: TextAlign.center,
                          child: body!,
                        ),
                      ],
                      if (content != null) ...[
                        const SizedBox(height: 8),
                        content!,
                      ],
                    ],
                  ),
                ),
                if (actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                    child: actions.length > 2
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int i = actions.length - 1; i >= 0; i--) ...[
                                if (i < actions.length - 1)
                                  const SizedBox(height: 12),
                                actions[i],
                              ],
                            ],
                          )
                        : Row(
                            children: [
                              for (int i = 0; i < actions.length; i++) ...[
                                if (i > 0) const SizedBox(width: 12),
                                Expanded(child: actions[i]),
                              ],
                            ],
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays an [AdwAlertDialog] with smooth GNOME transition animation.
Future<T?> showAdwAlertDialog<T>({
  required BuildContext context,
  Widget? heading,
  Widget? body,
  Widget? content,
  List<Widget> actions = const <Widget>[],
  bool barrierDismissible = true,
}) {
  final themeData = AdwTheme.maybeOf(context);
  final windowController = AdwWindowScope.maybeOf(context)?.controller;

  return Navigator.of(context, rootNavigator: true).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: barrierDismissible,
      barrierColor: const Color(0x66000000),
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        Widget dialog = AdwAlertDialog(
          heading: heading,
          body: body,
          content: content,
          actions: actions,
          onStartDrag: windowController?.startDragging,
        );
        if (AdwTheme.maybeOf(dialogContext) == null && themeData != null) {
          dialog = AdwTheme(data: themeData, child: dialog);
        }
        if (windowController != null) {
          dialog = AdwWindowResizeOverlay(
            controller: windowController,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowController.startDragging(),
              child: dialog,
            ),
          );
        }
        return dialog;
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        final scaleAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(scaleAnimation),
            child: child,
          ),
        );
      },
    ),
  );
}
