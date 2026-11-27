import 'package:flutter/widgets.dart';

import '../../theme/adw_colors.dart';

/// A circular user or entity avatar matching GNOME Libadwaita's `AdwAvatar`.
///
/// Displays a [customImage] when provided, or falls back to a deterministic
/// gradient from [AdwColors.avatarPalette] (hashed from [text]) with optional
/// initials when [showInitials] is `true`, or a neutral person silhouette when
/// [text] is empty.
///
/// ```dart
/// const AdwAvatar(
///   size: 64,
///   text: 'Ada Lovelace',
///   showInitials: true,
/// )
/// ```
///
/// See also:
///
/// * [AdwColors.avatarPalette], the 14-color palette used for generated avatars.
///
/// {@category Display}
class AdwAvatar extends StatelessWidget {
  /// Creates a circular Libadwaita avatar with the given [size].
  const AdwAvatar({
    super.key,
    required this.size,
    this.text,
    this.showInitials = false,
    this.customImage,
  });

  /// Diameter of the circular avatar in logical pixels.
  final double size;

  /// Optional display name used to pick a deterministic background color and
  /// derive initials when [showInitials] is `true`.
  final String? text;

  /// Whether to render up to two uppercase initials extracted from [text]
  /// when [customImage] is `null`. Defaults to `false`.
  final bool showInitials;

  /// Optional image displayed inside the circular avatar frame.
  final ImageProvider? customImage;

  static const _palette = AdwColors.avatarPalette;

  String _extractInitials(String raw) {
    final parts =
        raw.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  int _glibStrHash(String s) {
    var h = 5381;
    for (final codeUnit in s.codeUnits) {
      h = ((h << 5) + h + codeUnit) & 0xFFFFFFFF;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = text?.trim() ?? '';
    final initials = showInitials ? _extractInitials(trimmed) : '';
    final baseColor = (trimmed.isEmpty && customImage == null)
        ? AdwColors.avatarFallbackBase
        : _palette[_glibStrHash(trimmed) % _palette.length];
    final topColor = (trimmed.isEmpty && customImage == null)
        ? AdwColors.avatarFallbackTop
        : Color.lerp(baseColor, AdwColors.light1, 0.22)!;
    final bottomColor = (trimmed.isEmpty && customImage == null)
        ? AdwColors.avatarFallbackBottom
        : Color.lerp(baseColor, AdwColors.dark5, 0.22)!;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ),
        image: customImage != null
            ? DecorationImage(image: customImage!, fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: customImage != null
          ? null
          : initials.isNotEmpty
              ? Center(
                  child: Text(
                    initials,
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                    style: TextStyle(
                      color: Color.lerp(
                        AdwColors.light1,
                        baseColor,
                        0.18,
                      ),
                      fontSize: size * 0.32,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                )
              : CustomPaint(
                  size: Size.square(size * 0.48),
                  painter: _AvatarFallbackPainter(
                    color: Color.lerp(
                      AdwColors.light1,
                      baseColor,
                      0.18,
                    )!,
                  ),
                ),
    );
  }
}

class _AvatarFallbackPainter extends CustomPainter {
  const _AvatarFallbackPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 16.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Exact official Libadwaita avatar-default-symbolic SVG (16x16):
    // Head: circle at (8, 5) radius 4
    canvas.drawCircle(Offset(8.0 * u, 5.0 * u), 4.0 * u, paint);

    // Shoulders: M 1 15 A 4 4 0 0 1 5 11 L 11 11 A 4 4 0 0 1 15 15
    final body = Path()
      ..moveTo(1.0 * u, 15.0 * u)
      ..arcToPoint(
        Offset(5.0 * u, 11.0 * u),
        radius: Radius.circular(4.0 * u),
      )
      ..lineTo(11.0 * u, 11.0 * u)
      ..arcToPoint(
        Offset(15.0 * u, 15.0 * u),
        radius: Radius.circular(4.0 * u),
      );
    canvas.drawPath(body, paint);
  }

  @override
  bool shouldRepaint(_AvatarFallbackPainter oldDelegate) =>
      oldDelegate.color != color;
}
