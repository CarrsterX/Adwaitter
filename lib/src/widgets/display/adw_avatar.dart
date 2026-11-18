import 'package:flutter/widgets.dart';

/// A user avatar widget with generated initials and fallback (`AdwAvatar`).
class AdwAvatar extends StatelessWidget {
  const AdwAvatar({
    super.key,
    required this.size,
    this.text,
    this.showInitials = false,
    this.customImage,
  });

  final double size;
  final String? text;
  final bool showInitials;
  final ImageProvider? customImage;

  static const _palette = [
    Color(0xFF62A0EA),
    Color(0xFF57E389),
    Color(0xFFF5C211),
    Color(0xFFFFA348),
    Color(0xFFED333B),
    Color(0xFFC061CB),
    Color(0xFF9141AC),
    Color(0xFF3584E4),
    Color(0xFF33D17A),
    Color(0xFFE5A50A),
    Color(0xFFFF7800),
    Color(0xFFE01B24),
    Color(0xFFB5835A),
    Color(0xFF77767B),
  ];

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
        ? const Color(0xFF8E8E93)
        : _palette[_glibStrHash(trimmed) % _palette.length];
    final topColor = (trimmed.isEmpty && customImage == null)
        ? const Color(0xFFD4D4D8)
        : Color.lerp(baseColor, const Color(0xFFFFFFFF), 0.22)!;
    final bottomColor = (trimmed.isEmpty && customImage == null)
        ? const Color(0xFF5E5E64)
        : Color.lerp(baseColor, const Color(0xFF000000), 0.22)!;

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
                        const Color(0xFFFFFFFF),
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
                      const Color(0xFFFFFFFF),
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
