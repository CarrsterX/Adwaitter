import 'package:flutter/widgets.dart';

import '../containers/adw_action_row.dart';
import 'adw_switch.dart';

/// A preference row with an integrated [AdwSwitch] (`AdwSwitchRow`).
///
/// Toggles the boolean [value] either by interacting directly with the switch
/// or activating anywhere on the row body.
///
/// ```dart
/// AdwSwitchRow(
///   title: const Text('Dark Style'),
///   subtitle: const Text('Use the dark appearance across the app'),
///   value: isDark,
///   onChanged: (enabled) {},
/// )
/// ```
///
/// See also:
///
/// * [AdwSwitch], the standalone toggle control.
/// * [AdwActionRow], the underlying row layout.
///
/// {@category Controls}
class AdwSwitchRow extends StatelessWidget {
  /// Alias for [prefix] placed at the start of the row.
  final Widget? leading;

  /// Optional leading widget placed before [title].
  final Widget? prefix;

  /// Primary label widget for the row.
  final Widget title;

  /// Optional secondary description displayed below [title].
  final Widget? subtitle;

  /// Current boolean state of the switch.
  final bool value;

  /// Called when the row or switch is toggled. When `null`, the row is disabled.
  final ValueChanged<bool>? onChanged;

  /// Creates a Libadwaita switch preference row.
  const AdwSwitchRow({
    super.key,
    this.leading,
    this.prefix,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: AdwActionRow(
        prefix: prefix ?? leading,
        title: title,
        subtitle: subtitle,
        suffix: ExcludeFocus(
          child: ExcludeSemantics(
            child: AdwSwitch(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ),
        onPressed: onChanged != null ? () => onChanged!(!value) : null,
      ),
    );
  }
}

