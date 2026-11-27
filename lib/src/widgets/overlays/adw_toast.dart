import 'dart:async';
import 'package:flutter/widgets.dart';

import '../../core/adw_insets.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';

/// Data model for a Libadwaita floating in-app notification (`AdwToast`).
///
/// Enqueue an [AdwToast] using `AdwToastOverlay.of(context).addToast(...)`.
///
/// ```dart
/// AdwToastOverlay.of(context).addToast(
///   const AdwToast(title: Text('Copied to clipboard')),
/// );
/// ```
///
/// See also:
///
/// * [AdwToastOverlay], the overlay widget that displays queued toasts.
/// * [AdwBanner], for persistent top-of-view contextual notifications.
///
/// {@category Overlays}
class AdwToast {
  /// Message widget displayed inside the toast pill.
  final Widget title;

  /// Optional trailing action button (e.g. "Undo").
  final Widget? action;

  /// Duration before the toast automatically dismisses. Defaults to 5 seconds.
  final Duration timeout;

  /// Optional callback invoked when the toast finishes dismissing.
  final VoidCallback? onDismissed;

  /// Creates an [AdwToast] notification descriptor.
  const AdwToast({
    required this.title,
    this.action,
    this.timeout = const Duration(seconds: 5),
    this.onDismissed,
  });
}

/// Floating toast notification overlay layer (`AdwToastOverlay`).
///
/// Places pill-styled in-app notifications at the bottom center of the window
/// (automatically offset above mobile system navigation bars), matching
/// Libadwaita specifications.
///
/// {@category Overlays}
class AdwToastOverlay extends StatefulWidget {
  /// Subtree over which queued [AdwToast] notifications are displayed.
  final Widget child;

  /// Creates a toast notification overlay wrapping [child].
  const AdwToastOverlay({
    super.key,
    required this.child,
  });

  /// Returns the nearest [AdwToastOverlay] state for enqueueing toasts,
  /// asserting if none exists in the widget tree.
  static _AdwToastOverlayState of(BuildContext context) {
    final state = context.findAncestorStateOfType<_AdwToastOverlayState>();
    assert(
      state != null,
      'No AdwToastOverlay found in context. '
      'Wrap your view or content hierarchy with AdwToastOverlay.',
    );
    return state!;
  }

  /// Safely returns the nearest [AdwToastOverlay] state, or `null` if absent.
  static _AdwToastOverlayState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<_AdwToastOverlayState>();
  }

  @override
  State<AdwToastOverlay> createState() => _AdwToastOverlayState();
}

class _AdwToastOverlayState extends State<AdwToastOverlay>
    with SingleTickerProviderStateMixin {
  final List<AdwToast> _queue = [];
  AdwToast? _currentToast;
  Timer? _timer;
  bool _isDismissing = false;
  bool _isToastHovered = false;
  bool _isToastFocused = false;
  bool _isCloseHovered = false;
  bool _isCloseFocused = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AdwCurves.windowDuration,
      reverseDuration: AdwCurves.mediumDuration,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: AdwCurves.smooth,
      reverseCurve: Curves.linear,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 2.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: AdwCurves.smooth,
    ));
    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  /// Adds and presents a new [AdwToast].
  void addToast(AdwToast toast) {
    if (_currentToast != null) {
      final currentHasAction = _currentToast!.action != null;
      final newHasAction = toast.action != null;
      // Same toast type (or current has an action): queue and wait.
      if (currentHasAction || currentHasAction == newHasAction) {
        _queue.add(toast);
        return;
      }
      _timer?.cancel();
      _queue.clear();
      _currentToast?.onDismissed?.call();
      setState(() {
        _currentToast = toast;
        _isDismissing = false;
      });
      _animController.forward(from: 0.0);
      if (!_isToastHovered) {
        _timer = Timer(toast.timeout, _dismissCurrentToast);
      }
      return;
    }
    _queue.add(toast);
    _showNextToast();
  }

  /// Replaces [replacing] in-place if it is currently displayed, resetting
  /// its timeout, or adds [toast] normally otherwise.
  void replaceOrAddToast(AdwToast toast, {AdwToast? replacing}) {
    if (replacing != null && _currentToast == replacing && !_isDismissing) {
      setState(() {
        _currentToast = toast;
      });
      _timer?.cancel();
      if (!_isToastHovered) {
        _timer = Timer(toast.timeout, _dismissCurrentToast);
      }
      return;
    }
    addToast(toast);
  }

  /// Dismisses [toast] if it is currently displayed or queued.
  void dismissToast(AdwToast toast) {
    if (_currentToast == toast) {
      _dismissCurrentToast();
    } else {
      _queue.remove(toast);
    }
  }

  /// Dismisses the current toast and clears any queued toasts.
  void dismissAll() {
    _queue.clear();
    if (_currentToast != null) {
      _dismissCurrentToast();
    }
  }

  void _showNextToast() {
    if (_queue.isEmpty) {
      _currentToast = null;
      return;
    }

    setState(() {
      _currentToast = _queue.removeAt(0);
      _isDismissing = false;
    });

    _animController.forward(from: 0.0);

    _timer?.cancel();
    if (!_isToastHovered) {
      _timer = Timer(_currentToast!.timeout, () {
        _dismissCurrentToast();
      });
    }
  }

  void _dismissCurrentToast() {
    _timer?.cancel();
    setState(() => _isDismissing = true);
    _animController.reverse().then((_) {
      _currentToast?.onDismissed?.call();
      _showNextToast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Stack(
        children: [
          FocusTraversalOrder(
            order: const NumericFocusOrder(1.0),
            child: widget.child,
          ),
          if (_currentToast != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 22 + adwBottomSystemInset(context),
              child: FocusTraversalOrder(
                order: const NumericFocusOrder(2.0),
                child: Semantics(
                  liveRegion: true,
                  child: Focus(
                    skipTraversal: true,
                    onFocusChange: (hasFocus) {
                      _isToastFocused = hasFocus;
                      if (hasFocus) {
                        _timer?.cancel();
                      } else if (!_isToastHovered &&
                          _currentToast != null &&
                          !_isDismissing) {
                        _timer?.cancel();
                        _timer = Timer(_currentToast!.timeout, () {
                          _dismissCurrentToast();
                        });
                      }
                    },
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FadeTransition(
                        opacity: _isDismissing
                            ? _fadeAnimation
                            : const AlwaysStoppedAnimation(1.0),
                        child: ScaleTransition(
                          scale: _isDismissing
                              ? _scaleAnimation
                              : const AlwaysStoppedAnimation(1.0),
                          child: SlideTransition(
                            position: _isDismissing
                                ? const AlwaysStoppedAnimation(Offset.zero)
                                : _slideAnimation,
                            child: MouseRegion(
                              onEnter: (_) {
                                _isToastHovered = true;
                                _timer?.cancel();
                              },
                              onExit: (_) {
                                _isToastHovered = false;
                                if (!_isToastFocused &&
                                    _currentToast != null &&
                                    !_isDismissing) {
                                  _timer?.cancel();
                                  _timer = Timer(_currentToast!.timeout, () {
                                    _dismissCurrentToast();
                                  });
                                }
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 7, 8, 7),
                                decoration: BoxDecoration(
                                  color: theme.colors.toastBackground,
                                  borderRadius: BorderRadius.circular(
                                      AdwMetrics.pillRadius),
                                  boxShadow: theme.colors.toastShadows,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: DefaultTextStyle(
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.typography.body.copyWith(
                                          color: theme.colors.toastForeground,
                                          fontWeight: FontWeight.w600,
                                          height: 1.0,
                                        ),
                                        child: _currentToast!.title,
                                      ),
                                    ),
                                    if (_currentToast!.action != null) ...[
                                      const SizedBox(width: 64),
                                      _currentToast!.action!,
                                    ],
                                    SizedBox(
                                      width:
                                          _currentToast!.action != null ? 6 : 12,
                                    ),
                                    Semantics(
                                      button: true,
                                      label: 'Close',
                                      onTap: _dismissCurrentToast,
                                      child: FocusableActionDetector(
                                        mouseCursor: SystemMouseCursors.click,
                                        onShowHoverHighlight: (hovered) {
                                          if (_isCloseHovered != hovered) {
                                            setState(
                                                () => _isCloseHovered = hovered);
                                          }
                                        },
                                        onShowFocusHighlight: (focused) {
                                          if (_isCloseFocused != focused) {
                                            setState(
                                                () => _isCloseFocused = focused);
                                          }
                                        },
                                        actions: <Type, Action<Intent>>{
                                          ActivateIntent:
                                              CallbackAction<ActivateIntent>(
                                            onInvoke: (_) {
                                              _dismissCurrentToast();
                                              return null;
                                            },
                                          ),
                                        },
                                        child: GestureDetector(
                                          onTap: _dismissCurrentToast,
                                          behavior: HitTestBehavior.opaque,
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: (_isCloseHovered ||
                                                      _isCloseFocused)
                                                  ? theme.colors
                                                      .toastCloseHoverBackground
                                                  : const Color(0x00000000),
                                              border: _isCloseFocused
                                                  ? Border.all(
                                                      color: theme.colors
                                                          .focusBorderColor,
                                                      width: 2.0,
                                                    )
                                                  : null,
                                            ),
                                            child: Center(
                                              child: CustomPaint(
                                                size: const Size(8, 8),
                                                painter:
                                                    _ToastCloseIconPainter(
                                                  color: theme
                                                      .colors.toastForeground,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToastCloseIconPainter extends CustomPainter {
  final Color color;

  const _ToastCloseIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const inset = 0.75;
    canvas.drawLine(
      const Offset(inset, inset),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ToastCloseIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
