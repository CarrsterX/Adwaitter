import 'package:flutter/widgets.dart';

/// Helper widget for laying out an icon and label inside an [AdwButton],
/// matching GNOME Libadwaita's `AdwButtonContent`.
class AdwButtonContent extends StatelessWidget {
  final Widget? icon;
  final String label;
  final double spacing;

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
