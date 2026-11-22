import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/adw_text_selection.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';

/// Reusable Libadwaita / GTK4 revealable search bar (`GtkSearchBar`).
///
/// Slides down smoothly via an internal revealer when [revealed] is `true`,
/// includes a magnifying glass prefix, placeholder text, clear button, and
/// Escape-to-close handling.
class AdwSearchBar extends StatefulWidget {
  final bool revealed;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String placeholder;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClose;

  const AdwSearchBar({
    super.key,
    required this.revealed,
    this.controller,
    this.focusNode,
    this.placeholder = 'Search',
    this.maxWidth = 400.0,
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 8),
    this.onChanged,
    this.onClose,
  });

  @override
  State<AdwSearchBar> createState() => _AdwSearchBarState();
}

class _AdwSearchBarState extends State<AdwSearchBar> {
  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;
  bool _focused = false;

  TextEditingController get _controller =>
      widget.controller ?? (_internalController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
  }

  @override
  void didUpdateWidget(covariant AdwSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.revealed && widget.revealed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.revealed) {
          _focusNode.requestFocus();
        }
      });
    } else if (oldWidget.revealed && !widget.revealed) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);
    _internalFocusNode?.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  void _onTextChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final hasText = _controller.text.isNotEmpty;

    return ClipRect(
      child: AnimatedAlign(
        duration: AdwCurves.normalDuration,
        curve: AdwCurves.standard,
        alignment: Alignment.topCenter,
        heightFactor: widget.revealed ? 1.0 : 0.0,
        child: AnimatedOpacity(
          duration: AdwCurves.normalDuration,
          curve: AdwCurves.standard,
          opacity: widget.revealed ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !widget.revealed,
            child: CallbackShortcuts(
              bindings: {
                if (widget.revealed && widget.onClose != null)
                  const SingleActivator(LogicalKeyboardKey.escape):
                      widget.onClose!,
              },
              child: Padding(
                padding: widget.padding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: widget.maxWidth),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _focusNode.requestFocus(),
                      child: AnimatedContainer(
                        duration: AdwCurves.shortDuration,
                        curve: AdwCurves.standard,
                        height: 34.0,
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        decoration: BoxDecoration(
                          color: theme.colors.windowForeground
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AdwMetrics.entryRadius),
                          border: _focused
                              ? Border.all(
                                  color: theme.colors.accentColor
                                      .withValues(alpha: 0.50),
                                  width: 2.0,
                                )
                              : null,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(14, 14),
                              painter: _SearchBarLensPainter(
                                color: theme.colors.secondaryForeground,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  if (!hasText)
                                    Text(
                                      widget.placeholder,
                                      style: theme.typography.body.copyWith(
                                        color: theme.colors.secondaryForeground,
                                        height: 1.0,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  AdwEditableText(
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    onTapOutside: (_) => _focusNode.unfocus(),
                                    style: theme.typography.body.copyWith(
                                      height: 1.0,
                                      leadingDistribution:
                                          TextLeadingDistribution.even,
                                    ),
                                    cursorColor: theme.colors.accentColor,
                                    backgroundCursorColor:
                                        theme.colors.dividerColor,
                                    selectionColor: theme.colors.accentColor
                                        .withValues(alpha: 0.3),
                                    onChanged: widget.onChanged,
                                  ),
                                ],
                              ),
                            ),
                            if (hasText) ...[
                              const SizedBox(width: 6),
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    _controller.clear();
                                    widget.onChanged?.call('');
                                  },
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Center(
                                      child: CustomPaint(
                                        size: const Size(9, 9),
                                        painter: _SearchBarClearPainter(
                                          color:
                                              theme.colors.secondaryForeground,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
    );
  }
}

class _SearchBarLensPainter extends CustomPainter {
  final Color color;

  const _SearchBarLensPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width * 0.42, size.height * 0.42);
    final radius = size.width * 0.30;
    canvas.drawCircle(center, radius, paint);
    canvas.drawLine(
      Offset(center.dx + radius * 0.72, center.dy + radius * 0.72),
      Offset(size.width * 0.88, size.height * 0.88),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SearchBarLensPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SearchBarClearPainter extends CustomPainter {
  final Color color;

  const _SearchBarClearPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

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
  bool shouldRepaint(covariant _SearchBarClearPainter oldDelegate) =>
      oldDelegate.color != color;
}
