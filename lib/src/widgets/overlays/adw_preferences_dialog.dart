import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/adw_text_selection.dart';
import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../containers/adw_action_row.dart';
import '../containers/adw_expander_row.dart';
import '../containers/adw_preferences_group.dart';
import '../containers/adw_preferences_page.dart';
import '../containers/adw_status_page.dart';
import '../controls/adw_button.dart';
import '../controls/adw_button_row.dart';
import '../controls/adw_combo_row.dart';
import '../controls/adw_entry_row.dart';
import '../controls/adw_spin_row.dart';
import '../controls/adw_switch_row.dart';
import '../layout/adw_clamp.dart';
import '../layout/adw_header_bar.dart';
import '../layout/adw_toolbar_view.dart';
import '../layout/adw_window_title.dart';
import '../navigation/adw_navigation_view.dart';
import '../navigation/adw_view_switcher.dart';
import 'adw_dialog.dart';
import 'adw_toast.dart';

/// Descriptor for a page inside an [AdwPreferencesDialog].
@immutable
class AdwPreferencesDialogPage {
  /// Creates an [AdwPreferencesDialogPage].
  const AdwPreferencesDialogPage({
    required this.title,
    this.icon,
    this.description,
    this.banner,
    required this.children,
    this.padding,
    this.maxWidth = AdwMetrics.preferencesPageMaxWidth,
    this.groupSpacing = AdwMetrics.preferencesGroupSpacing,
  });

  /// Tab / page title shown in the view switcher and search breadcrumbs.
  final String title;

  /// Optional icon shown in the [AdwViewSwitcher] / [AdwViewSwitcherBar].
  final Widget? icon;

  /// Optional description displayed at the top of the preferences page.
  final Widget? description;

  /// Optional [AdwBanner] displayed above the scrollable page content.
  final Widget? banner;

  /// Preference groups and widgets rendered inside [AdwPreferencesPage].
  final List<Widget> children;

  /// Optional scroll padding override.
  final EdgeInsetsGeometry? padding;

  /// Maximum content width passed to [AdwPreferencesPage].
  final double maxWidth;

  /// Spacing between groups passed to [AdwPreferencesPage].
  final double groupSpacing;
}

/// Inherited scope exposed inside an [AdwPreferencesDialog] so child rows and
/// buttons can push/pop subpages, switch pages, or display toasts.
class AdwPreferencesDialogScope extends InheritedWidget {
  /// Pushes a navigation subpage onto the dialog's [AdwNavigationView].
  final void Function(AdwNavigationPage page) pushSubpage;

  /// Pops the top subpage from the dialog's [AdwNavigationView].
  final void Function() popSubpage;

  /// Displays an [AdwToast] inside the dialog's [AdwToastOverlay].
  final void Function(AdwToast toast) addToast;

  /// Switches the active preferences page by index.
  final void Function(int index) setPageIndex;

  const AdwPreferencesDialogScope({
    super.key,
    required this.pushSubpage,
    required this.popSubpage,
    required this.addToast,
    required this.setPageIndex,
    required super.child,
  });

  static AdwPreferencesDialogScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdwPreferencesDialogScope>();
  }

  static AdwPreferencesDialogScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(
      scope != null,
      'No AdwPreferencesDialogScope found in context. '
      'Call from inside an AdwPreferencesDialog.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant AdwPreferencesDialogScope oldWidget) {
    return pushSubpage != oldWidget.pushSubpage ||
        popSubpage != oldWidget.popSubpage ||
        addToast != oldWidget.addToast ||
        setPageIndex != oldWidget.setPageIndex;
  }
}

/// Adaptive preferences dialog (`AdwPreferencesDialog`) matching Libadwaita 1.5+.
///
/// Organizes [pages] with an adaptive [AdwViewSwitcher] / [AdwViewSwitcherBar],
/// built-in live search across groups and rows (`Ctrl+F`), an internal
/// [AdwToastOverlay], and subpage navigation via [AdwNavigationView].
class AdwPreferencesDialog extends StatefulWidget {
  /// Creates an [AdwPreferencesDialog].
  const AdwPreferencesDialog({
    super.key,
    this.title = 'Preferences',
    this.contentWidth = 640.0,
    this.contentHeight = 700.0,
    this.searchEnabled = true,
    this.searchPlaceholder = 'Search preferences',
    this.emptyTitle = 'No Results Found',
    this.emptyDescription = 'Try a different search',
    this.initialPageIndex = 0,
    required this.pages,
  });

  /// Dialog title shown when only one page exists or on narrow viewports.
  final String title;

  /// Preferred dialog width (defaults to `640.0`).
  final double contentWidth;

  /// Preferred dialog height (clamped to window bounds by [AdwDialog]).
  final double contentHeight;

  /// Whether the search button and `Ctrl+F` shortcut are enabled.
  final bool searchEnabled;

  /// Placeholder text in the search entry.
  final String searchPlaceholder;

  /// Title shown when search yields no matching rows.
  final String emptyTitle;

  /// Description shown when search yields no matching rows.
  final String emptyDescription;

  /// Initial selected page index.
  final int initialPageIndex;

  /// Preferences pages displayed in the dialog.
  final List<AdwPreferencesDialogPage> pages;

  @override
  State<AdwPreferencesDialog> createState() => _AdwPreferencesDialogState();
}

class _AdwPreferencesDialogState extends State<AdwPreferencesDialog> {
  final AdwNavigationViewController _navController =
      AdwNavigationViewController();
  final GlobalKey _toastHostKey = GlobalKey();
  final GlobalKey<_PreferencesMainPageState> _mainPageKey = GlobalKey();

  @override
  void dispose() {
    _navController.dispose();
    super.dispose();
  }

  void _pushSubpage(AdwNavigationPage page) {
    _navController.push(page);
  }

  void _popSubpage() {
    _navController.pop();
  }

  void _addToast(AdwToast toast) {
    final ctx = _toastHostKey.currentContext;
    if (ctx != null) {
      AdwToastOverlay.maybeOf(ctx)?.addToast(toast);
    }
  }

  void _setPageIndex(int index) {
    _mainPageKey.currentState?.setPageIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return AdwDialog(
      title: widget.title,
      contentWidth: widget.contentWidth,
      contentHeight: widget.contentHeight,
      child: AdwToastOverlay(
        child: Builder(
          key: _toastHostKey,
          builder: (toastContext) => AdwPreferencesDialogScope(
            pushSubpage: _pushSubpage,
            popSubpage: _popSubpage,
            addToast: _addToast,
            setPageIndex: _setPageIndex,
            child: AdwNavigationView(
              controller: _navController,
              initialPage: AdwNavigationPage(
                title: widget.title,
                canPop: false,
                child: _PreferencesMainPage(
                  key: _mainPageKey,
                  dialogWidget: widget,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferencesMainPage extends StatefulWidget {
  const _PreferencesMainPage({
    super.key,
    required this.dialogWidget,
  });

  final AdwPreferencesDialog dialogWidget;

  @override
  State<_PreferencesMainPage> createState() => _PreferencesMainPageState();
}

class _PreferencesMainPageState extends State<_PreferencesMainPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late int _currentIndex;
  bool _isSearching = false;
  bool _searchFocused = false;
  String _query = '';

  AdwPreferencesDialog get _dialog => widget.dialogWidget;

  @override
  void initState() {
    super.initState();
    _currentIndex = _dialog.pages.isEmpty
        ? 0
        : _dialog.initialPageIndex.clamp(0, _dialog.pages.length - 1);
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _searchFocusNode
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _searchController.text;
    if (next != _query) {
      setState(() => _query = next);
    }
  }

  void _onSearchFocusChanged() {
    if (mounted) {
      setState(() => _searchFocused = _searchFocusNode.hasFocus);
    }
  }

  void _toggleSearch([bool? active]) {
    if (!_dialog.searchEnabled) return;
    final next = active ?? !_isSearching;
    if (next == _isSearching) {
      if (next) {
        _searchFocusNode.requestFocus();
      }
      return;
    }
    setState(() {
      _isSearching = next;
      if (next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isSearching) {
            _searchFocusNode.requestFocus();
          }
        });
      } else {
        _searchFocusNode.unfocus();
        _searchController.clear();
        _query = '';
      }
    });
  }

  void setPageIndex(int index) {
    if (_dialog.pages.isEmpty) return;
    setState(() {
      _currentIndex = index.clamp(0, _dialog.pages.length - 1);
    });
  }

  List<_SearchMatch> _collectSearchMatches(String query) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();

    final matches = <_SearchMatch>[];
    for (var pageIdx = 0; pageIdx < _dialog.pages.length; pageIdx++) {
      final page = _dialog.pages[pageIdx];
      for (final child in page.children) {
        _extractFromWidget(
          widget: child,
          pageIndex: pageIdx,
          pageTitle: page.title,
          groupTitle: null,
          terms: terms,
          out: matches,
        );
      }
    }
    return matches;
  }

  void _extractFromWidget({
    required Widget widget,
    required int pageIndex,
    required String pageTitle,
    required String? groupTitle,
    required List<String> terms,
    required List<_SearchMatch> out,
  }) {
    if (widget is Builder) {
      _extractFromWidget(
        widget: widget.builder(context),
        pageIndex: pageIndex,
        pageTitle: pageTitle,
        groupTitle: groupTitle,
        terms: terms,
        out: out,
      );
      return;
    }

    if (widget is AdwPreferencesGroup) {
      final resolvedGroupTitle = _extractText(widget.title);
      for (final child in widget.children) {
        _extractFromWidget(
          widget: child,
          pageIndex: pageIndex,
          pageTitle: pageTitle,
          groupTitle: resolvedGroupTitle ?? groupTitle,
          terms: terms,
          out: out,
        );
      }
      return;
    }

    String? rowTitle;
    String? rowSubtitle;
    VoidCallback? onActivated;

    if (widget is AdwActionRow) {
      rowTitle = _extractText(widget.title);
      rowSubtitle = _extractText(widget.subtitle);
      onActivated = widget.onPressed;
    } else if (widget is AdwSwitchRow) {
      rowTitle = _extractText(widget.title);
      rowSubtitle = _extractText(widget.subtitle);
    } else if (widget is AdwComboRow) {
      rowTitle = _extractText(widget.title);
      rowSubtitle = _extractText(widget.subtitle);
    } else if (widget is AdwSpinRow) {
      rowTitle = _extractText(widget.title);
      rowSubtitle = _extractText(widget.subtitle);
    } else if (widget is AdwEntryRow) {
      rowTitle = _extractText(widget.title);
    } else if (widget is AdwPasswordEntryRow) {
      rowTitle = _extractText(widget.title);
    } else if (widget is AdwButtonRow) {
      rowTitle = _extractText(widget.title);
      onActivated = widget.onPressed;
    } else if (widget is AdwExpanderRow) {
      rowTitle = _extractText(widget.title);
      rowSubtitle = _extractText(widget.subtitle);
      for (final child in widget.children) {
        _extractFromWidget(
          widget: child,
          pageIndex: pageIndex,
          pageTitle: pageTitle,
          groupTitle: rowTitle ?? groupTitle,
          terms: terms,
          out: out,
        );
      }
    } else if (widget is MultiChildRenderObjectWidget) {
      for (final child in widget.children) {
        _extractFromWidget(
          widget: child,
          pageIndex: pageIndex,
          pageTitle: pageTitle,
          groupTitle: groupTitle,
          terms: terms,
          out: out,
        );
      }
      return;
    } else if (widget is SingleChildRenderObjectWidget &&
        widget.child != null) {
      _extractFromWidget(
        widget: widget.child!,
        pageIndex: pageIndex,
        pageTitle: pageTitle,
        groupTitle: groupTitle,
        terms: terms,
        out: out,
      );
      return;
    }

    if (rowTitle != null && rowTitle.isNotEmpty) {
      final haystack =
          '${rowTitle.toLowerCase()} ${(rowSubtitle ?? '').toLowerCase()} '
          '${(groupTitle ?? '').toLowerCase()} ${pageTitle.toLowerCase()}';
      final allMatch = terms.every(haystack.contains);
      if (allMatch) {
        out.add(
          _SearchMatch(
            title: rowTitle,
            breadcrumb:
                groupTitle != null && groupTitle.isNotEmpty
                    ? '$pageTitle → $groupTitle'
                    : pageTitle,
            pageIndex: pageIndex,
            onActivated: onActivated,
          ),
        );
      }
    }
  }

  static String? _extractText(Widget? widget) {
    if (widget == null) return null;
    if (widget is Text) {
      return widget.data ?? widget.textSpan?.toPlainText();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final switcherItems = [
      for (final page in _dialog.pages)
        AdwViewSwitcherItem(
          icon: page.icon,
          title: page.title,
        ),
    ];

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (_dialog.searchEnabled)
          const SingleActivator(
            LogicalKeyboardKey.keyF,
            control: true,
          ): () => _toggleSearch(true),
        if (_isSearching)
          const SingleActivator(LogicalKeyboardKey.escape):
              () => _toggleSearch(false),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hasMultiplePages = _dialog.pages.length > 1;
            final showHeaderSwitcher = hasMultiplePages && !_isSearching;

            Widget titleWidget;
            if (_isSearching) {
              titleWidget = AdwClamp(
                maximumSize: 400,
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
                      duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
                      curve: AdwCurves.standard,
                      height: 34,
                      padding: EdgeInsets.symmetric(
                        horizontal: _searchFocused ? 9.0 : 10.0,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colors.isDark
                            ? const Color(0xFF3E3E42)
                            : const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(
                          AdwMetrics.buttonRadius,
                        ),
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
                            painter: _PrefSearchIconPainter(
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
                                      _dialog.searchPlaceholder,
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
                                  onTapOutside: (_) =>
                                      _searchFocusNode.unfocus(),
                                  style: theme.typography.body.copyWith(
                                    height: 1,
                                    leadingDistribution:
                                        TextLeadingDistribution.even,
                                    color: theme.colors.windowForeground,
                                  ),
                                  cursorColor: theme.colors.windowForeground,
                                  backgroundCursorColor:
                                      theme.colors.borderColor,
                                  selectionColor: theme.colors.accentColor
                                      .withValues(alpha: 0.35),
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
                                  painter: _PrefClearIconPainter(
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
              );
            } else if (showHeaderSwitcher) {
              titleWidget = FittedBox(
                fit: BoxFit.scaleDown,
                child: AdwViewSwitcher(
                  items: switcherItems,
                  currentIndex: _currentIndex,
                  onIndexChanged: setPageIndex,
                  policy: AdwViewSwitcherPolicy.wide,
                ),
              );
            } else {
              titleWidget = AdwWindowTitle(title: _dialog.title);
            }

            Widget body;
            if (_isSearching) {
              final matches = _collectSearchMatches(_query);
              if (matches.isEmpty) {
                body = AdwStatusPage(
                  icon: CustomPaint(
                    size: const Size(128, 128),
                    painter: _PrefSearchIconPainter(
                      color: theme.colors.foreground.withValues(alpha: 0.45),
                      strokeWidth: 6.5,
                    ),
                  ),
                  title: Text(_dialog.emptyTitle),
                  description: Text(_dialog.emptyDescription),
                );
              } else {
                body = AdwPreferencesPage(
                  children: [
                    AdwPreferencesGroup(
                      children: [
                        for (final m in matches)
                          AdwActionRow(
                            title: Text(m.title),
                            subtitle: Text(m.breadcrumb),
                            onPressed: () {
                              setPageIndex(m.pageIndex);
                              _toggleSearch(false);
                              m.onActivated?.call();
                            },
                          ),
                      ],
                    ),
                  ],
                );
              }
            } else if (_dialog.pages.isEmpty) {
              body = const SizedBox.shrink();
            } else {
              body = IndexedStack(
                index: _currentIndex,
                children: [
                  for (final page in _dialog.pages)
                    AdwPreferencesPage(
                      description: page.description,
                      banner: page.banner,
                      padding: page.padding,
                      maxWidth: page.maxWidth,
                      groupSpacing: page.groupSpacing,
                      children: page.children,
                    ),
                ],
              );
            }

            return AdwToolbarView(
              topBar: AdwHeaderBar(
                isFlat: true,
                showBackButton: false,
                start: _dialog.searchEnabled
                    ? AdwButton(
                        style: _isSearching
                            ? AdwButtonStyle.standard
                            : AdwButtonStyle.flat,
                        width: 34,
                        height: 34,
                        padding: EdgeInsets.zero,
                        onPressed: _toggleSearch,
                        child: CustomPaint(
                          size: const Size(15, 15),
                          painter: _PrefSearchIconPainter(
                            color: theme.colors.foreground,
                          ),
                        ),
                      )
                    : null,
                titleWidget: AnimatedSwitcher(
                  duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
                  child: KeyedSubtree(
                    key: ValueKey('${_isSearching}_$showHeaderSwitcher'),
                    child: titleWidget,
                  ),
                ),
              ),
              content: AnimatedSwitcher(
                duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
                child: KeyedSubtree(
                  key: ValueKey(_isSearching ? 'search' : 'pages'),
                  child: body,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SearchMatch {
  const _SearchMatch({
    required this.title,
    required this.breadcrumb,
    required this.pageIndex,
    this.onActivated,
  });

  final String title;
  final String breadcrumb;
  final int pageIndex;
  final VoidCallback? onActivated;
}

class _PrefSearchIconPainter extends CustomPainter {
  const _PrefSearchIconPainter({
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
  bool shouldRepaint(covariant _PrefSearchIconPainter oldDelegate) {
    return color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
  }
}

class _PrefClearIconPainter extends CustomPainter {
  const _PrefClearIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

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
  bool shouldRepaint(covariant _PrefClearIconPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

/// Displays an [AdwPreferencesDialog] as a modal overlay.
Future<T?> showAdwPreferencesDialog<T>({
  required BuildContext context,
  required List<AdwPreferencesDialogPage> pages,
  String title = 'Preferences',
  double contentWidth = 640.0,
  double contentHeight = 700.0,
  bool searchEnabled = true,
  int initialPageIndex = 0,
}) {
  return showAdwDialog<T>(
    context: context,
    builder: (_) => AdwPreferencesDialog(
      title: title,
      contentWidth: contentWidth,
      contentHeight: contentHeight,
      searchEnabled: searchEnabled,
      initialPageIndex: initialPageIndex,
      pages: pages,
    ),
  );
}
