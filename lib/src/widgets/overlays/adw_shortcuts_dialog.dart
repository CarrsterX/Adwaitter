import 'package:flutter/widgets.dart';

import '../../core/adw_text_selection.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../containers/adw_preferences_group.dart';
import '../containers/adw_preferences_page.dart';
import '../containers/adw_status_page.dart';
import '../layout/adw_clamp.dart';
import '../layout/adw_header_bar.dart';
import '../layout/adw_toolbar_view.dart';
import 'adw_dialog.dart';

/// A single keyboard shortcut item inside an [AdwShortcutsSection].
///
/// Mirrors Libadwaita's `AdwShortcutsItem`.
@immutable
class AdwShortcutsItem {
  /// Creates an [AdwShortcutsItem].
  const AdwShortcutsItem({
    required this.title,
    required this.accelerator,
    this.subtitle,
    this.direction,
  });

  /// The human-readable title of the shortcut action.
  final String title;

  /// Optional subtitle providing further details on the shortcut.
  final String? subtitle;

  /// The GTK-style accelerator string, e.g. `'<Control>comma'`,
  /// `'<Shift><Ctrl>Tab <Ctrl>Page_Up'`, or `'<Alt>1...9'`.
  final String accelerator;

  /// Optional text direction constraint (`TextDirection.ltr` or
  /// `TextDirection.rtl`). When non-null, the item is only shown if the ambient
  /// [Directionality] matches [direction].
  final TextDirection? direction;
}

/// A section of shortcut items inside an [AdwShortcutsDialog].
///
/// Mirrors Libadwaita's `AdwShortcutsSection`. When [title] is `null`, the
/// section renders as an untitled sub-group beneath the preceding titled
/// section (matching `AdwShortcutsSection` without a `title` property in
/// Libadwaita).
@immutable
class AdwShortcutsSection {
  /// Creates an [AdwShortcutsSection].
  const AdwShortcutsSection({
    required this.items,
    this.title,
  });

  /// Optional section header title.
  final String? title;

  /// The shortcut items belonging to this section.
  final List<AdwShortcutsItem> items;
}

/// Displays a keyboard accelerator as a row of styled keycaps.
///
/// Mirrors Libadwaita's `AdwShortcutLabel` (`.shortcut-label` / `.keycap`).
/// Supports:
/// - Standard GTK modifier syntax (`<Control>`, `<Ctrl>`, `<Shift>`, `<Alt>`,
///   `<Super>`, `<Meta>`, `<Primary>`).
/// - Space-separated alternative accelerators (e.g.
///   `'<Shift><Ctrl>Tab <Ctrl>Page_Up'`), separated by `/`.
/// - Ranges (`'<Alt>1...9'`).
class AdwShortcutLabel extends StatelessWidget {
  /// Creates an [AdwShortcutLabel].
  const AdwShortcutLabel({
    required this.accelerator,
    this.disabledText,
    super.key,
  });

  /// The GTK-style accelerator string to parse and render.
  final String accelerator;

  /// Fallback text shown when [accelerator] is empty.
  final String? disabledText;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final trimmed = accelerator.trim();
    if (trimmed.isEmpty) {
      if (disabledText == null || disabledText!.isEmpty) {
        return const SizedBox.shrink();
      }
      return Text(
        disabledText!,
        style: theme.typography.body.copyWith(
          color: theme.colors.foreground.withValues(alpha: 0.55),
        ),
      );
    }

    final alternatives =
        trimmed.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

    final children = <Widget>[];
    for (var i = 0; i < alternatives.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '/',
              style: theme.typography.body.copyWith(
                color: theme.colors.foreground.withValues(alpha: 0.55),
              ),
            ),
          ),
        );
      }
      final tokens = _parseSingleAccelerator(alternatives[i]);
      for (var j = 0; j < tokens.length; j++) {
        if (j > 0) {
          children.add(const SizedBox(width: 6));
        }
        final token = tokens[j];
        if (token.isSeparator) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                token.label,
                style: theme.typography.body.copyWith(
                  color: theme.colors.foreground.withValues(alpha: 0.55),
                ),
              ),
            ),
          );
        } else {
          children.add(_Keycap(label: token.label));
        }
      }
    }

    return Wrap(
      spacing: 0,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.end,
      children: children,
    );
  }

  static List<_AccelToken> _parseSingleAccelerator(String raw) {
    final tokens = <_AccelToken>[];
    var rest = raw;

    final modRegex = RegExp('^<([^>]+)>');
    while (true) {
      final match = modRegex.firstMatch(rest);
      if (match == null) break;
      final modName = match.group(1)!;
      tokens.add(_AccelToken.keycap(_formatModifier(modName)));
      rest = rest.substring(match.end);
    }

    if (rest.isNotEmpty) {
      if (rest.contains('...')) {
        final parts = rest.split('...');
        for (var i = 0; i < parts.length; i++) {
          if (i > 0) {
            tokens.add(const _AccelToken.separator('…'));
          }
          if (parts[i].isNotEmpty) {
            tokens.add(_AccelToken.keycap(_formatKey(parts[i])));
          }
        }
      } else {
        tokens.add(_AccelToken.keycap(_formatKey(rest)));
      }
    }

    return tokens;
  }

  static String _formatModifier(String mod) {
    switch (mod.toLowerCase()) {
      case 'control':
      case 'ctrl':
      case 'primary':
        return 'Ctrl';
      case 'shift':
      case 'shft':
        return 'Shift';
      case 'alt':
      case 'mod1':
        return 'Alt';
      case 'super':
      case 'mod4':
        return 'Super';
      case 'meta':
        return 'Meta';
      case 'hyper':
        return 'Hyper';
      default:
        return mod;
    }
  }

  static String _formatKey(String key) {
    switch (key) {
      case 'comma':
        return ',';
      case 'period':
        return '.';
      case 'slash':
        return '/';
      case 'question':
        return '?';
      case 'plus':
        return '+';
      case 'minus':
        return '-';
      case 'equal':
        return '=';
      case 'BackSpace':
        return 'Backspace';
      case 'Return':
      case 'KP_Enter':
        return 'Enter';
      case 'Escape':
        return 'Esc';
      case 'Page_Up':
        return 'Page Up';
      case 'Page_Down':
        return 'Page Down';
      case 'Up':
        return '↑';
      case 'Down':
        return '↓';
      case 'Left':
        return '←';
      case 'Right':
        return '→';
      case 'space':
        return 'Space';
      default:
        if (key.length == 1) {
          return key.toUpperCase();
        }
        return key.replaceAll('_', ' ');
    }
  }

  /// Converts an [accelerator] into searchable plain-text keywords so users
  /// can search by key names like `"ctrl"`, `"page up"`, `"f10"`, or `"?"`.
  static String searchableText(String accelerator) {
    final trimmed = accelerator.trim();
    if (trimmed.isEmpty) return '';
    final buffer = StringBuffer();
    for (final alt in trimmed.split(RegExp(r'\s+'))) {
      for (final token in _parseSingleAccelerator(alt)) {
        buffer
          ..write(token.label)
          ..write(' ');
      }
    }
    return buffer.toString().toLowerCase();
  }
}

class _AccelToken {
  const _AccelToken.keycap(this.label) : isSeparator = false;
  const _AccelToken.separator(this.label) : isSeparator = true;

  final String label;
  final bool isSeparator;
}

class _Keycap extends StatelessWidget {
  const _Keycap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final isDark = theme.colors.isDark;
    // Matches Libadwaita _shortcuts-dialog.scss `.keycap`:
    // background: color-mix(in srgb, currentColor 10%, transparent);
    // box-shadow: inset 0 -2px var(--card-shade-color);
    // border-radius: 6px; padding: 4px 6px; min-width: 20px (total ~32px).
    final bgColor = theme.colors.foreground.withValues(alpha: 0.10);
    final shadeColor =
        isDark ? const Color(0x52000000) : const Color(0x1F000000);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(6)),
            border: Border(
              bottom: BorderSide(color: shadeColor, width: 2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 7,
              right: 7,
              top: 4,
              bottom: 6,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.typography.caption.copyWith(
                  color: theme.colors.foreground,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1.15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dialog that displays application keyboard shortcuts grouped by section
/// with live search filtering.
///
/// Mirrors Libadwaita 1.8's `AdwShortcutsDialog`.
class AdwShortcutsDialog extends StatefulWidget {
  /// Creates an [AdwShortcutsDialog].
  const AdwShortcutsDialog({
    required this.sections,
    this.title = 'Keyboard Shortcuts',
    this.searchPlaceholder = 'Search shortcuts',
    this.emptyTitle = 'No Results Found',
    this.emptyDescription = 'Try a different search',
    super.key,
  });

  /// The shortcut sections to display.
  final List<AdwShortcutsSection> sections;

  /// Accessible dialog title (defaults to `'Keyboard Shortcuts'`).
  final String title;

  /// Placeholder text shown inside the header bar search entry.
  final String searchPlaceholder;

  /// Title shown when a search query produces no results.
  final String emptyTitle;

  /// Description shown when a search query produces no results.
  final String emptyDescription;

  @override
  State<AdwShortcutsDialog> createState() => _AdwShortcutsDialogState();
}

class _AdwShortcutsDialogState extends State<AdwShortcutsDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchFocused = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() => _searchFocused = _searchFocusNode.hasFocus);
    }
  }

  void _onSearchChanged() {
    final next = _searchController.text;
    if (next != _query) {
      setState(() => _query = next);
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _searchFocusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  bool _itemVisibleForDirection(AdwShortcutsItem item, TextDirection dir) {
    return item.direction == null || item.direction == dir;
  }

  bool _itemMatchesQuery(AdwShortcutsItem item, List<String> terms) {
    final titleLower = item.title.toLowerCase();
    final subtitleLower = item.subtitle?.toLowerCase() ?? '';
    final accelLower = AdwShortcutLabel.searchableText(item.accelerator);
    final rawAccelLower = item.accelerator.toLowerCase();

    for (final term in terms) {
      final matches = titleLower.contains(term) ||
          subtitleLower.contains(term) ||
          accelLower.contains(term) ||
          rawAccelLower.contains(term);
      if (!matches) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final textDirection = Directionality.of(context);
    final trimmedQuery = _query.trim().toLowerCase();
    final isSearching = trimmedQuery.isNotEmpty;

    Widget content;
    if (!isSearching) {
      final groups = <Widget>[];
      var previousHadTitle = false;
      for (final section in widget.sections) {
        final visibleItems = section.items
            .where((item) => _itemVisibleForDirection(item, textDirection))
            .toList();
        if (visibleItems.isEmpty) continue;

        final hasTitle = section.title != null && section.title!.isNotEmpty;
        final group = AdwPreferencesGroup(
          title: hasTitle ? Text(section.title!) : null,
          children: [
            for (final item in visibleItems) _AdwShortcutRow(item: item),
          ],
        );

        // In Libadwaita, untitled AdwShortcutsSections sit below the preceding
        // group with a tighter 12px gap instead of the full 18px section gap.
        if (!hasTitle && previousHadTitle && groups.isNotEmpty) {
          groups.add(
            Transform.translate(
              offset: const Offset(0, -6),
              child: group,
            ),
          );
        } else {
          groups.add(group);
        }
        previousHadTitle = true;
      }

      content = AdwPreferencesPage(
        groupSpacing: 18,
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: groups,
      );
    } else {
      final terms = trimmedQuery
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();
      final matchingItems = <AdwShortcutsItem>[];
      for (final section in widget.sections) {
        for (final item in section.items) {
          if (!_itemVisibleForDirection(item, textDirection)) continue;
          if (_itemMatchesQuery(item, terms)) {
            matchingItems.add(item);
          }
        }
      }

      if (matchingItems.isEmpty) {
        content = AdwStatusPage(
          icon: CustomPaint(
            size: const Size(96, 96),
            painter: _SearchIconPainter(
              color: theme.colors.foreground.withValues(alpha: 0.45),
              strokeWidth: 6.5,
            ),
          ),
          title: Text(widget.emptyTitle),
          description: Text(widget.emptyDescription),
        );
      } else {
        content = AdwPreferencesPage(
          groupSpacing: 18,
          padding: const EdgeInsets.symmetric(vertical: 24),
          children: [
            AdwPreferencesGroup(
              children: [
                for (final item in matchingItems) _AdwShortcutRow(item: item),
              ],
            ),
          ],
        );
      }
    }

    return AdwDialog(
      title: widget.title,
      contentWidth: 600,
      contentHeight: 900,
      child: AdwToolbarView(
        topBar: AdwHeaderBar(
          isFlat: true,
          showBackButton: false,
          titleWidget: AdwClamp(
            maximumSize: 340,
            minimumMargin: 0,
            child: TapRegion(
              onTapOutside: (_) {
                if (_searchFocusNode.hasFocus) {
                  _searchFocusNode.unfocus();
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _searchFocusNode.requestFocus,
              child: AnimatedContainer(
                duration: AdwCurves.shortDuration,
                curve: AdwCurves.standard,
                height: 34,
                padding: EdgeInsets.symmetric(
                  horizontal: _searchFocused ? 9.0 : 10.0,
                ),
                decoration: BoxDecoration(
                  color: theme.colors.isDark
                      ? const Color(0xFF3E3E42)
                      : const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(AdwMetrics.buttonRadius),
                  border: Border.all(
                    color: _searchFocused
                        ? theme.colors.accentColor.withValues(alpha: 0.75)
                        : theme.colors.borderColor,
                    width: _searchFocused ? 2.0 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    CustomPaint(
                      size: const Size(15, 15),
                      painter: _SearchIconPainter(
                        color: theme.colors.secondaryForeground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          if (_searchController.text.isEmpty)
                            IgnorePointer(
                              child: Text(
                                widget.searchPlaceholder,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.body.copyWith(
                                  height: 1,
                                  leadingDistribution:
                                      TextLeadingDistribution.even,
                                  color: theme.colors.secondaryForeground
                                      .withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          AdwEditableText(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onTapOutside: (_) => _searchFocusNode.unfocus(),
                            style: theme.typography.body.copyWith(
                              height: 1,
                              leadingDistribution: TextLeadingDistribution.even,
                              color: theme.colors.windowForeground,
                            ),
                            cursorColor: theme.colors.windowForeground,
                            backgroundCursorColor: theme.colors.borderColor,
                            selectionColor: theme.colors.accentColor.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_searchController.text.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _searchController.clear,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: CustomPaint(
                            size: const Size(15, 15),
                            painter: _ClearIconPainter(
                              color: theme.colors.secondaryForeground,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
        content: content,
      ),
    );
  }
}

class _AdwShortcutRow extends StatelessWidget {
  const _AdwShortcutRow({required this.item});

  final AdwShortcutsItem item;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final hasSubtitle = item.subtitle != null && item.subtitle!.isNotEmpty;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.typography.body.copyWith(
                      color: theme.colors.foreground,
                    ),
                  ),
                  if (hasSubtitle) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: theme.typography.caption.copyWith(
                        color: theme.colors.foreground.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            AdwShortcutLabel(accelerator: item.accelerator),
          ],
        ),
      ),
    );
  }
}

class _SearchIconPainter extends CustomPainter {
  const _SearchIconPainter({
    required this.color,
    this.strokeWidth = 1.6,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final radius = size.width * 0.34;
    final center = Offset(
      radius + strokeWidth * 0.6,
      radius + strokeWidth * 0.6,
    );
    canvas.drawCircle(center, radius, paint);

    final handleStart = Offset(
      center.dx + radius * 0.72,
      center.dy + radius * 0.72,
    );
    final handleEnd = Offset(
      size.width - strokeWidth * 0.6,
      size.height - strokeWidth * 0.6,
    );
    canvas.drawLine(handleStart, handleEnd, paint);
  }

  @override
  bool shouldRepaint(covariant _SearchIconPainter oldDelegate) {
    return color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
  }
}

class _ClearIconPainter extends CustomPainter {
  const _ClearIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width * 0.44, fillPaint);

    final crossPaint = Paint()
      ..color = const Color(0x00000000)
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawCircle(center, size.width * 0.44, fillPaint);
    final r = size.width * 0.16;
    canvas.drawLine(
      Offset(center.dx - r, center.dy - r),
      Offset(center.dx + r, center.dy + r),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx + r, center.dy - r),
      Offset(center.dx - r, center.dy + r),
      crossPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ClearIconPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

/// Displays an [AdwShortcutsDialog] as a modal overlay.
Future<T?> showAdwShortcutsDialog<T>({
  required BuildContext context,
  required List<AdwShortcutsSection> sections,
  String title = 'Keyboard Shortcuts',
  String searchPlaceholder = 'Search shortcuts',
}) {
  return showAdwDialog<T>(
    context: context,
    builder: (dialogContext) => AdwShortcutsDialog(
      sections: sections,
      title: title,
      searchPlaceholder: searchPlaceholder,
    ),
  );
}
