import 'dart:math' as math;
import 'package:flutter/physics.dart';

import '../theme/adw_desktop_settings.dart';

/// Spring physics parameters mirroring Libadwaita's `AdwSpringParams`.
///
/// Used to drive fluid, velocity-preserving transitions for predictive
/// navigation gestures, carousels, and sheets without synthetic cubic curves.
class AdwSpringParams {
  /// Damping ratio (`>= 0.0`). `1.0` is critically damped (no oscillation).
  final double dampingRatio;

  /// Mass of the simulated object (`> 0.0`).
  final double mass;

  /// Spring stiffness (`> 0.0`). Higher values produce snappier transitions.
  final double stiffness;

  const AdwSpringParams({
    required this.dampingRatio,
    required this.mass,
    required this.stiffness,
  })  : assert(dampingRatio >= 0.0),
        assert(mass > 0.0),
        assert(stiffness > 0.0);

  /// Standard critically-damped spring used by Libadwaita `AdwNavigationView`
  /// for page push/pop and predictive swipe-back completion/cancellation.
  static const AdwSpringParams navigation = AdwSpringParams(
    dampingRatio: 1.0,
    mass: 1.0,
    stiffness: 280.0,
  );

  /// Slightly softer spring suitable for sheets and carousels.
  static const AdwSpringParams gentle = AdwSpringParams(
    dampingRatio: 0.92,
    mass: 1.0,
    stiffness: 300.0,
  );

  /// Critically-damped spring matching upstream `AdwOverlaySplitView`
  /// (`adw_spring_params_new(1, 0.5, 500)`).
  static const AdwSpringParams splitView = AdwSpringParams(
    dampingRatio: 1.0,
    mass: 0.5,
    stiffness: 500.0,
  );

  /// Underdamped spring matching upstream `AdwBottomSheet`
  /// (`SPRING_DAMPING = 0.8`, `mass = 1.0`, `SPRING_STIFFNESS = 400`).
  static const AdwSpringParams bottomSheet = AdwSpringParams(
    dampingRatio: 0.8,
    mass: 1.0,
    stiffness: 400.0,
  );

  /// Underdamped spring matching upstream `AdwFloatingSheet`
  /// (`SPRING_DAMPING = 0.62`, `mass = 1.0`, `SPRING_STIFFNESS = 500`).
  static const AdwSpringParams floatingSheet = AdwSpringParams(
    dampingRatio: 0.62,
    mass: 1.0,
    stiffness: 500.0,
  );

  /// Converts these parameters into a Flutter [SpringDescription].
  SpringDescription toSpringDescription() {
    final damping =
        2.0 * dampingRatio * math.sqrt(mass * stiffness);
    return SpringDescription(
      mass: mass,
      stiffness: stiffness,
      damping: damping,
    );
  }

  /// Creates a [Simulation] from [start] to [end] with initial [velocity],
  /// automatically scaled by the active desktop/Android animation duration
  /// factor (`AdwDesktopSettings.animationSettings`).
  Simulation createSimulation({
    required double start,
    required double end,
    double velocity = 0.0,
  }) {
    final settings = AdwDesktopSettings.animationSettings.value;
    final factor = settings.enableAnimations ? settings.durationFactor : 0.0;
    final base = SpringSimulation(
      toSpringDescription(),
      start,
      end,
      velocity,
    );
    if (factor == 1.0) {
      return base;
    }
    return _ScaledSpringSimulation(
      base: base,
      end: end,
      durationFactor: factor,
    );
  }
}

class _ScaledSpringSimulation extends Simulation {
  final SpringSimulation base;
  final double end;
  final double durationFactor;

  _ScaledSpringSimulation({
    required this.base,
    required this.end,
    required this.durationFactor,
  });

  @override
  double x(double time) {
    if (durationFactor <= 0.0) return end;
    return base.x(time / durationFactor);
  }

  @override
  double dx(double time) {
    if (durationFactor <= 0.0) return 0.0;
    return base.dx(time / durationFactor) / durationFactor;
  }

  @override
  bool isDone(double time) {
    if (durationFactor <= 0.0) return true;
    return base.isDone(time / durationFactor);
  }
}

