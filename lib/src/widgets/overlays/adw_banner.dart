import 'package:flutter/widgets.dart';

import '../../theme/adw_curves.dart';
import '../../theme/adw_theme.dart';
import '../controls/adw_button.dart';

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
      duration: const Duration(milliseconds: 340),
      value: widget.revealed ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
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

    return SizeTransition(
      sizeFactor: _expandAnimation,
      axisAlignment: 1.0,
      child: Container(
        width: double.infinity,
        color: theme.colors.cardBackground,
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final titleStyle = theme.typography.body.copyWith(
              fontWeight: FontWeight.w700,
            );

            Widget buildButton() => AdwButton(
                  style: widget.useSuggestedStyle
                      ? AdwButtonStyle.suggested
                      : AdwButtonStyle.standard,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  onPressed: widget.onButtonPressed,
                  child: Text(
                    widget.buttonLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              maxLines: 1,
              textScaler: textScaler,
              textDirection: Directionality.of(context),
            )..layout();
            final buttonWidth = buttonPainter.width + 44;

            final titleText = widget.title is Text
                ? (widget.title as Text).data ?? ''
                : '';
            final titlePainter = TextPainter(
              text: TextSpan(text: titleText, style: titleStyle),
              maxLines: 1,
              textScaler: textScaler,
              textDirection: Directionality.of(context),
            )..layout();
            final titleWidth = titlePainter.width;

            final maxW = constraints.maxWidth;
            final canCenterTitle = titleWidth + (buttonWidth + 24) * 2 <= maxW;
            final canSingleRow = titleWidth + buttonWidth + 16 <= maxW;

            if (canCenterTitle) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: buttonWidth + 12),
                    child: DefaultTextStyle(
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                      child: widget.title,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
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
    );
  }
}
