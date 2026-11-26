import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_metrics.dart';
import '../../theme/adw_theme.dart';
import '../controls/adw_button.dart';
import '../layout/adw_window.dart';

/// Collapsible informational contextual banner (`AdwBanner`).
///
/// Typically placed directly below an [AdwHeaderBar] to notify
/// critical app states (e.g. "No internet connection", "Update available").
class AdwBanner extends StatefulWidget {
  final Widget title;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;
  final bool revealed;
  final bool useSuggestedStyle;

  const AdwBanner({
    super.key,
    required this.title,
    this.buttonLabel,
    this.onButtonPressed,
    this.revealed = true,
    this.useSuggestedStyle = false,
  });

  @override
  State<AdwBanner> createState() => _AdwBannerState();
}

class _AdwBannerState extends State<AdwBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AdwCurves.resolveGlobal(AdwCurves.windowDuration),
      value: widget.revealed ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: AdwCurves.smooth,
    );
  }

  @override
  void didUpdateWidget(covariant AdwBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealed != oldWidget.revealed) {
      if (widget.revealed) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    final isWindowActive = AdwWindowScope.maybeOf(context)?.isActive ?? true;

    return ExcludeFocus(
      excluding: !widget.revealed,
      child: ExcludeSemantics(
        excluding: !widget.revealed,
        child: SizeTransition(
          sizeFactor: _expandAnimation,
      child: AnimatedContainer(
        duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
        curve: AdwCurves.standard,
        width: double.infinity,
        color: isWindowActive
            ? theme.colors.bannerBackground
            : theme.colors.bannerBackdropBackground,
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: AnimatedOpacity(
          duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
          opacity: isWindowActive ? 1.0 : 0.50,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final titleStyle = theme.typography.heading;

              Widget buildButton() => widget.useSuggestedStyle
                  ? AdwButton(
                      style: AdwButtonStyle.suggested,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      onPressed: widget.onButtonPressed,
                      child: Text(
                        widget.buttonLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : _AdwBannerButton(
                      label: widget.buttonLabel!,
                      onPressed: widget.onButtonPressed,
                    );

              if (widget.buttonLabel == null) {
                return Center(
                  child: DefaultTextStyle(
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                    child: widget.title,
                  ),
                );
              }

              // Estimate button width (label + padding + border + gap) to decide layout.
              final textScaler = MediaQuery.textScalerOf(context);
              final buttonPainter = TextPainter(
                text: TextSpan(
                  text: widget.buttonLabel!,
                  style: theme.typography.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                maxLines: 1,
                textScaler: textScaler,
                textDirection: Directionality.of(context),
              )..layout();
              final buttonWidth = buttonPainter.width + 44;

              final titleText =
                  widget.title is Text ? (widget.title as Text).data ?? '' : '';
              final titlePainter = TextPainter(
                text: TextSpan(text: titleText, style: titleStyle),
                maxLines: 1,
                textScaler: textScaler,
                textDirection: Directionality.of(context),
              )..layout();
              final titleWidth = titlePainter.width;

              final maxW = constraints.maxWidth;
              final canCenterTitle =
                  titleWidth + (buttonWidth + 24) * 2 <= maxW;
              final canSingleRow = titleWidth + buttonWidth + 16 <= maxW;

              if (canCenterTitle) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: buttonWidth + 12),
                      child: DefaultTextStyle(
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                        child: widget.title,
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: buildButton(),
                    ),
                  ],
                );
              }

              if (canSingleRow) {
                return Row(
                  children: [
                    Expanded(
                      child: DefaultTextStyle(
                        textAlign: TextAlign.start,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                        child: widget.title,
                      ),
                    ),
                    const SizedBox(width: 12),
                    buildButton(),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle(
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                    child: widget.title,
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: buildButton(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      alignment: AlignmentDirectional(-1.0, 1.0),
        ),
      ),
    );
  }
}

class _AdwBannerButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;

  const _AdwBannerButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_AdwBannerButton> createState() => _AdwBannerButtonState();
}

class _AdwBannerButtonState extends State<_AdwBannerButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);
    Color bg;
    if (_pressed && _enabled) {
      bg = theme.colors.bannerButtonActiveBackground;
    } else if ((_hovered || _focused) && _enabled) {
      bg = theme.colors.bannerButtonHoverBackground;
    } else {
      bg = theme.colors.bannerButtonBackground;
    }
    if (!_enabled) {
      bg = bg.withValues(alpha: 0.5);
    }
    final fg = _enabled
        ? theme.colors.windowForeground
        : theme.colors.windowForeground.withValues(alpha: 0.4);

    return Semantics(
      button: true,
      enabled: _enabled,
      onTap: _enabled ? widget.onPressed : null,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor:
            _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (hovered) {
          if (_enabled && _hovered != hovered) {
            setState(() {
              _hovered = hovered;
              if (!hovered) _pressed = false;
            });
          }
        },
        onShowFocusHighlight: (focused) {
          if (_focused != focused) setState(() => _focused = focused);
        },
        actions: _enabled
            ? <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    widget.onPressed?.call();
                    return null;
                  },
                ),
              }
            : const <Type, Action<Intent>>{},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            if (_enabled) setState(() => _pressed = true);
          },
          onTapUp: (_) {
            if (_enabled) setState(() => _pressed = false);
          },
          onTapCancel: () {
            if (_enabled) setState(() => _pressed = false);
          },
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: AdwCurves.resolve(context, AdwCurves.shortDuration),
            curve: AdwCurves.standard,
            constraints: const BoxConstraints(
              minHeight: AdwMetrics.buttonMinHeight,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AdwMetrics.buttonRadius),
            ),
            foregroundDecoration: _focused
                ? BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AdwMetrics.buttonRadius),
                    border: Border.all(
                      color: theme.colors.focusBorderColor,
                      width: 2.0,
                    ),
                  )
                : null,
            child: Center(
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.heading.copyWith(color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
