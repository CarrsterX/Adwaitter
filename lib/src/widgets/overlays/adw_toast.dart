import 'dart:async';
import 'package:flutter/widgets.dart';

import '../../core/adw_insets.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';

/// Data model for a Libadwaita floating in-app notification (`AdwToast`).
class AdwToast {
  final Widget title;
  final Widget? action;
  final Duration timeout;
  final VoidCallback? onDismissed;

  const AdwToast({
    required this.title,
    this.action,
    this.timeout = const Duration(seconds: 5),
    this.onDismissed,
  });
}

/// Floating toast notification overlay layer (`AdwToastOverlay`).
///
/// Places pill-styled in-app notifications at the bottom center of the window,
/// matching Libadwaita specifications.
class AdwToastOverlay extends StatefulWidget {
  final Widget child;

  const AdwToastOverlay({
    super.key,
    required this.child,
  });

  static _AdwToastOverlayState of(BuildContext context) {
    final state = context.findAncestorStateOfType<_AdwToastOverlayState>();
    assert(
      state != null,
      'No AdwToastOverlay found in context. '
      'Wrap your view or content hierarchy with AdwToastOverlay.',
    );
    return state!;
  }

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
  bool _isCloseHovered = false;

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

    return Stack(
      children: [
        widget.child,
        if (_currentToast != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 22 + adwBottomSystemInset(context),
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
                        if (_currentToast != null && !_isDismissing) {
                          _timer?.cancel();
                          _timer = Timer(_currentToast!.timeout, () {
                            _dismissCurrentToast();
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 7, 8, 7),
                        decoration: BoxDecoration(
                          color: theme.colors.isDark
                              ? const Color(0xFF505053)
                              : const Color(0xFF2E2E32),
                          borderRadius:
                              BorderRadius.circular(AdwMetrics.pillRadius),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x38000000),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: DefaultTextStyle(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.body.copyWith(
                                  color: const Color(0xFFFFFFFF),
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
                              width: _currentToast!.action != null ? 6 : 12,
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) =>
                                  setState(() => _isCloseHovered = true),
                              onExit: (_) =>
                                  setState(() => _isCloseHovered = false),
                              child: GestureDetector(
                                onTap: _dismissCurrentToast,
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isCloseHovered
                                        ? const Color(0x24FFFFFF)
                                        : const Color(0x00000000),
                                  ),
                                  child: const Center(
                                    child: CustomPaint(
                                      size: Size(10, 10),
                                      painter: _ToastCloseIconPainter(
                                        color: Color(0xFFFFFFFF),
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
      ],
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
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      const Offset(0.5, 0.5),
      Offset(size.width - 0.5, size.height - 0.5),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 0.5, 0.5),
      Offset(0.5, size.height - 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ToastCloseIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
