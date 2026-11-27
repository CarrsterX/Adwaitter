import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart' show RenderMetaData;
import 'package:flutter/services.dart'
    show Clipboard, HapticFeedback, MethodChannel, TextInputFormatter;
import 'package:flutter/widgets.dart';

import '../theme/adw_colors.dart';
import '../theme/adw_theme.dart';
import '../widgets/layout/adw_sub_window.dart';
import '../widgets/overlays/adw_popover.dart';

/// Marker widget wrapping an input container (e.g. [AdwEntry], [AdwEntryRow],
/// [AdwSearchBar]) so the touch magnifier aligns with the outer input border
/// rather than the inner text line.
///
/// {@category Core}
class AdwInputBounds extends StatelessWidget {
  /// Input widget subtree whose outer bounds are exposed to the magnifier.
  final Widget child;

  /// Creates an input-bounds marker wrapping [child].
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

  /// Key attached to the active Libadwaita text magnifier widget.
  static const Key magnifierKey = ValueKey<String>('adw_text_magnifier');

  static DateTime? _lastToolbarPointerDown;

  static void _markToolbarPointerDown() {
    _lastToolbarPointerDown = DateTime.now();
  }

  static bool get _isRecentToolbarPointerDown {
    final ts = _lastToolbarPointerDown;
    if (ts == null) return false;
    return DateTime.now().difference(ts) < const Duration(milliseconds: 150);
  }

  /// Builds a [TextMagnifierConfiguration] that aligns the magnifier with the
  /// enclosing [AdwInputBounds] top border when present, or with the text
  /// line (`caretRect.top`) for plain selectable text.
  ///
  /// When [resolveEditableText] is provided, renders a crisp `2.0×` vector
  /// [TextPainter] lens instead of blurry `BackdropFilter` pixel upscaling.
  static TextMagnifierConfiguration magnifierConfigurationFor(
    Rect? Function() resolveInputBounds, {
    EditableTextState? Function()? resolveEditableText,
  }) {
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
          resolveEditableText: resolveEditableText,
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
    EditableTextState editableTextState, {
    bool? isTouch,
  }) {
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
    final isTouchMode = isTouch ??
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            !isSecondaryTap);

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
      onPasteRequested: editableTextState.widget.readOnly
          ? null
          : () {
              if (editableTextState.mounted) {
                editableTextState.pasteText(SelectionChangedCause.toolbar);
              }
            },
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
  ///
  /// On Linux, touch selection on non-input selectable text hides the touch
  /// menu by default (matching native GTK4 / Libadwaita) unless
  /// [enableLinuxTouchMenu] is `true`. Mouse right-click always shows the
  /// vertical desktop popover menu, and Android/iOS always show the touch bar.
  static Widget selectableContextMenuBuilder(
    BuildContext context,
    SelectableRegionState selectableRegionState, {
    bool enableLinuxTouchMenu = false,
  }) {
    final anchors = selectableRegionState.contextMenuAnchors;
    final isTouchMode = anchors.secondaryAnchor != null ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (isTouchMode &&
        !enableLinuxTouchMenu &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.linux) {
      return const SizedBox.shrink();
    }
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

    final Widget handle = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => HapticFeedback.mediumImpact(),
      child: _AdwSelectionHandle(
        type: type,
        color: color,
      ),
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
  final VoidCallback? onPasteRequested;
  final ValueChanged<String>? onReplaceSelectedText;

  const _AdwTextSelectionToolbar({
    required this.anchors,
    required this.buttonItems,
    this.selectedText = '',
    this.readOnly = false,
    this.isEditable = false,
    this.isTouchMode = false,
    this.onPasteRequested,
    this.onReplaceSelectedText,
  });

  @override
  State<_AdwTextSelectionToolbar> createState() =>
      _AdwTextSelectionToolbarState();
}

class _AdwTextSelectionToolbarState extends State<_AdwTextSelectionToolbar> {
  Map<String, String> _labels = const <String, String>{};
  List<ContextMenuButtonItem> _nativeExtraItems = const [];
  Map<String, Uint8List> _nativeActionIcons = const <String, Uint8List>{};
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
    final extra = <ContextMenuButtonItem>[];
    final extraIcons = <String, Uint8List>{};
    if (widget.onPasteRequested != null &&
        !widget.readOnly &&
        !widget.buttonItems
            .any((b) => b.type == ContextMenuButtonType.paste)) {
      try {
        final hasClipboard = await Clipboard.hasStrings();
        if (hasClipboard) {
          extra.add(
            ContextMenuButtonItem(
              type: ContextMenuButtonType.paste,
              label: labels['paste'] ?? 'Paste',
              onPressed: widget.onPasteRequested,
            ),
          );
        }
      } catch (_) {}
    }
    final hasCustomItems =
        widget.buttonItems.any((b) => b.type == ContextMenuButtonType.custom);
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        (widget.selectedText.isNotEmpty || hasCustomItems)) {
      try {
        final raw = await AdwTextSelectionControls._textActionsChannel
            .invokeListMethod<dynamic>('getTextActions');
        if (raw != null) {
          final existingLabels = widget.buttonItems
              .map((b) => (b.label ?? '').toLowerCase())
              .toSet();
          for (final entry in raw) {
            if (entry is! Map) continue;
            final label = entry['label']?.toString() ?? '';
            final pkg = entry['packageName']?.toString() ?? '';
            final cls = entry['className']?.toString() ?? '';
            if (label.isEmpty || pkg.isEmpty || cls.isEmpty) {
              continue;
            }
            final lowerLabel = label.toLowerCase();
            final rawIcon = entry['iconBytes'];
            if (rawIcon is Uint8List && rawIcon.isNotEmpty) {
              extraIcons[lowerLabel] = rawIcon;
            }
            if (widget.selectedText.isEmpty ||
                existingLabels.contains(lowerLabel)) {
              continue;
            }
            existingLabels.add(lowerLabel);
            extra.add(
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
        }
      } catch (_) {
        // Ignore if runner does not implement getTextActions.
      }
    }
    if (!mounted) return;
    if (labels != _labels || extra.isNotEmpty || extraIcons.isNotEmpty) {
      setState(() {
        _labels = labels;
        _nativeExtraItems = extra;
        _nativeActionIcons = extraIcons;
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

  static _AdwTouchIconKind _iconKindFor(ContextMenuButtonItem item) {
    if (item.type == ContextMenuButtonType.custom &&
        item.label == 'Insert Emoji') {
      return _AdwTouchIconKind.insertEmoji;
    }
    switch (item.type) {
      case ContextMenuButtonType.cut:
        return _AdwTouchIconKind.cut;
      case ContextMenuButtonType.copy:
        return _AdwTouchIconKind.copy;
      case ContextMenuButtonType.paste:
        return _AdwTouchIconKind.paste;
      case ContextMenuButtonType.selectAll:
        return _AdwTouchIconKind.selectAll;
      case ContextMenuButtonType.share:
        return _AdwTouchIconKind.share;
      case ContextMenuButtonType.searchWeb:
      case ContextMenuButtonType.lookUp:
        return _AdwTouchIconKind.search;
      case ContextMenuButtonType.delete:
      case ContextMenuButtonType.liveTextInput:
      case ContextMenuButtonType.custom:
        final lower = (item.label ?? '').toLowerCase();
        if (lower.contains('traduc') || lower.contains('translat')) {
          return _AdwTouchIconKind.translate;
        }
        if (lower.contains('leer') ||
            lower.contains('voz') ||
            lower.contains('read') ||
            lower.contains('speak')) {
          return _AdwTouchIconKind.readAloud;
        }
        if (lower.contains('buscar') || lower.contains('search')) {
          return _AdwTouchIconKind.search;
        }
        return _AdwTouchIconKind.externalAction;
    }
  }

  /// Authentic Libadwaita `popover.touch-selection` OSD surface:
  /// dark OSD popover with pointing arrow and a `.linked` bar of symbolic icon
  /// buttons (`Cut`, `Copy`, `Paste`, `Select All`, `Insert Emoji`, `Share`,
  /// and Android `ACTION_PROCESS_TEXT` actions with their native icons),
  /// capped at 5 visible items (`194px`) with smooth horizontal scrolling.
  static Widget _buildTouchSelectionPopoverSurface(
    BuildContext context, {
    required List<ContextMenuButtonItem> items,
    required Map<String, String> labels,
    Map<String, Uint8List> nativeIcons = const <String, Uint8List>{},
    required AdwPopoverArrowSide arrowSide,
    VoidCallback? onDismissPopup,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    // 5 buttons * 38px + 4 dividers * 1px = 194px visible before scrolling.
    const double maxVisibleBarWidth = 5 * 38.0 + 4 * 1.0;

    final iconItems = <(ContextMenuButtonItem, _AdwTouchIconKind)>[
      for (final item in items) (item, _iconKindFor(item)),
    ];

    return TextFieldTapRegion(
      child: AdwPopoverSurface(
        isOsd: true,
        arrowSide: arrowSide,
        padding: const EdgeInsets.all(10.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxVisibleBarWidth),
          child: SizedBox(
            height: 34.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF35353A),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: PrimaryScrollController.none(
                  child: RawScrollbar(
                    interactive: false,
                    padding: EdgeInsets.zero,
                    scrollbarOrientation: ScrollbarOrientation.bottom,
                    thickness: 2.0,
                    radius: const Radius.circular(1.0),
                    thumbColor: const Color(0x66FFFFFF),
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < iconItems.length; i++) ...[
                              if (i > 0)
                                Container(
                                  width: 1,
                                  height: 34,
                                  color: const Color(0xFF45454B),
                                ),
                              _AdwTouchIconButton(
                                kind: iconItems[i].$2,
                                nativeIconBytes:
                                    iconItems[i].$1.type ==
                                                ContextMenuButtonType.custom &&
                                            iconItems[i].$2 !=
                                                _AdwTouchIconKind.readAloud
                                        ? nativeIcons[
                                            (iconItems[i].$1.label ?? '')
                                                .toLowerCase()]
                                        : null,
                                semanticLabel:
                                    _labelFor(iconItems[i].$1, labels),
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
                  ),
                ),
              ),
            ),
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final visibleBottom = screenSize.height - bottomInset;
    final maxWidth = math.max(180.0, screenSize.width - 16.0);
    final rawAnchorBelow =
        widget.anchors.secondaryAnchor ?? widget.anchors.primaryAnchor;
    // Clear the selection handles below the text baseline without leaving
    // extra empty space below the input.
    const double handleClearance = 14.0;
    final anchorBelow = Offset(
      rawAnchorBelow.dx,
      rawAnchorBelow.dy + handleClearance,
    );
    final placeAbove = anchorBelow.dy + 76.0 > visibleBottom;
    final arrowSide =
        placeAbove ? AdwPopoverArrowSide.bottom : AdwPopoverArrowSide.top;

    return CustomSingleChildLayout(
      delegate: _AdwToolbarLayoutDelegate(
        anchorAbove: widget.anchors.primaryAnchor,
        anchorBelow: anchorBelow,
        preferBelow: true,
        bottomInset: bottomInset,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: _buildTouchSelectionPopoverSurface(
          context,
          items: allItems,
          labels: _labels,
          nativeIcons: _nativeActionIcons,
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
  translate,
  readAloud,
  search,
  externalAction,
}

class _AdwTouchIconButton extends StatefulWidget {
  final _AdwTouchIconKind kind;
  final Uint8List? nativeIconBytes;
  final String semanticLabel;
  final VoidCallback? onPressed;

  const _AdwTouchIconButton({
    required this.kind,
    this.nativeIconBytes,
    required this.semanticLabel,
    this.onPressed,
  });

  @override
  State<_AdwTouchIconButton> createState() => _AdwTouchIconButtonState();
}

class _AdwTouchIconButtonState extends State<_AdwTouchIconButton> {
  static const List<double> _kMonochromeMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      0.9, 0,
  ];

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
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => AdwTextSelectionControls._markToolbarPointerDown(),
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
              child: widget.nativeIconBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(3.5),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix(_kMonochromeMatrix),
                        child: Image.memory(
                          widget.nativeIconBytes!,
                          width: 16,
                          height: 16,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    )
                  : CustomPaint(
                      size: const Size(16, 16),
                      painter: _AdwTouchSymbolicIconPainter(
                        kind: widget.kind,
                        color: const Color(0xE6FFFFFF),
                      ),
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
      case _AdwTouchIconKind.translate:
        // Stylized 'A' + globe/script strokes for Translate.
        canvas.drawLine(const Offset(2.0, 4.0), const Offset(8.5, 4.0), stroke);
        canvas.drawLine(const Offset(5.2, 2.2), const Offset(5.2, 4.0), stroke);
        canvas.drawLine(const Offset(7.2, 4.0), const Offset(3.2, 10.5), stroke);
        canvas.drawLine(const Offset(3.5, 6.2), const Offset(7.5, 10.2), stroke);
        canvas.drawLine(const Offset(8.8, 13.5), const Offset(11.3, 7.0), stroke);
        canvas.drawLine(const Offset(13.8, 13.5), const Offset(11.3, 7.0), stroke);
        canvas.drawLine(const Offset(9.7, 11.5), const Offset(12.9, 11.5), stroke);
      case _AdwTouchIconKind.readAloud:
        // Speaker cone + sound wave arcs.
        final speaker = Path()
          ..moveTo(2.0, 6.2)
          ..lineTo(4.8, 6.2)
          ..lineTo(8.2, 3.2)
          ..lineTo(8.2, 12.8)
          ..lineTo(4.8, 9.8)
          ..lineTo(2.0, 9.8)
          ..close();
        canvas.drawPath(speaker, fill);
        canvas.drawArc(
          const Rect.fromLTWH(8.5, 5.2, 3.2, 5.6),
          -math.pi / 3,
          2 * math.pi / 3,
          false,
          stroke,
        );
        canvas.drawArc(
          const Rect.fromLTWH(9.5, 3.0, 5.0, 10.0),
          -math.pi / 3,
          2 * math.pi / 3,
          false,
          stroke,
        );
      case _AdwTouchIconKind.search:
        canvas.drawCircle(const Offset(7.0, 7.0), 4.5, stroke);
        canvas.drawLine(const Offset(10.4, 10.4), const Offset(14.0, 14.0), stroke);
      case _AdwTouchIconKind.externalAction:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2.2, 4.2, 9.6, 9.6),
            const Radius.circular(1.8),
          ),
          stroke,
        );
        canvas.drawLine(const Offset(7.8, 8.2), const Offset(13.5, 2.5), stroke);
        canvas.drawLine(const Offset(9.8, 2.5), const Offset(13.5, 2.5), stroke);
        canvas.drawLine(const Offset(13.5, 2.5), const Offset(13.5, 6.2), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _AdwTouchSymbolicIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

/// Libadwaita `popover.magnifier` lens for touch text selection.
/// Displays a crisp `2.0×` vector-rendered text lens (matching GTK4's
/// `GtkMagnifier` at `100×60` @ `2.0×`, `padding: 8px`, `border-radius: 12px`,
/// `18×9` arrow = `116×85 px` total) when attached to an [EditableText],
/// falling back to [RawMagnifier] for non-editable selectable content.
///
/// Aligns the bottom arrow tip with the top border of the enclosing
/// [AdwInputBounds] whenever there is enough room above (`anchorTop >= 85px`),
/// and automatically flips below (`arrowOnTop: true`, top arrow tip aligned
/// with `inputBounds.bottom`) when the input sits near the top of the window.
class _AdwTextMagnifier extends StatefulWidget {
  final ValueNotifier<MagnifierInfo> magnifierInfo;
  final Rect? Function()? resolveInputBounds;
  final EditableTextState? Function()? resolveEditableText;

  const _AdwTextMagnifier({
    required this.magnifierInfo,
    this.resolveInputBounds,
    this.resolveEditableText,
  });

  // Exact GTK4 `gtk_text_ensure_magnifier` (`100×60` @ `2.0×`) + Libadwaita
  // `popover.magnifier` (`padding: 8px`, `border-radius: 12px`, `18×9` arrow).
  static const double _kLensWidth = 100.0;
  static const double _kLensHeight = 60.0;
  static const double _kPadding = 8.0;
  static const double _kArrowWidth = 18.0;
  static const double _kArrowHeight = 9.0;
  static const double _kOuterRadius = 12.0;
  static const double _kLensRadius = 0.0;
  static const double _kScale = 2.0;
  static const double _kTotalWidth = _kLensWidth + _kPadding * 2;
  static const double _kTotalHeight =
      _kLensHeight + _kPadding * 2 + _kArrowHeight;

  @override
  State<_AdwTextMagnifier> createState() => _AdwTextMagnifierState();
}

class _AdwTextMagnifierState extends State<_AdwTextMagnifier> {
  static bool _nativeLinuxMagnifierUnsupported = false;
  bool _nativeMagnifierActive = false;
  double? _lastGestureX;
  int _preferredSide = 0; // -1 = left of finger, 1 = right of finger, 0 = unset

  bool get _canUseNativeLinuxMagnifier =>
      !_nativeLinuxMagnifierUnsupported &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.linux &&
      widget.resolveEditableText != null;

  @override
  void dispose() {
    if (_nativeMagnifierActive) {
      _nativeMagnifierActive = false;
      AdwTextSelectionControls._textActionsChannel
          .invokeMethod<void>('hideMagnifier')
          .catchError((_) {});
    }
    super.dispose();
  }

  static int _activeCaretOffset(
    EditableTextState editableState,
    double targetX,
    int maxLength,
  ) {
    final sel = editableState.textEditingValue.selection;
    if (!sel.isValid) return maxLength;
    final base = sel.baseOffset.clamp(0, maxLength);
    final extent = sel.extentOffset.clamp(0, maxLength);
    if (base == extent) return extent;
    try {
      final render = editableState.renderEditable;
      final baseGlobalX = render
          .localToGlobal(
            render.getLocalRectForCaret(TextPosition(offset: base)).center,
          )
          .dx;
      final extentGlobalX = render
          .localToGlobal(
            render.getLocalRectForCaret(TextPosition(offset: extent)).center,
          )
          .dx;
      return (targetX - baseGlobalX).abs() < (targetX - extentGlobalX).abs()
          ? base
          : extent;
    } catch (_) {
      return extent;
    }
  }

  void _syncNativeLinuxMagnifier(
    BuildContext context,
    MagnifierInfo info,
    double targetX,
    double anchorTop,
    EditableTextState editableState,
    Color lensBg,
  ) {
    final w = editableState.widget;
    final val = editableState.textEditingValue;
    final displayText =
        w.obscureText ? w.obscuringCharacter * val.text.length : val.text;
    final sel = val.selection;
    final hasSel = sel.isValid && !sel.isCollapsed;
    final activeOffset =
        _activeCaretOffset(editableState, targetX, displayText.length);
    final selStart = sel.isValid ? sel.start.clamp(0, displayText.length) : 0;
    final selEnd = sel.isValid ? sel.end.clamp(0, displayText.length) : 0;
    final textColor = (w.style.color ?? const Color(0xFFFFFFFF)).toARGB32();
    final selColor =
        (w.selectionColor ?? const Color(0x4D3584E4)).toARGB32();
    final cursorColor = w.cursorColor.toARGB32();

    AdwTextSelectionControls._textActionsChannel
        .invokeMethod<bool>('updateMagnifier', <String, Object>{
      'x': targetX,
      'y': anchorTop,
      'text': displayText,
      'fontFamily': w.style.fontFamily ?? 'Sans',
      'fontSize': w.style.fontSize ?? 14.0,
      'caretIndex': activeOffset,
      'selectionStart': selStart,
      'selectionEnd': selEnd,
      'hasSelection': hasSel,
      'textColor': textColor,
      'bgColor': lensBg.toARGB32(),
      'selectionColor': selColor,
      'cursorColor': cursorColor,
    }).then((ok) {
      if (!mounted) return;
      if (ok == true) {
        if (!_nativeMagnifierActive) {
          setState(() => _nativeMagnifierActive = true);
        }
      } else {
        _nativeLinuxMagnifierUnsupported = true;
        if (_nativeMagnifierActive) {
          setState(() => _nativeMagnifierActive = false);
        }
      }
    }).catchError((_) {
      _nativeLinuxMagnifierUnsupported = true;
      if (mounted && _nativeMagnifierActive) {
        setState(() => _nativeMagnifierActive = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final bool isAndroidSideMagnifier =
        defaultTargetPlatform == TargetPlatform.android;
    const double arrowH = _AdwTextMagnifier._kArrowHeight;
    final double lensWidth =
        isAndroidSideMagnifier ? 76.0 : _AdwTextMagnifier._kLensWidth;
    final double lensHeight =
        isAndroidSideMagnifier ? 44.0 : _AdwTextMagnifier._kLensHeight;
    final double padding =
        isAndroidSideMagnifier ? 6.0 : _AdwTextMagnifier._kPadding;
    final double totalWidth =
        isAndroidSideMagnifier ? lensWidth + padding * 2 + arrowH : _AdwTextMagnifier._kTotalWidth;
    final double totalHeight =
        isAndroidSideMagnifier ? lensHeight + padding * 2 : _AdwTextMagnifier._kTotalHeight;
    const outerRadius = _AdwTextMagnifier._kOuterRadius;
    const arrowWidth = _AdwTextMagnifier._kArrowWidth;
    const scale = _AdwTextMagnifier._kScale;

    return ValueListenableBuilder<MagnifierInfo>(
      valueListenable: widget.magnifierInfo,
      builder: (context, info, _) {
        if (info == MagnifierInfo.empty) {
          _lastGestureX = null;
          _preferredSide = 0;
          return const SizedBox.shrink();
        }
        final bool hasCaretPosition = info.caretRect != Rect.zero;
        final double rawTargetX = hasCaretPosition
            ? info.caretRect.center.dx
            : info.globalGesturePosition.dx;
        final Rect horizontalBounds = !info.currentLineBoundaries.isEmpty
            ? info.currentLineBoundaries
            : info.fieldBounds;
        final targetX = rawTargetX
            .clamp(
              horizontalBounds.isEmpty ? 0.0 : horizontalBounds.left,
              horizontalBounds.isEmpty
                  ? screenSize.width
                  : horizontalBounds.right,
            )
            .toDouble();
        final double rawTargetY = hasCaretPosition
            ? info.caretRect.center.dy
            : (!info.currentLineBoundaries.isEmpty
                ? info.currentLineBoundaries.center.dy
                : info.globalGesturePosition.dy);
        final double targetY = !info.fieldBounds.isEmpty
            ? rawTargetY
                .clamp(info.fieldBounds.top, info.fieldBounds.bottom)
                .toDouble()
            : rawTargetY;

        final EditableTextState? editableState =
            widget.resolveEditableText?.call();

        final double left;
        if (defaultTargetPlatform == TargetPlatform.android) {
          const double edgeMargin = 8.0;
          const double fingerGap = 24.0;
          final double fingerX = info.globalGesturePosition.dx;
          final double dx =
              _lastGestureX != null ? fingerX - _lastGestureX! : 0.0;
          _lastGestureX = fingerX;

          final double leftSpace = fingerX - fingerGap - edgeMargin;
          final double rightSpace =
              (screenSize.width - edgeMargin) - (fingerX + fingerGap);
          final bool hasLeftSpace = leftSpace >= totalWidth;
          final bool hasRightSpace = rightSpace >= totalWidth;

          int desiredSide = 0;
          if (dx > 1.5) {
            desiredSide = -1; // Swiping right -> place magnifier on the left
          } else if (dx < -1.5) {
            desiredSide = 1; // Swiping left -> place magnifier on the right
          }

          if (_preferredSide == 0) {
            if (desiredSide == -1) {
              _preferredSide = hasLeftSpace ? -1 : 1;
            } else if (desiredSide == 1) {
              _preferredSide = hasRightSpace ? 1 : -1;
            } else {
              _preferredSide = leftSpace >= rightSpace ? -1 : 1;
            }
          } else if (desiredSide != 0 && desiredSide != _preferredSide) {
            // Only switch to the opposite side once there is enough room.
            if ((desiredSide == -1 && hasLeftSpace) ||
                (desiredSide == 1 && hasRightSpace)) {
              _preferredSide = desiredSide;
            }
          }

          final double desiredLeft = _preferredSide == -1
              ? fingerX - fingerGap - totalWidth
              : fingerX + fingerGap;
          left = desiredLeft
              .clamp(
                edgeMargin,
                math.max(edgeMargin, screenSize.width - totalWidth - edgeMargin),
              )
              .toDouble();
        } else {
          left = (targetX - totalWidth / 2)
              .clamp(
                8.0,
                math.max(8.0, screenSize.width - totalWidth - 8.0),
              )
              .toDouble();
        }

        final Rect? inputBounds = widget.resolveInputBounds?.call();
        final double anchorTop = inputBounds != null
            ? inputBounds.top
            : (!info.caretRect.isEmpty
                ? info.caretRect.top - 4.0
                : info.globalGesturePosition.dy - 14.0);

        final theme = AdwTheme.maybeOf(context);
        final Color lensBg =
            theme?.colors.windowBackground ?? const Color(0xFF222226);

        if (_canUseNativeLinuxMagnifier &&
            editableState != null &&
            editableState.mounted) {
          _syncNativeLinuxMagnifier(
            context,
            info,
            targetX,
            anchorTop,
            editableState,
            lensBg,
          );
          if (_nativeMagnifierActive) {
            return const SizedBox.shrink(
              key: AdwTextSelectionControls.magnifierKey,
            );
          }
        }

        final double boxWidth = totalWidth;
        final double boxHeight = totalHeight;
        final _MagnifierArrowSide arrowSide = isAndroidSideMagnifier
            ? (_preferredSide == -1
                ? _MagnifierArrowSide.right
                : _MagnifierArrowSide.left)
            : _MagnifierArrowSide.bottom;

        final double top = isAndroidSideMagnifier
            ? (targetY - boxHeight / 2)
                .clamp(
                  8.0,
                  math.max(8.0, screenSize.height - boxHeight - 8.0),
                )
                .toDouble()
            : (anchorTop - boxHeight)
                .clamp(
                  0.0,
                  math.max(0.0, screenSize.height - boxHeight - 4.0),
                )
                .toDouble();

        final double arrowOffset = isAndroidSideMagnifier
            ? (targetY - top)
                .clamp(
                  outerRadius + arrowWidth / 2 + 2.0,
                  boxHeight - outerRadius - arrowWidth / 2 - 2.0,
                )
                .toDouble()
            : (targetX - left)
                .clamp(
                  outerRadius + arrowWidth / 2 + 2.0,
                  boxWidth - outerRadius - arrowWidth / 2 - 2.0,
                )
                .toDouble();

        final double lensLeftInWidget =
            arrowSide == _MagnifierArrowSide.left ? padding + arrowH : padding;
        final double lensTopInWidget = padding;
        final lensCenterGlobal = Offset(
          left + lensLeftInWidget + lensWidth / 2,
          top + lensTopInWidget + lensHeight / 2,
        );
        final focalOffset = Offset(targetX, targetY) - lensCenterGlobal;

        final Widget lensContent = editableState != null && editableState.mounted
            ? CustomPaint(
                size: Size(lensWidth, lensHeight),
                painter: _AdwVectorTextMagnifierPainter(
                  editableState: editableState,
                  textDirection: Directionality.of(context),
                  backgroundColor: lensBg,
                  scale: scale,
                  activeOffset: _activeCaretOffset(
                    editableState,
                    targetX,
                    editableState.textEditingValue.text.length,
                  ),
                ),
              )
            : RawMagnifier(
                size: Size(lensWidth, lensHeight),
                magnificationScale: scale,
                focalPointOffset: focalOffset,
                decoration: const MagnifierDecoration(),
              );

        return Positioned(
          key: AdwTextSelectionControls.magnifierKey,
          left: left,
          top: top,
          child: IgnorePointer(
            child: SizedBox(
              width: boxWidth,
              height: boxHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: lensLeftInWidget,
                    top: lensTopInWidget,
                    child: ClipRect(child: lensContent),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _AdwMagnifierFramePainter(
                        lensRect: Rect.fromLTWH(
                          lensLeftInWidget,
                          lensTopInWidget,
                          lensWidth,
                          lensHeight,
                        ),
                        arrowSide: arrowSide,
                        arrowCenter: arrowOffset,
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

class _AdwVectorTextMagnifierPainter extends CustomPainter {
  final EditableTextState editableState;
  final TextDirection textDirection;
  final Color backgroundColor;
  final double scale;
  final int activeOffset;

  const _AdwVectorTextMagnifierPainter({
    required this.editableState,
    required this.textDirection,
    required this.backgroundColor,
    required this.scale,
    required this.activeOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fill lens with crisp input background color.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = backgroundColor,
    );

    final widget = editableState.widget;
    final value = editableState.textEditingValue;
    final rawText = value.text;
    final displayText = widget.obscureText
        ? widget.obscuringCharacter * rawText.length
        : rawText;

    final baseStyle = widget.style;
    final scaledStyle = baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 14.0) * scale,
    );

    final painter = TextPainter(
      text: TextSpan(text: displayText, style: scaledStyle),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();

    final sel = value.selection;
    final clampedActive = activeOffset.clamp(0, displayText.length);

    final caretOffset = painter.getOffsetForCaret(
      TextPosition(offset: clampedActive),
      Rect.zero,
    );

    final dx = size.width / 2 - caretOffset.dx;
    final dy = (size.height - painter.height) / 2;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(dx, dy);

    // 2. Paint selection highlight boxes at 2.0x vector resolution (matching
    //    GTK4's full vertical selection band inside the 60px lens).
    if (sel.isValid && !sel.isCollapsed) {
      final selColor = widget.selectionColor;
      if (selColor != null) {
        final boxes = painter.getBoxesForSelection(
          TextSelection(
            baseOffset: sel.baseOffset.clamp(0, displayText.length),
            extentOffset: sel.extentOffset.clamp(0, displayText.length),
          ),
        );
        final selPaint = Paint()..color = selColor;
        const double verticalPad = 6.0;
        for (final box in boxes) {
          final rect = box.toRect();
          canvas.drawRect(
            Rect.fromLTRB(
              rect.left,
              rect.top - verticalPad,
              rect.right,
              rect.bottom + verticalPad,
            ),
            selPaint,
          );
        }
      }
    }

    // 3. Paint crisp 2.0x vector text.
    painter.paint(canvas, Offset.zero);

    // 4. Paint crisp 2.0x caret bar ONLY when selection is collapsed
    //    (matching GTK4, which hides the caret line while a range is selected).
    if (!sel.isValid || sel.isCollapsed) {
      final caretHeight = painter.preferredLineHeight;
      final caretWidth = math.max(1.5, widget.cursorWidth * scale);
      canvas.drawRect(
        Rect.fromLTWH(
          caretOffset.dx - caretWidth / 2,
          caretOffset.dy,
          caretWidth,
          caretHeight,
        ),
        Paint()..color = widget.cursorColor,
      );
    }

    canvas.restore();
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _AdwVectorTextMagnifierPainter oldDelegate) =>
      true;
}

enum _MagnifierArrowSide { top, bottom, left, right }

class _AdwMagnifierFramePainter extends CustomPainter {
  final Rect lensRect;
  final _MagnifierArrowSide arrowSide;
  final double arrowCenter;

  const _AdwMagnifierFramePainter({
    required this.lensRect,
    required this.arrowSide,
    required this.arrowCenter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double arrowW = _AdwTextMagnifier._kArrowWidth;
    const double arrowH = _AdwTextMagnifier._kArrowHeight;
    const double outerR = _AdwTextMagnifier._kOuterRadius;
    const double lensR = _AdwTextMagnifier._kLensRadius;

    final double bodyLeft = arrowSide == _MagnifierArrowSide.left ? arrowH : 0.0;
    final double bodyRight =
        arrowSide == _MagnifierArrowSide.right ? size.width - arrowH : size.width;
    final double bodyTop = arrowSide == _MagnifierArrowSide.top ? arrowH : 0.0;
    final double bodyBottom =
        arrowSide == _MagnifierArrowSide.bottom ? size.height - arrowH : size.height;
    final outerRect = Rect.fromLTRB(bodyLeft, bodyTop, bodyRight, bodyBottom);

    Path outerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(outerRect, const Radius.circular(outerR)));

    final halfW = arrowW / 2;
    switch (arrowSide) {
      case _MagnifierArrowSide.top:
        final arrow = Path()
          ..moveTo(arrowCenter - halfW, bodyTop + 1)
          ..lineTo(arrowCenter, 0)
          ..lineTo(arrowCenter + halfW, bodyTop + 1)
          ..close();
        outerPath = Path.combine(PathOperation.union, outerPath, arrow);
      case _MagnifierArrowSide.bottom:
        final arrow = Path()
          ..moveTo(arrowCenter - halfW, bodyBottom - 1)
          ..lineTo(arrowCenter, size.height)
          ..lineTo(arrowCenter + halfW, bodyBottom - 1)
          ..close();
        outerPath = Path.combine(PathOperation.union, outerPath, arrow);
      case _MagnifierArrowSide.left:
        final arrow = Path()
          ..moveTo(bodyLeft + 1, arrowCenter - halfW)
          ..lineTo(0, arrowCenter)
          ..lineTo(bodyLeft + 1, arrowCenter + halfW)
          ..close();
        outerPath = Path.combine(PathOperation.union, outerPath, arrow);
      case _MagnifierArrowSide.right:
        final arrow = Path()
          ..moveTo(bodyRight - 1, arrowCenter - halfW)
          ..lineTo(size.width, arrowCenter)
          ..lineTo(bodyRight - 1, arrowCenter + halfW)
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
        ..color = const Color(0xCC000000) // Libadwaita OSD RGB(0 0 0 / 80%)
        ..style = PaintingStyle.fill,
    );

    // Subtle 1px rim around outer popover only (`box-shadow: 0 0 1px RGB(255 255 255 / 10%)`).
    canvas.drawPath(
      outerPath,
      Paint()
        ..color = const Color(0x1AFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _AdwMagnifierFramePainter oldDelegate) =>
      oldDelegate.lensRect != lensRect ||
      oldDelegate.arrowSide != arrowSide ||
      oldDelegate.arrowCenter != arrowCenter;
}

class _AdwToolbarLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset anchorAbove;
  final Offset anchorBelow;
  final bool preferBelow;
  final double bottomInset;

  const _AdwToolbarLayoutDelegate({
    required this.anchorAbove,
    required this.anchorBelow,
    this.preferBelow = false,
    this.bottomInset = 0.0,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const double margin = 8.0;
    const double gap = 2.0;
    final double visibleHeight = math.max(0.0, size.height - bottomInset);
    final double dx = (anchorAbove.dx - childSize.width / 2).clamp(
      margin,
      math.max(margin, size.width - childSize.width - margin),
    );
    double dy;
    if (preferBelow) {
      dy = anchorBelow.dy + gap;
      if (dy + childSize.height > visibleHeight - margin) {
        dy = (anchorAbove.dy - childSize.height - gap).clamp(
          margin,
          math.max(margin, visibleHeight - childSize.height - margin),
        );
      }
    } else {
      dy = anchorAbove.dy - childSize.height - gap;
      if (dy < margin) {
        dy = (anchorBelow.dy + gap).clamp(
          margin,
          math.max(margin, visibleHeight - childSize.height - margin),
        );
      }
    }
    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(covariant _AdwToolbarLayoutDelegate oldDelegate) {
    return anchorAbove != oldDelegate.anchorAbove ||
        anchorBelow != oldDelegate.anchorBelow ||
        preferBelow != oldDelegate.preferBelow ||
        bottomInset != oldDelegate.bottomInset;
  }
}

/// Reusable [SelectableRegion] wrapper with consistent Adwaita styling,
/// teardrop touch handles, OSD touch selection toolbar, vertical desktop
/// popover menu, touch magnifier, and tap-outside unfocus handling.
class AdwSelectableRegion extends StatefulWidget {
  final Widget child;
  final FocusNode? focusNode;

  /// Whether to show the touch selection toolbar on Linux touchscreens.
  ///
  /// Defaults to `false` to match native GTK4 / Libadwaita behavior, where
  /// non-input selectable text does not open a touch selection popover on
  /// Linux (mouse right-click still opens the vertical desktop popover menu).
  /// On Android and iOS the touch selection toolbar is always shown.
  final bool enableLinuxTouchMenu;

  const AdwSelectableRegion({
    super.key,
    required this.child,
    this.focusNode,
    this.enableLinuxTouchMenu = false,
  });

  @override
  State<AdwSelectableRegion> createState() => _AdwSelectableRegionState();
}

class _AdwSelectableRegionState extends State<AdwSelectableRegion> {
  FocusNode? _internalFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.maybeOf(context);
    final accentColor = theme?.colors.accentColor ?? AdwColors.accentBlue;
    final hasOverlay = Overlay.maybeOf(context) != null;

    return DefaultSelectionStyle(
      selectionColor: accentColor.withValues(alpha: 0.3),
      cursorColor: accentColor,
      child: TextFieldTapRegion(
        onTapOutside: (_) {
          if (AdwTextSelectionControls._isRecentToolbarPointerDown) {
            return;
          }
          if (_focusNode.hasFocus) {
            _focusNode.unfocus();
          }
        },
        child: SelectableRegion(
          focusNode: _focusNode,
          selectionControls: AdwTextSelectionControls.forPlatform(context),
          contextMenuBuilder: hasOverlay
              ? (ctx, state) =>
                  AdwTextSelectionControls.selectableContextMenuBuilder(
                    ctx,
                    state,
                    enableLinuxTouchMenu: widget.enableLinuxTouchMenu,
                  )
              : null,
          magnifierConfiguration: hasOverlay
              ? AdwTextSelectionControls.magnifierConfiguration
              : TextMagnifierConfiguration.disabled,
          child: widget.child,
        ),
      ),
    );
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
  PointerDeviceKind _lastPointerKind = PointerDeviceKind.mouse;

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
      resolveEditableText: () => editableTextKey.currentState,
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
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          _lastPointerKind = event.kind;
        },
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
            scrollPadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 96.0),
            selectionControls:
                hasOverlay ? AdwTextSelectionControls.forPlatform(context) : null,
            contextMenuBuilder: hasOverlay
                ? (ctx, state) => AdwTextSelectionControls.contextMenuBuilder(
                      ctx,
                      state,
                      isTouch: _lastPointerKind == PointerDeviceKind.touch ||
                          _lastPointerKind == PointerDeviceKind.stylus,
                    )
                : null,
          magnifierConfiguration: hasOverlay
              ? _magnifierConfiguration
              : TextMagnifierConfiguration.disabled,
          obscureText: widget.obscureText,
          readOnly: widget.readOnly,
          keyboardType: widget.keyboardType ?? TextInputType.text,
          inputFormatters: widget.inputFormatters,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          onTapOutside: widget.onTapOutside == null
              ? null
              : (event) {
                  if (AdwTextSelectionControls._isRecentToolbarPointerDown) {
                    return;
                  }
                  widget.onTapOutside!(event);
                },
        ),
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
