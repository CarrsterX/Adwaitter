import 'package:flutter/widgets.dart';

/// Structured toolbar and content layout container (`AdwToolbarView`).
///
/// Coordinates top bars (such as [AdwHeaderBar]), central scrollable content,
/// and optional bottom action bars in alignment with the Libadwaita 1.4+ architecture.
class AdwToolbarView extends StatelessWidget {
  final Widget? topBar;
  final Widget content;
  final Widget? bottomBar;

  const AdwToolbarView({
    super.key,
    this.topBar,
    required this.content,
    this.bottomBar,
  });

  @override
  Widget build(BuildContext context) {
    // Paint topBar last (VerticalDirection.up) so raised headerbar shadows
    // cast cleanly onto the content area below it.
    return Column(
      verticalDirection: VerticalDirection.up,
      children: [
        if (bottomBar != null) bottomBar!,
        Expanded(child: content),
        if (topBar != null) topBar!,
      ],
    );
  }
}

