import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_theme.dart';

/// Libadwaita progress bar (`GtkProgressBar` / `.osd`).
///
/// Pass a [value] in `0.0..1.0` for determinate progress, or `null` for an
/// indeterminate pulsing bar. Set [isOsd] to `true` for the slim edge-attached
/// `.osd` overlay progress bar (`3px` height, square corners).
class AdwProgressBar extends StatefulWidget {
  final double? value;
  final bool isOsd;
  final double? height;
  final Color? color;
  final Color? trackColor;

  const AdwProgressBar({
    super.key,
    this.value,
    this.isOsd = false,
    this.height,
    this.color,
    this.trackColor,
  });

  @override
  State<AdwProgressBar> createState() => _AdwProgressBarState();
}

class _AdwProgressBarState extends State<AdwProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.value == null) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AdwProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == null && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (widget.value != null && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final effectiveHeight = widget.height ?? (widget.isOsd ? 2.0 : 6.0);
    final effectiveRadius =
        widget.isOsd ? BorderRadius.zero : BorderRadius.circular(99.0);
    final effectiveTrack = widget.trackColor ??
        theme.colors.windowForeground.withValues(
          alpha: widget.isOsd ? 0.12 : 0.15,
        );
    final effectiveFill = widget.color ?? theme.colors.accentColor;

    if (widget.value != null) {
      final fraction = widget.value!.clamp(0.0, 1.0);
      return ClipRRect(
        borderRadius: effectiveRadius,
        child: Container(
          height: effectiveHeight,
          color: effectiveTrack,
          alignment: Alignment.centerLeft,
          child: AnimatedFractionallySizedBox(
            duration: AdwCurves.shortDuration,
            curve: AdwCurves.standard,
            widthFactor: fraction,
            child: Container(
              height: effectiveHeight,
              decoration: BoxDecoration(
                color: effectiveFill,
                borderRadius: effectiveRadius,
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: Container(
        height: effectiveHeight,
        color: effectiveTrack,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final barWidth = width * 0.30;
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_pulseController.value);
                final left = (width - barWidth) * t;
                return Stack(
                  children: [
                    Positioned(
                      left: left,
                      top: 0,
                      bottom: 0,
                      width: barWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: effectiveFill,
                          borderRadius: effectiveRadius,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
