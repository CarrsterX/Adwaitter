import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'adw_clamp.dart';

/// Controls how children are distributed along each line in [AdwWrapBox].
///
/// {@category Layout}
enum AdwJustifyMode {
  /// No extra justification; leftover space is positioned according to `align`.
  none,

  /// Stretches children evenly to fill the available line length.
  fill,

  /// Distributes leftover space evenly between children on each line.
  spread,
}

/// Packing direction within each line of an [AdwWrapBox].
///
/// {@category Layout}
enum AdwPackDirection {
  /// Packs children from start to end (e.g. left to right in LTR).
  startToEnd,

  /// Packs children from end to start.
  endToStart,
}

/// Line-breaking policy for [AdwWrapBox].
///
/// {@category Layout}
enum AdwWrapPolicy {
  /// Wraps only when children would otherwise overflow the available size.
  minimum,

  /// Wraps based on each child's natural size.
  natural,
}

/// A box-like container that wraps its children into multiple lines (`AdwWrapBox`).
///
/// Mirrors Libadwaita's `AdwWrapBox` / `AdwWrapLayout`, supporting horizontal
/// or vertical orientation, child and line spacing with [AdwLengthUnit],
/// justification modes, line alignment, homogeneous line sizing, and reverse
/// packing or wrapping.
///
/// ```dart
/// const AdwWrapBox(
///   childSpacing: 6,
///   lineSpacing: 6,
///   children: [
///     AdwButton(child: Text('Tag 1')),
///     AdwButton(child: Text('Tag 2')),
///   ],
/// )
/// ```
///
/// See also:
///
/// * [AdwJustifyMode], [AdwPackDirection], and [AdwWrapPolicy].
///
/// {@category Layout}
class AdwWrapBox extends StatelessWidget {
  /// Child widgets laid out across wrapped lines.
  final List<Widget> children;

  /// Primary flow axis. Defaults to [Axis.horizontal].
  final Axis orientation;

  /// Spacing between adjacent children on the same line. Defaults to `0.0`.
  final double childSpacing;

  /// Length unit for [childSpacing]. Defaults to [AdwLengthUnit.px].
  final AdwLengthUnit childSpacingUnit;

  /// Spacing between consecutive wrapped lines. Defaults to `0.0`.
  final double lineSpacing;

  /// Length unit for [lineSpacing]. Defaults to [AdwLengthUnit.px].
  final AdwLengthUnit lineSpacingUnit;

  /// Normalized alignment (`0.0` start, `0.5` center, `1.0` end) when
  /// [justify] is [AdwJustifyMode.none]. Defaults to `0.0`.
  final double align;

  /// How remaining space on each line is distributed. Defaults to [AdwJustifyMode.none].
  final AdwJustifyMode justify;

  /// Whether [justify] also applies to the final line. Defaults to `false`.
  final bool justifyLastLine;

  /// Direction in which children are packed within each line.
  final AdwPackDirection packDirection;

  /// Whether all lines share the same cross-axis thickness. Defaults to `false`.
  final bool lineHomogeneous;

  /// Whether wrapped lines stack in reverse cross-axis order. Defaults to `false`.
  final bool wrapReverse;

  /// Line-breaking strategy. Defaults to [AdwWrapPolicy.natural].
  final AdwWrapPolicy wrapPolicy;

  /// Creates a Libadwaita wrapping box layout.
  const AdwWrapBox({
    super.key,
    this.children = const <Widget>[],
    this.orientation = Axis.horizontal,
    this.childSpacing = 0.0,
    this.childSpacingUnit = AdwLengthUnit.px,
    this.lineSpacing = 0.0,
    this.lineSpacingUnit = AdwLengthUnit.px,
    this.align = 0.0,
    this.justify = AdwJustifyMode.none,
    this.justifyLastLine = false,
    this.packDirection = AdwPackDirection.startToEnd,
    this.lineHomogeneous = false,
    this.wrapReverse = false,
    this.wrapPolicy = AdwWrapPolicy.natural,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.maybeTextScalerOf(context)?.scale(1.0) ?? 1.0;
    final effectiveChildSpacing = adwLengthUnitToPx(
      childSpacingUnit,
      childSpacing,
      textScale: textScale,
    );
    final effectiveLineSpacing = adwLengthUnitToPx(
      lineSpacingUnit,
      lineSpacing,
      textScale: textScale,
    );
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;

    return _AdwWrapRenderObjectWidget(
      orientation: orientation,
      childSpacing: effectiveChildSpacing,
      lineSpacing: effectiveLineSpacing,
      align: align.clamp(0.0, 1.0),
      justify: justify,
      justifyLastLine: justifyLastLine,
      packDirection: packDirection,
      lineHomogeneous: lineHomogeneous,
      wrapReverse: wrapReverse,
      textDirection: textDirection,
      children: children,
    );
  }
}

class _AdwWrapRenderObjectWidget extends MultiChildRenderObjectWidget {
  final Axis orientation;
  final double childSpacing;
  final double lineSpacing;
  final double align;
  final AdwJustifyMode justify;
  final bool justifyLastLine;
  final AdwPackDirection packDirection;
  final bool lineHomogeneous;
  final bool wrapReverse;
  final TextDirection textDirection;

  const _AdwWrapRenderObjectWidget({
    required this.orientation,
    required this.childSpacing,
    required this.lineSpacing,
    required this.align,
    required this.justify,
    required this.justifyLastLine,
    required this.packDirection,
    required this.lineHomogeneous,
    required this.wrapReverse,
    required this.textDirection,
    required super.children,
  });

  @override
  _RenderAdwWrapBox createRenderObject(BuildContext context) {
    return _RenderAdwWrapBox(
      orientation: orientation,
      childSpacing: childSpacing,
      lineSpacing: lineSpacing,
      align: align,
      justify: justify,
      justifyLastLine: justifyLastLine,
      packDirection: packDirection,
      lineHomogeneous: lineHomogeneous,
      wrapReverse: wrapReverse,
      textDirection: textDirection,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderAdwWrapBox renderObject) {
    renderObject
      ..orientation = orientation
      ..childSpacing = childSpacing
      ..lineSpacing = lineSpacing
      ..align = align
      ..justify = justify
      ..justifyLastLine = justifyLastLine
      ..packDirection = packDirection
      ..lineHomogeneous = lineHomogeneous
      ..wrapReverse = wrapReverse
      ..textDirection = textDirection;
  }
}

class _WrapParentData extends ContainerBoxParentData<RenderBox> {}

class _WrapLine {
  final List<RenderBox> children = [];
  double mainExtent = 0.0;
  double crossExtent = 0.0;
}

class _RenderAdwWrapBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _WrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _WrapParentData> {
  _RenderAdwWrapBox({
    required Axis orientation,
    required double childSpacing,
    required double lineSpacing,
    required double align,
    required AdwJustifyMode justify,
    required bool justifyLastLine,
    required AdwPackDirection packDirection,
    required bool lineHomogeneous,
    required bool wrapReverse,
    required TextDirection textDirection,
  })  : _orientation = orientation,
        _childSpacing = childSpacing,
        _lineSpacing = lineSpacing,
        _align = align,
        _justify = justify,
        _justifyLastLine = justifyLastLine,
        _packDirection = packDirection,
        _lineHomogeneous = lineHomogeneous,
        _wrapReverse = wrapReverse,
        _textDirection = textDirection;

  Axis _orientation;
  set orientation(Axis value) {
    if (_orientation == value) return;
    _orientation = value;
    markNeedsLayout();
  }

  double _childSpacing;
  set childSpacing(double value) {
    if (_childSpacing == value) return;
    _childSpacing = value;
    markNeedsLayout();
  }

  double _lineSpacing;
  set lineSpacing(double value) {
    if (_lineSpacing == value) return;
    _lineSpacing = value;
    markNeedsLayout();
  }

  double _align;
  set align(double value) {
    if (_align == value) return;
    _align = value;
    markNeedsLayout();
  }

  AdwJustifyMode _justify;
  set justify(AdwJustifyMode value) {
    if (_justify == value) return;
    _justify = value;
    markNeedsLayout();
  }

  bool _justifyLastLine;
  set justifyLastLine(bool value) {
    if (_justifyLastLine == value) return;
    _justifyLastLine = value;
    markNeedsLayout();
  }

  AdwPackDirection _packDirection;
  set packDirection(AdwPackDirection value) {
    if (_packDirection == value) return;
    _packDirection = value;
    markNeedsLayout();
  }

  bool _lineHomogeneous;
  set lineHomogeneous(bool value) {
    if (_lineHomogeneous == value) return;
    _lineHomogeneous = value;
    markNeedsLayout();
  }

  bool _wrapReverse;
  set wrapReverse(bool value) {
    if (_wrapReverse == value) return;
    _wrapReverse = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _WrapParentData) {
      child.parentData = _WrapParentData();
    }
  }

  double _mainSize(Size size) =>
      _orientation == Axis.horizontal ? size.width : size.height;

  double _crossSize(Size size) =>
      _orientation == Axis.horizontal ? size.height : size.width;

  Offset _makeOffset(double main, double cross) => _orientation == Axis.horizontal
      ? Offset(main, cross)
      : Offset(cross, main);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (childCount == 0) return constraints.smallest;

    final mainLimit = _orientation == Axis.horizontal
        ? constraints.maxWidth
        : constraints.maxHeight;
    final childConstraints = _orientation == Axis.horizontal
        ? BoxConstraints(maxWidth: mainLimit)
        : BoxConstraints(maxHeight: mainLimit);

    final lines = <_WrapLine>[];
    var current = _WrapLine();

    RenderBox? child = firstChild;
    while (child != null) {
      final size = child.getDryLayout(childConstraints);
      final cMain = _mainSize(size);
      final cCross = _crossSize(size);
      final nextMain = current.children.isEmpty
          ? cMain
          : current.mainExtent + _childSpacing + cMain;

      if (current.children.isNotEmpty &&
          mainLimit.isFinite &&
          nextMain > mainLimit) {
        lines.add(current);
        current = _WrapLine();
      }
      current.children.add(child);
      current.mainExtent = current.children.length == 1
          ? cMain
          : current.mainExtent + _childSpacing + cMain;
      current.crossExtent = math.max(current.crossExtent, cCross);
      child = childAfter(child);
    }
    if (current.children.isNotEmpty) {
      lines.add(current);
    }

    double maxMain = 0.0;
    double totalCross = 0.0;
    double maxLineCross = 0.0;
    for (final line in lines) {
      maxMain = math.max(maxMain, line.mainExtent);
      maxLineCross = math.max(maxLineCross, line.crossExtent);
    }
    for (var i = 0; i < lines.length; i++) {
      final lineCross = _lineHomogeneous ? maxLineCross : lines[i].crossExtent;
      totalCross += lineCross;
      if (i > 0) totalCross += _lineSpacing;
    }

    final result = _orientation == Axis.horizontal
        ? Size(mainLimit.isFinite ? mainLimit : maxMain, totalCross)
        : Size(totalCross, mainLimit.isFinite ? mainLimit : maxMain);
    return constraints.constrain(result);
  }

  @override
  void performLayout() {
    if (childCount == 0) {
      size = constraints.smallest;
      return;
    }

    final mainLimit = _orientation == Axis.horizontal
        ? constraints.maxWidth
        : constraints.maxHeight;
    final childConstraints = _orientation == Axis.horizontal
        ? BoxConstraints(maxWidth: mainLimit)
        : BoxConstraints(maxHeight: mainLimit);

    final lines = <_WrapLine>[];
    var current = _WrapLine();

    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      final cMain = _mainSize(child.size);
      final cCross = _crossSize(child.size);
      final nextMain = current.children.isEmpty
          ? cMain
          : current.mainExtent + _childSpacing + cMain;

      if (current.children.isNotEmpty &&
          mainLimit.isFinite &&
          nextMain > mainLimit) {
        lines.add(current);
        current = _WrapLine();
      }
      current.children.add(child);
      current.mainExtent = current.children.length == 1
          ? cMain
          : current.mainExtent + _childSpacing + cMain;
      current.crossExtent = math.max(current.crossExtent, cCross);
      child = childAfter(child);
    }
    if (current.children.isNotEmpty) {
      lines.add(current);
    }

    double maxMain = 0.0;
    double maxLineCross = 0.0;
    for (final line in lines) {
      maxMain = math.max(maxMain, line.mainExtent);
      maxLineCross = math.max(maxLineCross, line.crossExtent);
    }

    final containerMain = mainLimit.isFinite ? mainLimit : maxMain;
    double totalCross = 0.0;
    for (var i = 0; i < lines.length; i++) {
      final lineCross = _lineHomogeneous ? maxLineCross : lines[i].crossExtent;
      totalCross += lineCross;
      if (i > 0) totalCross += _lineSpacing;
    }

    size = constraints.constrain(
      _orientation == Axis.horizontal
          ? Size(containerMain, totalCross)
          : Size(totalCross, containerMain),
    );

    final actualMain = _mainSize(size);
    final flipMain = (_orientation == Axis.horizontal &&
            _textDirection == TextDirection.rtl) ^
        (_packDirection == AdwPackDirection.endToStart);

    final orderedLines = _wrapReverse ? lines.reversed.toList() : lines;
    double crossPos = 0.0;

    for (var lineIndex = 0; lineIndex < orderedLines.length; lineIndex++) {
      final line = orderedLines[lineIndex];
      final isLastLogicalLine =
          _wrapReverse ? lineIndex == 0 : lineIndex == orderedLines.length - 1;
      final lineCross = _lineHomogeneous ? maxLineCross : line.crossExtent;
      final shouldJustify = _justify != AdwJustifyMode.none &&
          (!isLastLogicalLine || _justifyLastLine) &&
          line.children.isNotEmpty;

      final leftover = math.max(0.0, actualMain - line.mainExtent);
      double mainPos = 0.0;
      double spacing = _childSpacing;
      double extraPerChild = 0.0;

      if (shouldJustify) {
        if (_justify == AdwJustifyMode.fill) {
          extraPerChild = leftover / line.children.length;
        } else if (_justify == AdwJustifyMode.spread) {
          if (line.children.length > 1) {
            spacing += leftover / (line.children.length - 1);
          } else {
            mainPos = leftover * _align;
          }
        }
      } else {
        mainPos = leftover * _align;
      }

      final childrenInLine =
          flipMain ? line.children.reversed.toList() : line.children;

      for (final item in childrenInLine) {
        if (extraPerChild > 0.0) {
          final targetMain = _mainSize(item.size) + extraPerChild;
          final tightConstraints = _orientation == Axis.horizontal
              ? BoxConstraints.tightFor(width: targetMain)
              : BoxConstraints.tightFor(height: targetMain);
          item.layout(tightConstraints, parentUsesSize: true);
        }

        final itemCross = _crossSize(item.size);
        final crossOffset = crossPos + (lineCross - itemCross) * 0.5;
        final parentData = item.parentData! as _WrapParentData;
        parentData.offset = _makeOffset(mainPos, crossOffset);

        mainPos += _mainSize(item.size) + spacing;
      }

      crossPos += lineCross + _lineSpacing;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }
}
