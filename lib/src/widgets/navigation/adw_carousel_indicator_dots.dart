import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_theme.dart';
import 'adw_carousel.dart';

/// Paginated dot indicator widget for [AdwCarousel] (`AdwCarouselIndicatorDots`).
///
/// Implements upstream GNOME Libadwaita specifications (`adw-carousel-indicator-dots.c`):
/// - Inactive dot: `6×6 px` circle (`radius: 3.0`) at `30%` foreground opacity.
/// - Active dot: `8×8 px` circle (`radius: 4.0`) at `90%` foreground opacity.
/// - Spacing: `7.0 px` between dots, `6.0 px` outer margin.
/// - Supports both [Axis.horizontal] and [Axis.vertical] orientations and
///   continuous interpolation synced with [AdwCarouselController.page].
class AdwCarouselIndicatorDots extends StatelessWidget {
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

  /// Callback invoked when a dot is clicked.
  final ValueChanged<int>? onDotClicked;

  static const double _dotRadius = 3.0;
  static const double _dotRadiusSelected = 4.0;
  static const double _dotOpacity = 0.3;
  static const double _dotOpacitySelected = 0.9;
  static const double _dotSpacing = 7.0;
  static const double _dotMargin = 6.0;

  const AdwCarouselIndicatorDots({
    super.key,
    this.controller,
    this.itemCount,
    this.currentPage,
    this.position,
    this.orientation = Axis.horizontal,
    this.onDotClicked,
  });

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return AnimatedBuilder(
        animation: controller!,
        builder: (context, _) {
          return _buildDots(
            context,
            count: controller!.itemCount,
            pos: controller!.page,
            onTap: (index) {
              final duration =
                  AdwCurves.resolve(context, AdwCurves.normalDuration);
              controller!.animateToPage(index, duration: duration);
              onDotClicked?.call(index);
            },
          );
        },
      );
    }

    return _buildDots(
      context,
      count: itemCount ?? 0,
      pos: position ?? (currentPage ?? 0).toDouble(),
      onTap: onDotClicked,
    );
  }

  Widget _buildDots(
    BuildContext context, {
    required int count,
    required double pos,
    required ValueChanged<int>? onTap,
  }) {
    if (count <= 1) return const SizedBox.shrink();

    final theme = AdwTheme.of(context);
    final slotSize = 2.0 * _dotRadiusSelected + _dotSpacing;
    final length = count * slotSize - _dotSpacing + _dotMargin * 2;
    final thickness = 2.0 * _dotRadiusSelected + _dotMargin * 2;

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
              final index = ((localCoord - _dotMargin) / slotSize)
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
          painter: _DotsIndicatorPainter(
            count: count,
            position: pos,
            orientation: orientation,
            color: theme.colors.foreground,
            dotRadius: _dotRadius,
            dotRadiusSelected: _dotRadiusSelected,
            dotOpacity: _dotOpacity,
            dotOpacitySelected: _dotOpacitySelected,
            dotSpacing: _dotSpacing,
            dotMargin: _dotMargin,
          ),
        ),
      ),
    );
  }
}

class _DotsIndicatorPainter extends CustomPainter {
  final int count;
  final double position;
  final Axis orientation;
  final Color color;
  final double dotRadius;
  final double dotRadiusSelected;
  final double dotOpacity;
  final double dotOpacitySelected;
  final double dotSpacing;
  final double dotMargin;

  _DotsIndicatorPainter({
    required this.count,
    required this.position,
    required this.orientation,
    required this.color,
    required this.dotRadius,
    required this.dotRadiusSelected,
    required this.dotOpacity,
    required this.dotOpacitySelected,
    required this.dotSpacing,
    required this.dotMargin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final slotSize = 2.0 * dotRadiusSelected + dotSpacing;
    final indicatorLength = count * slotSize - dotSpacing;

    double x = orientation == Axis.horizontal
        ? (size.width - indicatorLength) / 2.0
        : size.width / 2.0;
    double y = orientation == Axis.horizontal
        ? size.height / 2.0
        : (size.height - indicatorLength) / 2.0;

    final paint = Paint()..isAntiAlias = true;

    for (int i = 0; i < count; i++) {
      if (orientation == Axis.horizontal) {
        x += slotSize / 2.0 - dotSpacing / 2.0;
      } else {
        y += slotSize / 2.0 - dotSpacing / 2.0;
      }

      final progress = (1.0 - (position - i).abs()).clamp(0.0, 1.0);
      final radius = lerpDouble(dotRadius, dotRadiusSelected, progress)!;
      final opacity = lerpDouble(dotOpacity, dotOpacitySelected, progress)!;

      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);

      if (orientation == Axis.horizontal) {
        x += slotSize / 2.0 + dotSpacing / 2.0;
      } else {
        y += slotSize / 2.0 + dotSpacing / 2.0;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsIndicatorPainter oldDelegate) {
    return oldDelegate.count != count ||
        oldDelegate.position != position ||
        oldDelegate.orientation != orientation ||
        oldDelegate.color != color;
  }
}
