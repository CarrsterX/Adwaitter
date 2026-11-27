import 'package:flutter/widgets.dart';

import '../../theme/adw_theme.dart';

/// Official Libadwaita window title widget (`AdwWindowTitle`).
///
/// Centers a primary window [title] and an optional [subtitle] with official
/// Libadwaita typography and subtle secondary text styling.
///
/// ```dart
/// const AdwWindowTitle(
///   title: 'Settings',
///   subtitle: 'Appearance',
/// )
/// ```
///
/// See also:
///
/// * [AdwHeaderBar], which typically displays [AdwWindowTitle] in `titleWidget`.
///
/// {@category Layout}
class AdwWindowTitle extends StatelessWidget {
  /// Primary title text displayed in bold heading typography.
  final String title;

  /// Optional muted secondary line displayed below [title].
  final String? subtitle;

  /// Creates a centered Libadwaita header bar title widget.
  const AdwWindowTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: theme.typography.heading,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1.0),
            child: Text(
              subtitle!,
              style: theme.typography.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

