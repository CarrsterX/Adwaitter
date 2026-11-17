import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/adw_theme.dart';

// Constants ported 1:1 from libadwaita's `adw-spinner-paintable.c`.
const double _kSpinDurationMs = 1200;
const double _kStartAngle = math.pi * 0.35;
const double _kCircleOpacity = 0.15;
const double _kMinArcLength = math.pi * 0.015;
const double _kMaxArcLength = math.pi * 0.9;
const double _kIdleDistance = math.pi * 0.9;
const double _kOverlapDistance = math.pi * 0.7;
const double _kExtendDistance = math.pi * 1.1;
const double _kContractDistance = math.pi * 1.35;
const double _kMaxRadius = 32;

/// How many full cycles it takes for the spinner to loop seamlessly.
const int _kNCycles = 53;

const double _kCycleLength = _kIdleDistance +
    _kExtendDistance +
    _kContractDistance -
    _kOverlapDistance;

double _easeInOutSine(double t) => -(math.cos(math.pi * t) - 1) / 2;

double _lerp(double a, double b, double t) => a * (1 - t) + b * t;

double _arcStart(double angle) {
  angle = angle % _kCycleLength;
  final double t;
  if (angle > _kExtendDistance) {
    t = 1;
  } else {
    t = _easeInOutSine(angle / _kExtendDistance);
  }
  return _lerp(_kMinArcLength, _kMaxArcLength, t) -
      angle * _kMaxArcLength / _kCycleLength;
}

double _arcEnd(double angle) {
  angle = angle % _kCycleLength;
  final double t;
  if (angle < _kExtendDistance - _kOverlapDistance) {
    t = 0;
  } else if (angle > _kCycleLength - _kIdleDistance) {
    t = 1;
  } else {
    t = _easeInOutSine(
      (angle - _kExtendDistance + _kOverlapDistance) / _kContractDistance,
    );
  }
  return _lerp(0, _kMaxArcLength - _kMinArcLength, t) -
      angle * _kMaxArcLength / _kCycleLength;
}

double _normalizeAngle(double angle) {
  const twoPi = math.pi * 2;
  while (angle < 0) {
    angle += twoPi;
  }
  while (angle > twoPi) {
    angle -= twoPi;
  }
  return angle;
}

/// A modern GNOME Libadwaita spinner (`AdwSpinner` / `AdwSpinnerPaintable`).
///
/// The drawn circle is capped at 64×64 (radius 32) and centered inside the
/// available [size], exactly like the native paintable.
class AdwSpinner extends StatefulWidget {
  const AdwSpinner({
    super.key,
    this.size = 32,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  State<AdwSpinner> createState() => _AdwSpinnerState();
}

class _AdwSpinnerState extends State<AdwSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (_kSpinDurationMs * _kNCycles).round(),
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedColor = widget.color ??
        IconTheme.of(context).color ??
        AdwTheme.of(context).colors.windowForeground;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _AdwSpinnerPainter(
              // Linear progress in radians: 2π per SPIN_DURATION_MS.
              progress: _controller.value * _kNCycles * math.pi * 2,
              color: resolvedColor,
            ),
          );
        },
      ),
    );
  }
}

class _AdwSpinnerPainter extends CustomPainter {
  const _AdwSpinnerPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min((math.min(size.width, size.height) / 2).floorToDouble(), _kMaxRadius);
    final lineWidth = (radius * 2) / 10.0;
    if (radius < lineWidth / 2) return;

    final center = Offset(
      (size.width / 2).roundToDouble(),
      (size.height / 2).roundToDouble(),
    );
    final circleRadius = radius - lineWidth / 2;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;

    // Track circle.
    canvas.drawCircle(
      center,
      circleRadius,
      strokePaint..color = color.withValues(alpha: _kCircleOpacity),
    );

    // Moving arc, drawn clockwise from `end` to `start`.
    final baseAngle = progress;
    final startAngle =
        _normalizeAngle(baseAngle + _arcStart(baseAngle) + _kStartAngle);
    final endAngle =
        _normalizeAngle(baseAngle + _arcEnd(baseAngle) + _kStartAngle);

    var sweep = startAngle - endAngle;
    if (sweep < 0) sweep += math.pi * 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: circleRadius),
      endAngle,
      sweep,
      false,
      strokePaint..color = color,
    );
  }

  @override
  bool shouldRepaint(_AdwSpinnerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
