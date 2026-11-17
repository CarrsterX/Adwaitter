import 'package:flutter/widgets.dart';

/// Bottom system inset (navigation bar / gesture pill) for the current
/// [MediaQuery], robust to ancestors that consumed `padding` but kept
/// `viewPadding` (and vice-versa). Excludes the virtual keyboard.
double adwBottomSystemInset(BuildContext context) {
  final data = MediaQuery.maybeOf(context);
  if (data == null) return 0.0;
  final double inset = data.padding.bottom > data.viewPadding.bottom
      ? data.padding.bottom
      : data.viewPadding.bottom;
  final double keyboard = data.viewInsets.bottom;
  // When the keyboard is open it already covers the navbar area.
  return keyboard > 0.0 ? 0.0 : inset;
}

/// Marks the bottom system inset as consumed (padding and viewPadding) so
/// descendants such as  do not reserve it again.
class AdwBottomInsetConsumer extends StatelessWidget {
  final Widget child;

  const AdwBottomInsetConsumer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.maybeOf(context);
    if (data == null ||
        (data.padding.bottom == 0.0 && data.viewPadding.bottom == 0.0)) {
      return child;
    }
    return MediaQuery(
      data: data.copyWith(
        padding: data.padding.copyWith(bottom: 0.0),
        viewPadding: data.viewPadding.copyWith(bottom: 0.0),
      ),
      child: child,
    );
  }
}
