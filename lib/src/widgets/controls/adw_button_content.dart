import 'package:flutter/widgets.dart';

/// Helper widget for laying out an [icon] and [label] inside an [AdwButton],
/// matching GNOME Libadwaita's `AdwButtonContent`.
///
/// ```dart
/// AdwButton(
///   onPressed: () {},
///   child: const AdwButtonContent(
///     icon: Icon(AdwIcons.document_save_symbolic, size: 16),
///     label: 'Save',
///   ),
/// )
/// ```
///
/// See also:
///
/// * [AdwButton], the button widget that hosts [AdwButtonContent].
///
/// {@category Controls}
class AdwButtonContent extends StatelessWidget {
  /// Optional leading icon widget.
  final Widget? icon;

  /// Text label displayed next to [icon].
  final String label;

  /// Horizontal gap between [icon] and [label]. Defaults to `6.0`.
  final double spacing;

  /// Creates an icon-and-label layout for [AdwButton].
  const AdwButtonContent({
    super.key,
    this.icon,
    required this.label,
    this.spacing = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          icon!,
          SizedBox(width: spacing),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
