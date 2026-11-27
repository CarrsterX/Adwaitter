import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'adw_colors.dart';
import 'adw_style_platform_stub.dart'
    if (dart.library.io) 'adw_style_platform_io.dart' as style_platform;
import 'adw_typography.dart';

/// System color scheme preference mirroring Libadwaita's `AdwColorScheme`.
///
/// {@category Theming & Localization}
enum AdwSystemColorScheme {
  /// Follow the system default (typically light, unless `prefer-dark` is set).
  defaultScheme,

  /// Prefer dark appearance (`prefer-dark`).
  preferDark,

  /// Prefer light appearance (`prefer-light`).
  preferLight,
}

/// Immutable snapshot of host desktop appearance settings.
class AdwSystemAppearance {
  final AdwSystemColorScheme colorScheme;
  final AdwAccentColor accentColor;
  final bool highContrast;

  const AdwSystemAppearance({
    this.colorScheme = AdwSystemColorScheme.defaultScheme,
    this.accentColor = AdwAccentColor.blue,
    this.highContrast = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdwSystemAppearance &&
          runtimeType == other.runtimeType &&
          colorScheme == other.colorScheme &&
          accentColor == other.accentColor &&
          highContrast == other.highContrast;

  @override
  int get hashCode => Object.hash(colorScheme, accentColor, highContrast);
}

/// Central appearance coordinator mirroring GNOME Libadwaita's `AdwStyleManager`.
///
/// Acts as the single source of truth for light/dark theme transitions and
/// system accent color changes, synchronizing live with the host desktop
/// environment (GNOME `org.gnome.desktop.interface` via `libadwaitter/settings`)
/// while allowing applications to override preferences centrally.
class AdwStyleManager extends ChangeNotifier {
  AdwStyleManager._();

  /// The global default [AdwStyleManager] instance (analogous to `adw_style_manager_get_default()`).
  static final AdwStyleManager instance = AdwStyleManager._();

  static const MethodChannel _channel = MethodChannel('libadwaitter/style');
  static bool _initialized = false;
  static bool _emojiFontLoaded = false;

  AdwSystemAppearance _systemAppearance = const AdwSystemAppearance();
  AdwSystemColorScheme? _colorSchemeOverride;
  AdwAccentColor? _accentColorOverride;
  Color? _customAccentColorOverride;
  Color? _systemDynamicAccentLight;
  Color? _systemDynamicAccentDark;
  bool _hasPlatformBridge = false;

  /// Current appearance reported by the host desktop environment.
  AdwSystemAppearance get systemAppearance => _systemAppearance;

  /// Active color scheme (override if set, otherwise host system preference).
  AdwSystemColorScheme get colorScheme =>
      _colorSchemeOverride ?? _systemAppearance.colorScheme;

  /// Active accent color (override if set, otherwise host system accent color).
  AdwAccentColor get accentColor =>
      _accentColorOverride ?? _systemAppearance.accentColor;

  /// Optional custom accent [Color] override (e.g. Android 12+ wallpaper
  /// dynamic color or a custom app accent). Returns `null` when an explicit
  /// [AdwAccentColor] enum override is active or no dynamic color is present.
  Color? get resolvedCustomAccentColor {
    if (_customAccentColorOverride != null) return _customAccentColorOverride;
    if (_accentColorOverride != null) return null;
    if (_systemDynamicAccentLight == null && _systemDynamicAccentDark == null) {
      return null;
    }
    return isDark
        ? (_systemDynamicAccentDark ?? _systemDynamicAccentLight)
        : (_systemDynamicAccentLight ?? _systemDynamicAccentDark);
  }

  /// Effective resolved accent [Color], combining custom/dynamic colors and
  /// standard [AdwAccentColor] tokens.
  Color get effectiveAccentColor =>
      resolvedCustomAccentColor ?? accentColor.color;

  /// Whether high-contrast mode is enabled on the host desktop.
  bool get highContrast => _systemAppearance.highContrast;

  /// Whether the resolved appearance is dark.
  bool get isDark {
    switch (colorScheme) {
      case AdwSystemColorScheme.preferDark:
        return true;
      case AdwSystemColorScheme.preferLight:
        return false;
      case AdwSystemColorScheme.defaultScheme:
        // In Libadwaita/GNOME, 'default' resolves to light unless dark is explicitly preferred.
        if (_hasPlatformBridge) {
          return false;
        }
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  /// Centrally overrides the application's color scheme (pass `null` to follow system).
  set colorScheme(AdwSystemColorScheme? value) {
    if (_colorSchemeOverride == value) return;
    _colorSchemeOverride = value;
    notifyListeners();
  }

  /// Centrally overrides the application's accent color (pass `null` to follow system).
  set accentColor(AdwAccentColor? value) {
    if (_accentColorOverride == value && _customAccentColorOverride == null) {
      return;
    }
    _customAccentColorOverride = null;
    _accentColorOverride = value;
    notifyListeners();
  }

  /// Centrally overrides the application's accent with a custom [Color]
  /// (pass `null` to fall back to system/dynamic or [accentColor]).
  set customAccentColor(Color? value) {
    if (_customAccentColorOverride == value) return;
    _customAccentColorOverride = value;
    notifyListeners();
  }

  /// Initializes the platform bridge for live system theme & accent synchronization.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onSystemAppearanceChanged') {
          final Map<dynamic, dynamic>? args =
              call.arguments as Map<dynamic, dynamic>?;
          if (args != null) {
            instance._updateFromMap(args);
          }
        }
      });
      instance._fetchInitialAppearance();
      instance._loadSystemEmojiFont();
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      instance._fetchAndroidDynamicAccent();
    }
  }

  /// Refreshes system appearance / dynamic accent from the host platform.
  void refreshSystemAppearance() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _fetchAndroidDynamicAccent();
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      _fetchInitialAppearance();
    }
  }

  Future<void> _fetchAndroidDynamicAccent() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getSystemDynamicAccent');
      if (result == null) return;
      final int? lightArgb = result['light'] as int?;
      final int? darkArgb = result['dark'] as int?;
      final Color? nextLight = lightArgb != null ? Color(lightArgb) : null;
      final Color? nextDark = darkArgb != null ? Color(darkArgb) : null;
      if (nextLight != _systemDynamicAccentLight ||
          nextDark != _systemDynamicAccentDark) {
        _systemDynamicAccentLight = nextLight;
        _systemDynamicAccentDark = nextDark;
        notifyListeners();
      }
    } catch (_) {
      // Gracefully fall back to standard Adwaita accent colors if unavailable
    }
  }

  Future<void> _loadSystemEmojiFont() async {
    if (_emojiFontLoaded) return;
    _emojiFontLoaded = true;
    try {
      String? fontPath;
      try {
        fontPath = await _channel.invokeMethod<String>('getSystemEmojiFontPath');
      } catch (_) {
        // Fall back to direct fc-match query if runner does not implement method
      }
      if (fontPath == null || fontPath.isEmpty) {
        fontPath = await style_platform.querySystemEmojiFontPath();
      }
      if (fontPath == null || fontPath.isEmpty) return;
      final bytes = await style_platform.readLocalFileBytes(fontPath);
      if (bytes == null) return;
      final loader = FontLoader(AdwTypography.systemEmojiFamily)
        ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
      notifyListeners();
    } catch (_) {
      _emojiFontLoaded = false;
    }
  }

  void _fetchInitialAppearance() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getSystemAppearance');
      if (result != null) {
        _updateFromMap(result);
      }
    } catch (_) {
      // Gracefully retain platformBrightness / default accent if channel is unavailable
    }
  }

  /// Called by [AdwApplication] when platform brightness changes at the engine level.
  void handlePlatformBrightnessChanged() {
    if (_colorSchemeOverride == null) {
      notifyListeners();
    }
  }

  void _updateFromMap(Map<dynamic, dynamic> map) {
    final String? schemeStr = map['colorScheme'] as String?;
    final String? accentStr = map['accentColor'] as String?;
    final bool highContrast = map['highContrast'] as bool? ?? false;

    final next = AdwSystemAppearance(
      colorScheme: _parseColorScheme(schemeStr),
      accentColor: _parseAccentColor(accentStr),
      highContrast: highContrast,
    );

    final bool firstBridgeSync = !_hasPlatformBridge;
    _hasPlatformBridge = true;

    if (next != _systemAppearance || firstBridgeSync) {
      _systemAppearance = next;
      notifyListeners();
    }
  }

  static AdwSystemColorScheme _parseColorScheme(String? value) {
    switch (value) {
      case 'prefer-dark':
        return AdwSystemColorScheme.preferDark;
      case 'prefer-light':
        return AdwSystemColorScheme.preferLight;
      default:
        return AdwSystemColorScheme.defaultScheme;
    }
  }

  static AdwAccentColor _parseAccentColor(String? value) {
    switch (value) {
      case 'teal':
        return AdwAccentColor.teal;
      case 'green':
        return AdwAccentColor.green;
      case 'yellow':
        return AdwAccentColor.yellow;
      case 'orange':
        return AdwAccentColor.orange;
      case 'red':
        return AdwAccentColor.red;
      case 'pink':
        return AdwAccentColor.pink;
      case 'purple':
        return AdwAccentColor.purple;
      case 'slate':
        return AdwAccentColor.slate;
      case 'blue':
      default:
        return AdwAccentColor.blue;
    }
  }
}
