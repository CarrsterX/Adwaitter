import 'package:flutter/widgets.dart';

/// Localized strings for Libadwaitter components (default: English).
///
/// Retrieve the active instance using `AdwLocalizations.of(context)`.
///
/// {@category Theming & Localization}
class AdwLocalizations {
  /// Active locale for this localization bundle.
  final Locale locale;

  /// Creates a localization bundle for [locale].
  const AdwLocalizations(this.locale);

  static const AdwLocalizations _defaultInstance = AdwLocalizations(Locale('en'));

  /// Returns the nearest [AdwLocalizations] from [context], falling back to
  /// English defaults when no [Localizations] ancestor is present.
  static AdwLocalizations of(BuildContext context) {
    return Localizations.of<AdwLocalizations>(context, AdwLocalizations) ?? _defaultInstance;
  }

  /// Tooltip for the window close button.
  String get closeButtonTooltip => 'Close';

  /// Tooltip for the window minimize button.
  String get minimizeButtonTooltip => 'Minimize';

  /// Tooltip for the window maximize button.
  String get maximizeButtonTooltip => 'Maximize';

  /// Tooltip for the window unmaximize/restore button.
  String get restoreButtonTooltip => 'Restore';

  /// Standard "Cancel" dialog action label.
  String get cancelLabel => 'Cancel';

  /// Standard "OK" dialog action label.
  String get okLabel => 'OK';

  /// Standard "Close" dialog action label.
  String get closeLabel => 'Close';

  /// Standard "Reset" action label.
  String get resetLabel => 'Reset';

  /// Default title for [AdwAboutDialog].
  String get aboutDialogTitle => 'About';

  /// Label for the version section in [AdwAboutDialog].
  String get versionLabel => 'Version';

  /// Label for the credits section in [AdwAboutDialog].
  String get creditsLabel => 'Credits';

  /// Label for the license section in [AdwAboutDialog].
  String get licenseLabel => 'License';

  /// Label for the website link in [AdwAboutDialog].
  String get websiteLabel => 'Website';

  /// Default placeholder text for search inputs.
  String get searchPlaceholder => 'Search';

  /// Tooltip for clear-text buttons inside entries and search bars.
  String get clearTextTooltip => 'Clear text';
}

/// Localization delegate for [AdwLocalizations].
///
/// {@category Theming & Localization}
class AdwLocalizationsDelegate extends LocalizationsDelegate<AdwLocalizations> {
  /// Creates a localization delegate for [AdwLocalizations].
  const AdwLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AdwLocalizations> load(Locale locale) {
    return Future.value(AdwLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AdwLocalizations> old) => false;
}

