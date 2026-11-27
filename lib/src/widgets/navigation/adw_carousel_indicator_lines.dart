import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_theme.dart';
import 'adw_carousel.dart';

/// Paginated line indicator widget for [AdwCarousel] (`AdwCarouselIndicatorLines`).
///
/// Syncs continuously with [AdwCarouselController.page] and supports both
/// [Axis.horizontal] and [Axis.vertical] orientations.
///
/// ```dart
/// AdwCarouselIndicatorLines(controller: carouselController)
/// ```
///
/// See also:
///
/// * [AdwCarousel], the carousel widget driven by [controller].
/// * [AdwCarouselIndicatorDots], the dot indicator alternative.
///
/// {@category Navigation}
class AdwCarouselIndicatorLines extends StatelessWidget {
  /// Optional carousel controller driving continuous position and page count.
  final AdwCarouselController? controller;

  /// Explicit page count when used independently of [AdwCarouselController].
  final int? itemCount;

  /// Explicit active page index when used independently.
  final int? currentPage;

  /// Explicit continuous position when used independently.
  final double? position;

  /// Layout orientation of the indicator (`Axis.horizontal` or `Axis.vertical`).
  final Axis orientation;

  /// Callback invoked when a line segment is clicked.
  final ValueChanged<int>? onLineClicked;

  static const double _lineWidth = 3.0;
  static const double _lineLength = 35.0;
  static const double _lineSpacing = 5.0;
  static const double _lineOpacity = 0.3;
  static const double _lineOpacityActive = 0.9;
  static const double _lineMargin = 2.0;

  const AdwCarouselIndicatorLines({
    super.key,
    this.controller,
    this.itemCount,
    this.currentPage,
    this.position,
    this.orientation = Axis.horizontal,
    this.onLineClicked,
  });

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return AnimatedBuilder(
        animation: controller!,
        builder: (context, _) {
          return _buildLines(
            context,
            count: controller!.itemCount,
            pos: controller!.page,
            onTap: (index) {
              final duration =
                  AdwCurves.resolve(context, AdwCurves.normalDuration);
              controller!.animateToPage(index, duration: duration);
              onLineClicked?.call(index);
            },
          );
        },
      );
    }

    return _buildLines(
      context,
      count: itemCount ?? 0,
      pos: position ?? (currentPage ?? 0).toDouble(),
      onTap: onLineClicked,
    );
  }

  Widget _buildLines(
    BuildContext context, {
    required int count,
    required double pos,
    required ValueChanged<int>? onTap,
  }) {
    if (count <= 1) return const SizedBox.shrink();

    final theme = AdwTheme.of(context);
    final step = _lineLength + _lineSpacing;
    final length = count * step - _lineSpacing + _lineMargin * 2;
    final thickness = _lineWidth + _lineMargin * 2 + 8.0;

    final width = orientation == Axis.horizontal ? length : thickness;
    final height = orientation == Axis.horizontal ? thickness : length;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: onTap == null
          ? null
          : (details) {
              final localCoord = orientation == Axis.horizontal
                  ? details.localPosition.dx
                  : details.localPosition.dy;
              final index = ((localCoord - _lineMargin) / step)
                  .floor()
                  .clamp(0, count - 1);
              onTap(index);
            },
      child: MouseRegion(
        cursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: CustomPaint(
          size: Size(width, height),
          painter: _LinesIndicatorPainter(
            count: count,
            position: pos,
            orientation: orientation,
            color: theme.colors.foreground,
            lineWidth: _lineWidth,
            lineLength: _lineLength,
            lineSpacing: _lineSpacing,
            lineOpacity: _lineOpacity,
            lineOpacityActive: _lineOpacityActive,
          ),
        ),
      ),
    );
  }
}

class _LinesIndicatorPainter extends CustomPainter {
  final int count;
  final double position;
  final Axis orientation;
  final Color color;
  final double lineWidth;
  final double lineLength;
  final double lineSpacing;
  final double lineOpacity;
  final double lineOpacityActive;

  _LinesIndicatorPainter({
    required this.count,
    required this.position,
    required this.orientation,
    required this.color,
    required this.lineWidth,
    required this.lineLength,
    required this.lineSpacing,
    required this.lineOpacity,
    required this.lineOpacityActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final step = lineLength + lineSpacing;
    final indicatorLength = count * step - lineSpacing;

    final startX = orientation == Axis.horizontal
        ? (size.width - indicatorLength) / 2.0
        : (size.width - lineWidth) / 2.0;
    final startY = orientation == Axis.horizontal
        ? (size.height - lineWidth) / 2.0
        : (size.height - indicatorLength) / 2.0;

    final trackPaint = Paint()
      ..color = color.withValues(alpha: lineOpacity)
      ..isAntiAlias = true;

    for (int i = 0; i < count; i++) {
      final offset = i * step;
      final rect = orientation == Axis.horizontal
          ? Rect.fromLTWH(startX + offset, startY, lineLength, lineWidth)
          : Rect.fromLTWH(startX, startY + offset, lineWidth, lineLength);
      canvas.drawRect(rect, trackPaint);
    }

    final activeOffset = position.clamp(0.0, (count - 1).toDouble()) * step;
    final activePaint = Paint()
      ..color = color.withValues(alpha: lineOpacityActive)
      ..isAntiAlias = true;

    final activeRect = orientation == Axis.horizontal
        ? Rect.fromLTWH(startX + activeOffset, startY, lineLength, lineWidth)
        : Rect.fromLTWH(startX, startY + activeOffset, lineWidth, lineLength);
    canvas.drawRect(activeRect, activePaint);
  }

  @override
  bool shouldRepaint(covariant _LinesIndicatorPainter oldDelegate) {
    return oldDelegate.count != count ||
        oldDelegate.position != position ||
        oldDelegate.orientation != orientation ||
        oldDelegate.color != color;
  }
}
