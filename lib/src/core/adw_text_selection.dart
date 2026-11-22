import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/rendering.dart' show RenderMetaData;
import 'package:flutter/services.dart' show MethodChannel, TextInputFormatter;
import 'package:flutter/widgets.dart';

import '../theme/adw_colors.dart';
import '../theme/adw_theme.dart';
import '../widgets/layout/adw_sub_window.dart';
import '../widgets/overlays/adw_popover.dart';

/// Marker widget wrapping an input container (e.g. [AdwEntry], [AdwEntryRow],
/// [AdwSearchBar]) so the touch magnifier aligns with the outer input border
/// rather than the inner text line.
class AdwInputBounds extends StatelessWidget {
  final Widget child;

  const AdwInputBounds({super.key, required this.child});

  static const Object _marker = Object();

  /// Returns the global [Rect] of the nearest enclosing [AdwInputBounds], or
  /// `null` for plain selectable text without an input frame.
  static Rect? resolveBounds(BuildContext? context) {
    if (context == null || !context.mounted) return null;
    RenderObject? obj = context.findRenderObject();
    while (obj != null) {
      if (obj is RenderMetaData && identical(obj.metaData, _marker)) {
        if (obj.hasSize) {
          return obj.localToGlobal(Offset.zero) & obj.size;
        }
      }
      obj = obj.parent;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MetaData(
      metaData: _marker,
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}

/// Pure-Dart Adwaita-styled [TextSelectionControls] implementing:
/// - Libadwaita teardrop `cursor-handle`s (`20×20 px` with one sharp `0px`
///   corner, rotated `45°` for `.insertion-cursor`) on touch input.
/// - Libadwaita OSD `popover.touch-selection` (horizontal dark OSD bar with
///   pointing arrow, Cut/Copy/Paste/Select All/Insert Emoji/Share/ProcessText)
///   for touch selection.
/// - Libadwaita vertical `GtkPopoverMenu` inside a free native `PopupWindow`
///   for mouse right-click (`secondaryTap`).
class AdwTextSelectionControls extends TextSelectionControls
    with TextSelectionHandleControls {
  final Color? accentColor;

  AdwTextSelectionControls({this.accentColor});

  static const double _kHandleTouchSize = 44.0;
  static const double _kHandleVisualSize = 20.0;

  /// Builds a [TextMagnifierConfiguration] that aligns the magnifier with the
  /// enclosing [AdwInputBounds] top border when present, or with the text
  /// line (`caretRect.top`) for plain selectable text.
  static TextMagnifierConfiguration magnifierConfigurationFor(
    Rect? Function() resolveInputBounds,
  ) {
    return TextMagnifierConfiguration(
      shouldDisplayHandlesInMagnifier: false,
      magnifierBuilder: (
        BuildContext context,
        MagnifierController magnifierController,
        ValueNotifier<MagnifierInfo> magnifierInfo,
      ) {
        return _AdwTextMagnifier(
          magnifierInfo: magnifierInfo,
          resolveInputBounds: resolveInputBounds,
        );
      },
    );
  }

  /// Default Libadwaita `popover.magnifier` configuration (aligns with text).
  static final TextMagnifierConfiguration magnifierConfiguration =
      magnifierConfigurationFor(() => null);

  /// Returns [AdwTextSelectionControls] configured with the current Adwaita
  /// accent color. Mouse gestures automatically keep handles hidden via
  /// [EditableText.showSelectionHandles], while touch gestures on Android,
  /// iOS, and Linux touchscreens display the Libadwaita teardrop handles.
  static TextSelectionControls forPlatform(BuildContext context) {
    return AdwTextSelectionControls(
      accentColor: AdwTheme.maybeOf(context)?.colors.accentColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdwTextSelectionControls && other.accentColor == accentColor;

  @override
  int get hashCode => accentColor.hashCode;

  static const MethodChannel _portalChannel =
      MethodChannel('libadwaitter/portal');
  static const MethodChannel _textActionsChannel =
      MethodChannel('libadwaitter/text_actions');

  static Map<String, String>? _localizedLabels;
  static bool _labelsRequested = false;

  static bool _shouldUseOsLocalizedLabels(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return locale != null && locale.languageCode != 'en';
  }

  static Future<Map<String, String>> _ensureLocalizedLabels(
    BuildContext context,
  ) async {
    if (!_shouldUseOsLocalizedLabels(context)) {
      return const <String, String>{};
    }
    if (_localizedLabels != null) return _localizedLabels!;
    if (!_labelsRequested &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      _labelsRequested = true;
      try {
        final raw = await _textActionsChannel
            .invokeMapMethod<String, dynamic>('getLocalizedLabels');
        if (raw != null) {
          _localizedLabels = raw.map(
            (k, v) => MapEntry(k, v?.toString() ?? ''),
          );
          return _localizedLabels!;
        }
      } catch (_) {
        // Fall back to English defaults if runner does not implement channel.
      }
    }
    return _localizedLabels ?? const <String, String>{};
  }

  /// Adwaita context menu builder for [EditableText.contextMenuBuilder].
  ///
  /// Distinguishes mouse right-click (`lastSecondaryTapDownPosition != null`,
  /// rendered as a vertical `GtkPopoverMenu`) from touch selection
  /// (`lastSecondaryTapDownPosition == null`, rendered as a horizontal OSD
  /// `popover.touch-selection` with pointing arrow).
  static Widget contextMenuBuilder(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final items = List<ContextMenuButtonItem>.of(
      editableTextState.contextMenuButtonItems,
    );
    final value = editableTextState.textEditingValue;
    final hasSelection =
        value.selection.isValid && !value.selection.isCollapsed;
    final selectedText =
        hasSelection ? value.selection.textInside(value.text) : '';
    final isSecondaryTap =
        editableTextState.renderEditable.lastSecondaryTapDownPosition != null;
    final isTouchMode = !isSecondaryTap;

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        selectedText.isNotEmpty &&
        !items.any((i) => i.type == ContextMenuButtonType.share)) {
      items.add(
        ContextMenuButtonItem(
          type: ContextMenuButtonType.share,
          label: 'Share',
          onPressed: () {
            ContextMenuController.removeAny();
            _portalChannel.invokeMethod<dynamic>('share', {
              'text': selectedText,
            }).catchError((_) {});
          },
        ),
      );
    }

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.linux &&
        !editableTextState.widget.readOnly) {
      final anchor = editableTextState.contextMenuAnchors.primaryAnchor;
      items.add(
        ContextMenuButtonItem(
          type: ContextMenuButtonType.custom,
          label: 'Insert Emoji',
          onPressed: () {
            ContextMenuController.removeAny();
            _insertNativeLinuxEmoji(editableTextState, anchor);
          },
        ),
      );
    }

    return _AdwTextSelectionToolbar(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
      selectedText: selectedText,
      readOnly: editableTextState.widget.readOnly,
      isEditable: true,
      isTouchMode: isTouchMode,
      onReplaceSelectedText: (replacement) {
        if (!editableTextState.mounted || editableTextState.widget.readOnly) {
          return;
        }
        final current = editableTextState.textEditingValue;
        final sel = current.selection;
        if (!sel.isValid) return;
        final nextText =
            current.text.replaceRange(sel.start, sel.end, replacement);
        editableTextState.userUpdateTextEditingValue(
          current.copyWith(
            text: nextText,
            selection:
                TextSelection.collapsed(offset: sel.start + replacement.length),
            composing: TextRange.empty,
          ),
          SelectionChangedCause.toolbar,
        );
      },
    );
  }

  static Future<void> _insertNativeLinuxEmoji(
    EditableTextState editableTextState,
    Offset anchor,
  ) async {
    try {
      final raw = await _portalChannel.invokeMethod<dynamic>('pickEmoji', {
        'x': anchor.dx,
        'y': anchor.dy,
      });
      if (raw is Map && raw['status'] == 'granted') {
        final emoji = raw['value'] as String?;
        if (emoji != null && emoji.isNotEmpty && editableTextState.mounted) {
          final current = editableTextState.textEditingValue;
          final sel = current.selection;
          final start = sel.isValid ? sel.start : current.text.length;
          final end = sel.isValid ? sel.end : current.text.length;
          final nextText = current.text.replaceRange(start, end, emoji);
          editableTextState.userUpdateTextEditingValue(
            current.copyWith(
              text: nextText,
              selection: TextSelection.collapsed(offset: start + emoji.length),
              composing: TextRange.empty,
            ),
            SelectionChangedCause.toolbar,
          );
        }
      }
    } catch (_) {
      // Ignore if portal channel does not implement pickEmoji.
    }
  }

  /// Adwaita context menu builder for [SelectableRegion.contextMenuBuilder].
  static Widget selectableContextMenuBuilder(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final anchors = selectableRegionState.contextMenuAnchors;
    final isTouchMode = anchors.secondaryAnchor != null ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return _AdwTextSelectionToolbar(
      anchors: anchors,
      buttonItems: selectableRegionState.contextMenuButtonItems,
      isTouchMode: isTouchMode,
    );
  }

  @override
  Size getHandleSize(double textLineHeight) =>
      const Size(_kHandleTouchSize, _kHandleTouchSize);

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    const double leftInset = (_kHandleTouchSize - _kHandleVisualSize) / 2;
    switch (type) {
      case TextSelectionHandleType.left:
        // cursor-handle.top: sharp top-right corner of the 20x20 teardrop.
        return const Offset(leftInset + _kHandleVisualSize, 2.0);
      case TextSelectionHandleType.right:
        // cursor-handle.bottom: sharp top-left corner of the 20x20 teardrop
        // shifted +1px (transform: translateX(1px)).
        return const Offset(leftInset + 1.0, 2.0);
      case TextSelectionHandleType.collapsed:
        // cursor-handle.insertion-cursor: top vertex of the 45-degree rotated
        // 20x20 teardrop.
        return const Offset(_kHandleTouchSize / 2, 2.0);
    }
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    final theme = AdwTheme.maybeOf(context);
    final Color color =
        accentColor ?? theme?.colors.accentColor ?? AdwColors.accentBlue;

    final Widget handle = _AdwSelectionHandle(
      type: type,
      color: color,
    );

    if (onTap == null) return handle;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: handle,
    );
  }
}

/// Exact Libadwaita teardrop `cursor-handle` widget:
/// - `cursor-handle > contents`: `20×20 px`, `border-radius: 50%`,
///   `background-color: var(--accent-bg-color)`.
/// - `.top` ([TextSelectionHandleType.left]): `border-top-right-radius: 0`.
/// - `.bottom` ([TextSelectionHandleType.right]): `border-top-left-radius: 0`,
///   `translateX(1px)`.
/// - `.insertion-cursor` ([TextSelectionHandleType.collapsed]):
///   `border-top-left-radius: 0`, `rotate(45deg)`.
class _AdwSelectionHandle extends StatefulWidget {
  final TextSelectionHandleType type;
  final Color color;

  const _AdwSelectionHandle({
    required this.type,
    required this.color,
  });

  @override
  State<_AdwSelectionHandle> createState() => _AdwSelectionHandleState();
}

class _AdwSelectionHandleState extends State<_AdwSelectionHandle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const double touchSize = AdwTextSelectionControls._kHandleTouchSize;
    const double visualSize = AdwTextSelectionControls._kHandleVisualSize;
    const double leftInset = (touchSize - visualSize) / 2;
    const Radius round = Radius.circular(visualSize / 2);

    final BorderRadius borderRadius = switch (widget.type) {
      TextSelectionHandleType.left => const BorderRadius.only(
          topLeft: round,
          bottomLeft: round,
          bottomRight: round,
          topRight: Radius.zero,
        ),
      TextSelectionHandleType.right ||
      TextSelectionHandleType.collapsed =>
        const BorderRadius.only(
          topRight: round,
          bottomLeft: round,
          bottomRight: round,
          topLeft: Radius.zero,
        ),
    };

    Widget droplet = AnimatedScale(
      scale: _pressed ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Container(
        width: visualSize,
        height: visualSize,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: borderRadius,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );

    final double left;
    final double top;
    if (widget.type == TextSelectionHandleType.collapsed) {
      // Center of the 20x20 square at (22, 16) so its rotated top vertex
      // (14.14px above center) lands at (22, 2).
      left = leftInset;
      top = 6.0;
      droplet = Transform.rotate(
        angle: math.pi / 4,
        alignment: Alignment.center,
        child: droplet,
      );
    } else if (widget.type == TextSelectionHandleType.right) {
      left = leftInset + 1.0;
      top = 2.0;
    } else {
      left = leftInset;
      top = 2.0;
    }

    return TextFieldTapRegion(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          if (mounted && !_pressed) setState(() => _pressed = true);
        },
        onPointerUp: (_) {
          if (mounted && _pressed) setState(() => _pressed = false);
        },
        onPointerCancel: (_) {
          if (mounted && _pressed) setState(() => _pressed = false);
        },
        child: SizedBox(
          width: touchSize,
          height: touchSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: left,
                top: top,
                child: droplet,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdwTextSelectionToolbar extends StatefulWidget {
  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> buttonItems;
  final String selectedText;
  final bool readOnly;
  final bool isEditable;
  final bool isTouchMode;
  final ValueChanged<String>? onReplaceSelectedText;

  const _AdwTextSelectionToolbar({
    required this.anchors,
    required this.buttonItems,
    this.selectedText = '',
    this.readOnly = false,
    this.isEditable = false,
    this.isTouchMode = false,
    this.onReplaceSelectedText,
  });

  @override
  State<_AdwTextSelectionToolbar> createState() =>
      _AdwTextSelectionToolbarState();
}

class _AdwTextSelectionToolbarState extends State<_AdwTextSelectionToolbar> {
  Map<String, String> _labels = const <String, String>{};
  List<ContextMenuButtonItem> _nativeExtraItems = const [];
  bool _openingNativePopover = false;
  bool _metadataLoaded = false;

  bool get _useFreeNativePopup =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.linux &&
      AdwSubWindowManager.isNativeLinuxWindowingSupported &&
      AdwSubWindowManager.instance.isRootWindowRegistered;

  @override
  void initState() {
    super.initState();
    if (_useFreeNativePopup) {
      _scheduleNativePopover();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_useFreeNativePopup && !_metadataLoaded) {
      _metadataLoaded = true;
      _loadNativeMetadata();
    }
  }

  void _scheduleNativePopover() {
    if (_openingNativePopover) return;
    _openingNativePopover = true;
    // Snapshot state so the free native PopupWindow remains completely
    // independent even if GTK focus-out unmounts EditableText's overlay entry.
    final anchor = widget.anchors.primaryAnchor;
    final secondary = widget.anchors.secondaryAnchor;
    final isTouchMode = widget.isTouchMode;
    final isEditable = widget.isEditable;
    final readOnly = widget.readOnly;
    final itemsSnapshot = List<ContextMenuButtonItem>.of(widget.buttonItems);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openingNativePopover = false;
      if (!mounted) return;
      final Rect anchorRect = isTouchMode && secondary != null
          ? Rect.fromLTRB(
              math.min(anchor.dx, secondary.dx) - 2.0,
              math.min(anchor.dy, secondary.dy),
              math.max(anchor.dx, secondary.dx) + 2.0,
              math.max(anchor.dy, secondary.dy),
            )
          : Rect.fromCenter(
              center: anchor,
              width: 2.0,
              height: 2.0,
            );
      final initialLabels =
          AdwTextSelectionControls._shouldUseOsLocalizedLabels(context)
              ? (AdwTextSelectionControls._localizedLabels ??
                  const <String, String>{})
              : const <String, String>{};
      final popupLabels = ValueNotifier<Map<String, String>>(initialLabels);
      bool popupClosed = false;

      showAdwPopover(
        context: context,
        anchorRect: anchorRect,
        owner: Object(),
        parentAnchor: isTouchMode
            ? AdwPopoverAnchor.bottom
            : AdwPopoverAnchor.bottomLeft,
        childAnchor: isTouchMode
            ? AdwPopoverAnchor.top
            : AdwPopoverAnchor.topLeft,
        offset: isTouchMode ? const Offset(0, 6) : const Offset(0, 4),
        constraints: isTouchMode
            ? const BoxConstraints(
                minWidth: 120.0,
                maxWidth: 420.0,
                maxHeight: 96.0,
              )
            : const BoxConstraints(
                minWidth: 168.0,
                maxWidth: 248.0,
                maxHeight: 360.0,
              ),
        onDismiss: () {
          popupClosed = true;
          popupLabels.dispose();
          ContextMenuController.removeAny();
        },
        builder: (popoverContext, handle) {
          return ValueListenableBuilder<Map<String, String>>(
            valueListenable: popupLabels,
            builder: (context, labels, _) {
              if (isTouchMode) {
                return _buildTouchSelectionPopoverSurface(
                  context,
                  items: itemsSnapshot,
                  labels: labels,
                  arrowSide: AdwPopoverArrowSide.top,
                  onDismissPopup: handle.dismiss,
                );
              }
              return _buildDesktopPopoverMenu(
                context,
                items: itemsSnapshot,
                labels: labels,
                isEditable: isEditable,
                readOnly: readOnly,
                onDismissPopup: handle.dismiss,
              );
            },
          );
        },
      );

      AdwTextSelectionControls._ensureLocalizedLabels(context).then((labels) {
        if (!popupClosed && labels.isNotEmpty) {
          popupLabels.value = labels;
        }
      });
    });
  }

  Future<void> _loadNativeMetadata() async {
    final labels = await AdwTextSelectionControls._ensureLocalizedLabels(
      context,
    );
    List<ContextMenuButtonItem> extra = const [];
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        widget.selectedText.isNotEmpty) {
      try {
        final raw = await AdwTextSelectionControls._textActionsChannel
            .invokeListMethod<dynamic>('getTextActions');
        if (raw != null) {
          final existingLabels = widget.buttonItems
              .map((b) => (b.label ?? '').toLowerCase())
              .toSet();
          final built = <ContextMenuButtonItem>[];
          for (final entry in raw) {
            if (entry is! Map) continue;
            final label = entry['label']?.toString() ?? '';
            final pkg = entry['packageName']?.toString() ?? '';
            final cls = entry['className']?.toString() ?? '';
            if (label.isEmpty ||
                pkg.isEmpty ||
                cls.isEmpty ||
                existingLabels.contains(label.toLowerCase())) {
              continue;
            }
            existingLabels.add(label.toLowerCase());
            built.add(
              ContextMenuButtonItem(
                type: ContextMenuButtonType.custom,
                label: label,
                onPressed: () async {
                  ContextMenuController.removeAny();
                  try {
                    final replaced = await AdwTextSelectionControls
                        ._textActionsChannel
                        .invokeMethod<String>('performTextAction', {
                      'packageName': pkg,
                      'className': cls,
                      'text': widget.selectedText,
                      'readOnly': widget.readOnly,
                    });
                    if (replaced != null && replaced.isNotEmpty) {
                      widget.onReplaceSelectedText?.call(replaced);
                    }
                  } catch (_) {}
                },
              ),
            );
          }
          extra = built;
        }
      } catch (_) {
        // Ignore if runner does not implement getTextActions.
      }
    }
    if (!mounted) return;
    if (labels != _labels || extra.isNotEmpty) {
      setState(() {
        _labels = labels;
        _nativeExtraItems = extra;
      });
    }
  }

  static String _labelFor(
    ContextMenuButtonItem item,
    Map<String, String> labels,
  ) {
    if (item.type == ContextMenuButtonType.custom &&
        item.label == 'Insert Emoji') {
      return labels['insertEmoji'] ?? 'Insert Emoji';
    }
    return switch (item.type) {
      ContextMenuButtonType.cut => labels['cut'] ?? item.label ?? 'Cut',
      ContextMenuButtonType.copy => labels['copy'] ?? item.label ?? 'Copy',
      ContextMenuButtonType.paste => labels['paste'] ?? item.label ?? 'Paste',
      ContextMenuButtonType.selectAll =>
        labels['selectAll'] ?? item.label ?? 'Select All',
      ContextMenuButtonType.delete => item.label ?? 'Delete',
      ContextMenuButtonType.lookUp => item.label ?? 'Look Up',
      ContextMenuButtonType.searchWeb => item.label ?? 'Search',
      ContextMenuButtonType.share => labels['share'] ?? item.label ?? 'Share',
      ContextMenuButtonType.liveTextInput => item.label ?? 'Scan Text',
      ContextMenuButtonType.custom => item.label ?? '',
    };
  }

  static ContextMenuButtonItem? _findItem(
    List<ContextMenuButtonItem> items,
    ContextMenuButtonType type,
  ) {
    for (final item in items) {
      if (item.type == type) return item;
    }
    return null;
  }

  static VoidCallback? _wrapAction(
    VoidCallback? onPressed,
    VoidCallback? onDismissPopup,
  ) {
    if (onPressed == null) return null;
    return () {
      onDismissPopup?.call();
      onPressed();
    };
  }

  /// Authentic GTK4 / Libadwaita vertical `GtkPopoverMenu` layout for mouse
  /// right-click (`Cut / Copy / Paste` — divider — `Select All` — divider —
  /// `Insert Emoji` & extra actions).
  static Widget _buildDesktopPopoverMenu(
    BuildContext context, {
    required List<ContextMenuButtonItem> items,
    required Map<String, String> labels,
    required bool isEditable,
    required bool readOnly,
    VoidCallback? onDismissPopup,
  }) {
    final cutItem = _findItem(items, ContextMenuButtonType.cut);
    final copyItem = _findItem(items, ContextMenuButtonType.copy);
    final pasteItem = _findItem(items, ContextMenuButtonType.paste);
    final selectAllItem = _findItem(items, ContextMenuButtonType.selectAll);
    final extraItems = items
        .where(
          (i) =>
              i.type != ContextMenuButtonType.cut &&
              i.type != ContextMenuButtonType.copy &&
              i.type != ContextMenuButtonType.paste &&
              i.type != ContextMenuButtonType.selectAll,
        )
        .toList();

    final rows = <Widget>[];
    if (isEditable && !readOnly) {
      rows.add(
        AdwPopoverMenuItem(
          label: labels['cut'] ?? 'Cut',
          onTap: _wrapAction(cutItem?.onPressed, onDismissPopup),
        ),
      );
      rows.add(
        AdwPopoverMenuItem(
          label: labels['copy'] ?? 'Copy',
          onTap: _wrapAction(copyItem?.onPressed, onDismissPopup),
        ),
      );
      rows.add(
        AdwPopoverMenuItem(
          label: labels['paste'] ?? 'Paste',
          onTap: _wrapAction(pasteItem?.onPressed, onDismissPopup),
        ),
      );
      rows.add(const AdwPopoverDivider());
      rows.add(
        AdwPopoverMenuItem(
          label: labels['selectAll'] ?? 'Select All',
          onTap: _wrapAction(selectAllItem?.onPressed, onDismissPopup),
        ),
      );
    } else {
      if (copyItem != null) {
        rows.add(
          AdwPopoverMenuItem(
            label: _labelFor(copyItem, labels),
            onTap: _wrapAction(copyItem.onPressed, onDismissPopup),
          ),
        );
      }
      if (selectAllItem != null) {
        if (rows.isNotEmpty) rows.add(const AdwPopoverDivider());
        rows.add(
          AdwPopoverMenuItem(
            label: _labelFor(selectAllItem, labels),
            onTap: _wrapAction(selectAllItem.onPressed, onDismissPopup),
          ),
        );
      }
    }

    if (extraItems.isNotEmpty) {
      if (rows.isNotEmpty) rows.add(const AdwPopoverDivider());
      for (final item in extraItems) {
        rows.add(
          AdwPopoverMenuItem(
            label: _labelFor(item, labels),
            onTap: _wrapAction(item.onPressed, onDismissPopup),
          ),
        );
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return TextFieldTapRegion(
      child: AdwPopoverSurface(
        arrowSide: AdwPopoverArrowSide.none,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 168.0,
            maxWidth: 248.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ),
    );
  }

  static _AdwTouchIconKind? _iconKindFor(ContextMenuButtonItem item) {
    if (item.type == ContextMenuButtonType.custom &&
        item.label == 'Insert Emoji') {
      return _AdwTouchIconKind.insertEmoji;
    }
    return switch (item.type) {
      ContextMenuButtonType.cut => _AdwTouchIconKind.cut,
      ContextMenuButtonType.copy => _AdwTouchIconKind.copy,
      ContextMenuButtonType.paste => _AdwTouchIconKind.paste,
      ContextMenuButtonType.selectAll => _AdwTouchIconKind.selectAll,
      ContextMenuButtonType.share => _AdwTouchIconKind.share,
      _ => null,
    };
  }

  /// Authentic Libadwaita `popover.touch-selection` OSD surface:
  /// dark OSD popover with pointing arrow and a `.linked` bar of symbolic icon
  /// buttons (`Cut`, `Copy`, `Paste`, `Select All`, `Insert Emoji`, `Share`),
  /// plus optional compact text buttons for Android `ACTION_PROCESS_TEXT`.
  static Widget _buildTouchSelectionPopoverSurface(
    BuildContext context, {
    required List<ContextMenuButtonItem> items,
    required Map<String, String> labels,
    required AdwPopoverArrowSide arrowSide,
    VoidCallback? onDismissPopup,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    final iconItems = <(ContextMenuButtonItem, _AdwTouchIconKind)>[];
    final textItems = <ContextMenuButtonItem>[];
    for (final item in items) {
      final kind = _iconKindFor(item);
      if (kind != null) {
        iconItems.add((item, kind));
      } else {
        textItems.add(item);
      }
    }

    return TextFieldTapRegion(
      child: AdwPopoverSurface(
        isOsd: true,
        arrowSide: arrowSide,
        padding: const EdgeInsets.all(10.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconItems.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x18FFFFFF),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < iconItems.length; i++) ...[
                          if (i > 0)
                            Container(
                              width: 1,
                              height: 34,
                              color: const Color(0x1EFFFFFF),
                            ),
                          _AdwTouchIconButton(
                            kind: iconItems[i].$2,
                            semanticLabel: _labelFor(iconItems[i].$1, labels),
                            onPressed: _wrapAction(
                              iconItems[i].$1.onPressed,
                              onDismissPopup,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (iconItems.isNotEmpty && textItems.isNotEmpty)
                const SizedBox(width: 6),
              if (textItems.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x18FFFFFF),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < textItems.length; i++) ...[
                          if (i > 0)
                            Container(
                              width: 1,
                              height: 34,
                              color: const Color(0x1EFFFFFF),
                            ),
                          _AdwTouchOsdButton(
                            label: _labelFor(textItems[i], labels),
                            onPressed: _wrapAction(
                              textItems[i].onPressed,
                              onDismissPopup,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Positioned `popover.touch-selection` for in-window overlays (Android, iOS,
  /// and headless tests). Always prefers BELOW the selection with an upward
  /// arrow (matching Libadwaita), flipping above only near the bottom edge.
  Widget _buildTouchOverlayToolbar(BuildContext context) {
    final allItems = <ContextMenuButtonItem>[
      ...widget.buttonItems,
      ..._nativeExtraItems,
    ];
    if (allItems.isEmpty) return const SizedBox.shrink();
    final screenSize = MediaQuery.sizeOf(context);
    final maxWidth = math.max(180.0, screenSize.width - 16.0);
    final anchorBelow =
        widget.anchors.secondaryAnchor ?? widget.anchors.primaryAnchor;
    final placeAbove = anchorBelow.dy + 76.0 > screenSize.height;
    final arrowSide =
        placeAbove ? AdwPopoverArrowSide.bottom : AdwPopoverArrowSide.top;

    return CustomSingleChildLayout(
      delegate: _AdwToolbarLayoutDelegate(
        anchorAbove: widget.anchors.primaryAnchor,
        anchorBelow: anchorBelow,
        preferBelow: true,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: _buildTouchSelectionPopoverSurface(
          context,
          items: allItems,
          labels: _labels,
          arrowSide: arrowSide,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_useFreeNativePopup) {
      // Rendered inside a free native GTK PopupWindow via showAdwPopover.
      return const SizedBox.shrink();
    }
    if (!widget.isTouchMode) {
      final allItems = <ContextMenuButtonItem>[
        ...widget.buttonItems,
        ..._nativeExtraItems,
      ];
      return CustomSingleChildLayout(
        delegate: _AdwToolbarLayoutDelegate(
          anchorAbove: widget.anchors.primaryAnchor,
          anchorBelow:
              widget.anchors.secondaryAnchor ?? widget.anchors.primaryAnchor,
        ),
        child: _buildDesktopPopoverMenu(
          context,
          items: allItems,
          labels: _labels,
          isEditable: widget.isEditable,
          readOnly: widget.readOnly,
        ),
      );
    }
    return _buildTouchOverlayToolbar(context);
  }
}

/// Symbolic icon kinds rendered inside Libadwaita's `popover.touch-selection`.
enum _AdwTouchIconKind {
  cut,
  copy,
  paste,
  selectAll,
  insertEmoji,
  share,
}

class _AdwTouchIconButton extends StatefulWidget {
  final _AdwTouchIconKind kind;
  final String semanticLabel;
  final VoidCallback? onPressed;

  const _AdwTouchIconButton({
    required this.kind,
    required this.semanticLabel,
    this.onPressed,
  });

  @override
  State<_AdwTouchIconButton> createState() => _AdwTouchIconButtonState();
}

class _AdwTouchIconButtonState extends State<_AdwTouchIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    if (_pressed) {
      bg = const Color(0x2EFFFFFF);
    } else if (_hovered) {
      bg = const Color(0x1CFFFFFF);
    } else {
      bg = const Color(0x00000000);
    }

    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (mounted) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (mounted) setState(() => _hovered = false);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            if (mounted) setState(() => _pressed = true);
          },
          onTapUp: (_) {
            if (mounted) setState(() => _pressed = false);
          },
          onTapCancel: () {
            if (mounted) setState(() => _pressed = false);
          },
          onTap: widget.onPressed,
          child: Container(
            width: 38,
            height: 34,
            color: bg,
            alignment: Alignment.center,
            child: CustomPaint(
              size: const Size(16, 16),
              painter: _AdwTouchSymbolicIconPainter(
                kind: widget.kind,
                color: const Color(0xE6FFFFFF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pure-Dart Adwaita 16x16 symbolic icons for `popover.touch-selection`
/// (matching GTK4's `edit-cut-symbolic`, `edit-copy-symbolic`,
/// `edit-paste-symbolic`, `edit-select-all-symbolic`, `face-smile-symbolic`,
/// and `emblem-shared-symbolic`).
class _AdwTouchSymbolicIconPainter extends CustomPainter {
  final _AdwTouchIconKind kind;
  final Color color;

  const _AdwTouchSymbolicIconPainter({
    required this.kind,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (kind) {
      case _AdwTouchIconKind.cut:
        canvas.drawCircle(const Offset(4.5, 12.0), 2.3, stroke);
        canvas.drawCircle(const Offset(11.5, 12.0), 2.3, stroke);
        canvas.drawLine(const Offset(6.2, 10.2), const Offset(11.8, 2.5), stroke);
        canvas.drawLine(const Offset(9.8, 10.2), const Offset(4.2, 2.5), stroke);
      case _AdwTouchIconKind.copy:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2.0, 2.0, 8.0, 9.5),
            const Radius.circular(1.5),
          ),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(6.0, 5.0, 8.0, 9.5),
            const Radius.circular(1.5),
          ),
          stroke,
        );
      case _AdwTouchIconKind.paste:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.0, 3.2, 10.0, 11.3),
            const Radius.circular(1.8),
          ),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5.5, 1.5, 5.0, 2.8),
            const Radius.circular(1.0),
          ),
          fill,
        );
      case _AdwTouchIconKind.selectAll:
        // Dashed outer border + 2x2 inner grid (exact Adwaita icon).
        for (final x in [1.5, 5.2, 8.8, 12.5]) {
          canvas.drawRect(Rect.fromLTWH(x, 1.5, 2.0, 1.5), fill);
          canvas.drawRect(Rect.fromLTWH(x, 13.0, 2.0, 1.5), fill);
        }
        for (final y in [5.2, 8.8]) {
          canvas.drawRect(Rect.fromLTWH(1.5, y, 1.5, 2.0), fill);
          canvas.drawRect(Rect.fromLTWH(13.0, y, 1.5, 2.0), fill);
        }
        canvas.drawRect(const Rect.fromLTWH(4.8, 4.8, 2.7, 2.7), fill);
        canvas.drawRect(const Rect.fromLTWH(8.5, 4.8, 2.7, 2.7), fill);
        canvas.drawRect(const Rect.fromLTWH(4.8, 8.5, 2.7, 2.7), fill);
        canvas.drawRect(const Rect.fromLTWH(8.5, 8.5, 2.7, 2.7), fill);
      case _AdwTouchIconKind.insertEmoji:
        canvas.drawCircle(const Offset(8.0, 8.0), 6.5, stroke);
        canvas.drawCircle(const Offset(5.7, 6.6), 1.0, fill);
        canvas.drawCircle(const Offset(10.3, 6.6), 1.0, fill);
        final smile = Path()
          ..moveTo(5.2, 9.8)
          ..quadraticBezierTo(8.0, 12.2, 10.8, 9.8);
        canvas.drawPath(smile, stroke);
      case _AdwTouchIconKind.share:
        canvas.drawCircle(const Offset(3.5, 8.0), 2.0, fill);
        canvas.drawCircle(const Offset(12.2, 3.5), 2.0, fill);
        canvas.drawCircle(const Offset(12.2, 12.5), 2.0, fill);
        canvas.drawLine(const Offset(5.0, 7.2), const Offset(10.6, 4.3), stroke);
        canvas.drawLine(const Offset(5.0, 8.8), const Offset(10.6, 11.7), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _AdwTouchSymbolicIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

/// Libadwaita `popover.magnifier` lens for touch text selection.
/// Displays a live 1.75× GPU-magnified viewport with full native brightness
/// (`RawMagnifier` painted *before* the punched-out OSD frame + arrow so
/// `BackdropFilter` never dims the magnified text).
class _AdwTextMagnifier extends StatelessWidget {
  final ValueNotifier<MagnifierInfo> magnifierInfo;
  final Rect? Function()? resolveInputBounds;

  const _AdwTextMagnifier({
    required this.magnifierInfo,
    this.resolveInputBounds,
  });

  static const double _kLensWidth = 112.0;
  static const double _kLensHeight = 42.0;
  static const double _kPadding = 5.0;
  static const double _kArrowWidth = 16.0;
  static const double _kArrowHeight = 8.0;
  static const double _kOuterRadius = 11.0;
  static const double _kLensRadius = 6.0;
  static const double _kScale = 1.65;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    const totalWidth = _kLensWidth + _kPadding * 2;
    const totalHeight = _kLensHeight + _kPadding * 2 + _kArrowHeight;

    return ValueListenableBuilder<MagnifierInfo>(
      valueListenable: magnifierInfo,
      builder: (context, info, _) {
        if (info == MagnifierInfo.empty) {
          return const SizedBox.shrink();
        }
        final targetX = (!info.caretRect.isEmpty
                ? info.caretRect.center.dx
                : info.globalGesturePosition.dx)
            .clamp(
              info.fieldBounds.isEmpty ? 0.0 : info.fieldBounds.left,
              info.fieldBounds.isEmpty
                  ? screenSize.width
                  : info.fieldBounds.right,
            )
            .toDouble();
        final targetY = !info.caretRect.isEmpty
            ? info.caretRect.center.dy
            : info.globalGesturePosition.dy;
        final caretTop = !info.caretRect.isEmpty
            ? info.caretRect.top
            : info.globalGesturePosition.dy - 10.0;

        final left = (targetX - totalWidth / 2)
            .clamp(
              8.0,
              math.max(8.0, screenSize.width - totalWidth - 8.0),
            )
            .toDouble();

        // Align with the outer input top border when inside an input widget,
        // or with the text line (`caretTop`) for plain selectable text.
        final Rect? inputBounds = resolveInputBounds?.call();
        final double anchorTop = inputBounds != null
            ? inputBounds.top
            : caretTop;
        final double top = (anchorTop - totalHeight - 6.0)
            .clamp(
              0.0,
              math.max(0.0, screenSize.height - totalHeight - 4.0),
            )
            .toDouble();

        final arrowOffset = (targetX - left)
            .clamp(
              _kOuterRadius + _kArrowWidth / 2 + 2.0,
              totalWidth - _kOuterRadius - _kArrowWidth / 2 - 2.0,
            )
            .toDouble();

        const lensTopInWidget = _kPadding;
        final lensCenterGlobal = Offset(
          left + _kPadding + _kLensWidth / 2,
          top + lensTopInWidget + _kLensHeight / 2,
        );
        final focalOffset = Offset(targetX, targetY) - lensCenterGlobal;

        return Positioned(
          left: left,
          top: top,
          child: IgnorePointer(
            child: SizedBox(
              width: totalWidth,
              height: totalHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Paint RawMagnifier FIRST with zero background behind it
                  //    so BackdropFilter magnifies crisp, full-brightness text.
                  Positioned(
                    left: _kPadding,
                    top: lensTopInWidget,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_kLensRadius),
                      child: RawMagnifier(
                        size: const Size(_kLensWidth, _kLensHeight),
                        magnificationScale: _kScale,
                        focalPointOffset: focalOffset,
                        decoration: const MagnifierDecoration(),
                      ),
                    ),
                  ),
                  // 2. Paint the dark OSD outer frame + bottom arrow AFTER
                  //    RawMagnifier with an even-odd hole for the lens.
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _AdwMagnifierFramePainter(
                        lensRect: Rect.fromLTWH(
                          _kPadding,
                          lensTopInWidget,
                          _kLensWidth,
                          _kLensHeight,
                        ),
                        arrowOnTop: false,
                        arrowCenterX: arrowOffset,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdwMagnifierFramePainter extends CustomPainter {
  final Rect lensRect;
  final bool arrowOnTop;
  final double arrowCenterX;

  const _AdwMagnifierFramePainter({
    required this.lensRect,
    required this.arrowOnTop,
    required this.arrowCenterX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double arrowW = _AdwTextMagnifier._kArrowWidth;
    const double arrowH = _AdwTextMagnifier._kArrowHeight;
    const double outerR = _AdwTextMagnifier._kOuterRadius;
    const double lensR = _AdwTextMagnifier._kLensRadius;

    final double bodyTop = arrowOnTop ? arrowH : 0.0;
    final double bodyBottom = arrowOnTop ? size.height : size.height - arrowH;
    final outerRect = Rect.fromLTRB(0, bodyTop, size.width, bodyBottom);

    Path outerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(outerRect, const Radius.circular(outerR)));

    final halfW = arrowW / 2;
    if (arrowOnTop) {
      final arrow = Path()
        ..moveTo(arrowCenterX - halfW, bodyTop + 1)
        ..lineTo(arrowCenterX, 0)
        ..lineTo(arrowCenterX + halfW, bodyTop + 1)
        ..close();
      outerPath = Path.combine(PathOperation.union, outerPath, arrow);
    } else {
      final arrow = Path()
        ..moveTo(arrowCenterX - halfW, bodyBottom - 1)
        ..lineTo(arrowCenterX, size.height)
        ..lineTo(arrowCenterX + halfW, bodyBottom - 1)
        ..close();
      outerPath = Path.combine(PathOperation.union, outerPath, arrow);
    }

    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(lensRect, const Radius.circular(lensR)));

    // Punched-out OSD frame (outer popover minus lens hole).
    final framePath = Path.combine(PathOperation.difference, outerPath, holePath);

    canvas.drawPath(
      framePath,
      Paint()
        ..color = const Color(0xB3000000) // Libadwaita OSD RGB(0 0 0 / 70%)
        ..style = PaintingStyle.fill,
    );

    // Subtle 1px rim around outer popover + lens edge.
    canvas.drawPath(
      outerPath,
      Paint()
        ..color = const Color(0x1AFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.drawPath(
      holePath,
      Paint()
        ..color = const Color(0x1AFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _AdwMagnifierFramePainter oldDelegate) =>
      oldDelegate.lensRect != lensRect ||
      oldDelegate.arrowOnTop != arrowOnTop ||
      oldDelegate.arrowCenterX != arrowCenterX;
}

/// Flat OSD button inside `popover.touch-selection` for custom text actions.
class _AdwTouchOsdButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;

  const _AdwTouchOsdButton({
    required this.label,
    this.onPressed,
  });

  @override
  State<_AdwTouchOsdButton> createState() => _AdwTouchOsdButtonState();
}

class _AdwTouchOsdButtonState extends State<_AdwTouchOsdButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.maybeOf(context);
    const fg = Color(0xE6FFFFFF); // RGB(255 255 255 / 90%)
    final style = (theme?.typography.body ?? const TextStyle(fontSize: 13.5))
        .copyWith(
      color: fg,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    );

    final Color bg;
    if (_pressed) {
      bg = const Color(0x29FFFFFF);
    } else if (_hovered) {
      bg = const Color(0x1AFFFFFF);
    } else {
      bg = const Color(0x00000000);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (mounted) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _hovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (mounted) setState(() => _pressed = true);
        },
        onTapUp: (_) {
          if (mounted) setState(() => _pressed = false);
        },
        onTapCancel: () {
          if (mounted) setState(() => _pressed = false);
        },
        onTap: widget.onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(widget.label, style: style),
        ),
      ),
    );
  }
}

class _AdwToolbarLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset anchorAbove;
  final Offset anchorBelow;
  final bool preferBelow;

  const _AdwToolbarLayoutDelegate({
    required this.anchorAbove,
    required this.anchorBelow,
    this.preferBelow = false,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const double margin = 8.0;
    const double gap = 6.0;
    final double dx = (anchorAbove.dx - childSize.width / 2).clamp(
      margin,
      math.max(margin, size.width - childSize.width - margin),
    );
    double dy;
    if (preferBelow) {
      dy = anchorBelow.dy + gap;
      if (dy + childSize.height > size.height - margin) {
        dy = (anchorAbove.dy - childSize.height - gap).clamp(
          margin,
          math.max(margin, size.height - childSize.height - margin),
        );
      }
    } else {
      dy = anchorAbove.dy - childSize.height - gap;
      if (dy < margin) {
        dy = (anchorBelow.dy + gap).clamp(
          margin,
          math.max(margin, size.height - childSize.height - margin),
        );
      }
    }
    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(covariant _AdwToolbarLayoutDelegate oldDelegate) {
    return anchorAbove != oldDelegate.anchorAbove ||
        anchorBelow != oldDelegate.anchorBelow ||
        preferBelow != oldDelegate.preferBelow;
  }
}

/// Reusable [EditableText] wrapper with full touch & pointer text selection
/// ([TextSelectionGestureDetectorBuilder], Libadwaita teardrop `cursor-handle`s
/// on touch, OSD `popover.touch-selection` on touch, and vertical
/// `GtkPopoverMenu` on mouse right-click).
class AdwEditableText extends StatefulWidget {
  final GlobalKey<EditableTextState>? editableTextKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final Color cursorColor;
  final Color backgroundCursorColor;
  final Color selectionColor;
  final bool obscureText;
  final bool readOnly;
  final double cursorWidth;
  final bool cursorOpacityAnimates;
  final bool showCursor;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TapRegionCallback? onTapOutside;

  const AdwEditableText({
    super.key,
    this.editableTextKey,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.cursorColor,
    required this.backgroundCursorColor,
    required this.selectionColor,
    this.obscureText = false,
    this.readOnly = false,
    this.cursorWidth = 1.5,
    this.cursorOpacityAnimates = true,
    this.showCursor = true,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTapOutside,
  });

  @override
  State<AdwEditableText> createState() => _AdwEditableTextState();
}

class _AdwEditableTextState extends State<AdwEditableText>
    implements TextSelectionGestureDetectorBuilderDelegate {
  final GlobalKey<EditableTextState> _internalEditableTextKey =
      GlobalKey<EditableTextState>();

  @override
  GlobalKey<EditableTextState> get editableTextKey =>
      widget.editableTextKey ?? _internalEditableTextKey;

  late final TextSelectionGestureDetectorBuilder
      _selectionGestureDetectorBuilder;
  late final TextMagnifierConfiguration _magnifierConfiguration;
  bool _showSelectionHandles = false;

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  @override
  void initState() {
    super.initState();
    _selectionGestureDetectorBuilder =
        _AdwSelectionGestureDetectorBuilder(delegate: this);
    _magnifierConfiguration = AdwTextSelectionControls.magnifierConfigurationFor(
      () => mounted ? AdwInputBounds.resolveBounds(context) : null,
    );
  }

  bool _shouldShowSelectionHandles(SelectionChangedCause? cause) {
    if (!_selectionGestureDetectorBuilder.shouldShowSelectionToolbar ||
        !_selectionGestureDetectorBuilder.shouldShowSelectionHandles) {
      return false;
    }
    if (cause == SelectionChangedCause.keyboard) {
      return false;
    }
    if (widget.readOnly && widget.controller.selection.isCollapsed) {
      return false;
    }
    if (cause == SelectionChangedCause.longPress ||
        cause == SelectionChangedCause.stylusHandwriting) {
      return true;
    }
    if (widget.controller.text.isNotEmpty) {
      return true;
    }
    return false;
  }

  void _handleSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    final willShow = _shouldShowSelectionHandles(cause);
    if (willShow != _showSelectionHandles) {
      setState(() {
        _showSelectionHandles = willShow;
      });
    }
    if (cause == SelectionChangedCause.longPress) {
      editableTextKey.currentState?.bringIntoView(selection.extent);
    }
  }

  void _handleSelectionHandleTapped() {
    if (widget.controller.selection.isCollapsed) {
      editableTextKey.currentState?.toggleToolbar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasOverlay = Overlay.maybeOf(context) != null;
    return TextFieldTapRegion(
      child: _selectionGestureDetectorBuilder.buildGestureDetector(
        behavior: HitTestBehavior.translucent,
        child: EditableText(
          key: editableTextKey,
          controller: widget.controller,
          focusNode: widget.focusNode,
          style: widget.style,
          cursorColor: widget.cursorColor,
          backgroundCursorColor: widget.backgroundCursorColor,
          selectionColor: widget.selectionColor,
          cursorWidth: widget.cursorWidth,
          cursorOpacityAnimates: widget.cursorOpacityAnimates,
          showCursor: widget.showCursor,
          showSelectionHandles: _showSelectionHandles,
          onSelectionChanged: _handleSelectionChanged,
          onSelectionHandleTapped: _handleSelectionHandleTapped,
          rendererIgnoresPointer: true,
          enableInteractiveSelection: true,
          selectionControls:
              hasOverlay ? AdwTextSelectionControls.forPlatform(context) : null,
          contextMenuBuilder:
              hasOverlay ? AdwTextSelectionControls.contextMenuBuilder : null,
          magnifierConfiguration: hasOverlay
              ? _magnifierConfiguration
              : TextMagnifierConfiguration.disabled,
          obscureText: widget.obscureText,
          readOnly: widget.readOnly,
          keyboardType: widget.keyboardType ?? TextInputType.text,
          inputFormatters: widget.inputFormatters,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          onTapOutside: widget.onTapOutside,
        ),
      ),
    );
  }
}

/// Extends [TextSelectionGestureDetectorBuilder] to match Libadwaita's touch
/// selection behavior:
/// - Long-press starts at the exact character under the finger (without
///   selecting the whole word) and opens the magnifier on Android, iOS, and
///   Linux touchscreens.
/// - Dragging while holding selects character-by-character from the initial
///   touch point to the current finger position while tracking the magnifier.
class _AdwSelectionGestureDetectorBuilder
    extends TextSelectionGestureDetectorBuilder {
  _AdwSelectionGestureDetectorBuilder({required super.delegate});

  Offset? _longPressOrigin;

  @override
  void onSingleLongTapStart(LongPressStartDetails details) {
    if (!delegate.selectionEnabled) return;
    _longPressOrigin = details.globalPosition;
    renderEditable.selectPositionAt(
      from: details.globalPosition,
      cause: SelectionChangedCause.longPress,
    );
    if (editableText.context.mounted) {
      Feedback.forLongPress(editableText.context);
    }
    editableText.showMagnifier(details.globalPosition);
  }

  @override
  void onSingleLongTapMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!delegate.selectionEnabled) return;
    final origin = _longPressOrigin ??
        (details.globalPosition - details.offsetFromOrigin);
    renderEditable.selectPositionAt(
      from: origin,
      to: details.globalPosition,
      cause: SelectionChangedCause.longPress,
    );
    editableText.showMagnifier(details.globalPosition);
  }

  @override
  void onSingleLongTapEnd(LongPressEndDetails details) {
    _longPressOrigin = null;
    editableText.hideMagnifier();
    if (shouldShowSelectionToolbar) {
      editableText.showToolbar();
    }
  }

  @override
  void onSingleLongTapCancel() {
    _longPressOrigin = null;
    editableText.hideMagnifier();
  }
}
