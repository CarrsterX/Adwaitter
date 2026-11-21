import 'package:flutter/widgets.dart';

import '../../core/adw_insets.dart';
import '../../core/adw_scrollbar.dart';
import '../../theme/adw_theme.dart';

/// A declarative section of items inside an [AdwSidebar], matching GNOME
/// Libadwaita 1.9+'s `AdwSidebarSection`.
class AdwSidebarSection {
  final String? title;
  final List<Widget> items;

  const AdwSidebarSection({
    this.title,
    required this.items,
  });
}

/// Declarative navigation sidebar container matching GNOME Libadwaita 1.9+'s
/// `AdwSidebar`.
///
/// Renders grouped [sections] with optional section headers, subtle dividers
/// between sections, and an integrated [AdwScrollbar].
class AdwSidebar extends StatefulWidget {
  final List<AdwSidebarSection> sections;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;

  const AdwSidebar({
    super.key,
    required this.sections,
    this.controller,
    this.padding = const EdgeInsets.symmetric(vertical: 6.0),
  });

  @override
  State<AdwSidebar> createState() => _AdwSidebarState();
}

class _AdwSidebarState extends State<AdwSidebar> {
  ScrollController? _internalController;

  ScrollController get _controller =>
      widget.controller ?? (_internalController ??= ScrollController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final bottomInset = adwBottomSystemInset(context);
    final resolvedPadding = widget.padding
        .resolve(Directionality.of(context))
        .add(EdgeInsets.only(bottom: bottomInset));

    final children = <Widget>[];
    for (int i = 0; i < widget.sections.length; i++) {
      final section = widget.sections[i];
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
            child: Container(
              height: 1.0,
              color: theme.colors.dividerColor,
            ),
          ),
        );
      }
      if (section.title != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(18.0, 8.0, 18.0, 4.0),
            child: Text(
              section.title!,
              style: theme.typography.sectionTitle.copyWith(
                color: theme.colors.secondaryForeground,
              ),
            ),
          ),
        );
      }
      children.addAll(section.items);
    }

    return AdwScrollbar(
      axisDirection: AxisDirection.down,
      controller: _controller,
      child: ListView(
        controller: _controller,
        padding: resolvedPadding,
        children: children,
      ),
    );
  }
}
