import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Bridges browser CSS Media Queries (`prefers-reduced-motion`,
/// `prefers-contrast`, `forced-colors`) into [AdwDesktopSettings] in real time.
void initializeWebAccessibilitySettings({
  required void Function(bool reducedMotion) onReducedMotionChanged,
  required void Function(bool highContrast) onHighContrastChanged,
}) {
  try {
    JSObject? matchMedia(String query) {
      final result = globalContext.callMethod<JSAny?>(
        'matchMedia'.toJS,
        query.toJS,
      );
      return result as JSObject?;
    }

    bool matches(JSObject? mql) {
      if (mql == null) return false;
      final val = mql.getProperty<JSAny?>('matches'.toJS);
      return (val as JSBoolean?)?.toDart ?? false;
    }

    void listen(JSObject? mql, void Function() callback) {
      mql?.callMethod<JSAny?>(
        'addEventListener'.toJS,
        'change'.toJS,
        ((JSAny? _) => callback()).toJS,
      );
    }

    final reducedMotionQuery = matchMedia('(prefers-reduced-motion: reduce)');
    if (reducedMotionQuery != null) {
      onReducedMotionChanged(matches(reducedMotionQuery));
      listen(reducedMotionQuery, () {
        onReducedMotionChanged(matches(reducedMotionQuery));
      });
    }

    final contrastMoreQuery = matchMedia('(prefers-contrast: more)');
    final forcedColorsQuery = matchMedia('(forced-colors: active)');

    void notifyContrast() {
      final isHigh = matches(contrastMoreQuery) || matches(forcedColorsQuery);
      onHighContrastChanged(isHigh);
    }

    notifyContrast();
    listen(contrastMoreQuery, notifyContrast);
    listen(forcedColorsQuery, notifyContrast);
  } catch (_) {
    // Gracefully ignore if browser environment restricts matchMedia
  }
}
