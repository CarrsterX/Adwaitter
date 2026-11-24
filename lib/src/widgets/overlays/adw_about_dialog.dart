import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/adw_text_selection.dart';
import '../../theme/adw_theme.dart';
import '../containers/adw_action_row.dart';
import '../containers/adw_preferences_group.dart';
import '../controls/adw_button.dart';
import '../display/adw_emblem.dart';
import '../layout/adw_header_bar.dart';
import '../layout/adw_toolbar_view.dart';
import '../navigation/adw_navigation_view.dart';
import 'adw_dialog.dart';
import 'adw_toast.dart';

/// Link entry for [AdwAboutDialog].
class AdwAboutLink {
  final String title;
  final String url;

  const AdwAboutLink({required this.title, required this.url});
}

/// Legal section entry for [AdwAboutDialog].
class AdwAboutLegalSection {
  final String title;
  final String? copyright;
  final String? license;

  const AdwAboutLegalSection({
    required this.title,
    this.copyright,
    this.license,
  });
}

/// Acknowledgement section entry for [AdwAboutDialog].
class AdwAboutAcknowledgement {
  final String title;
  final List<String> people;

  const AdwAboutAcknowledgement({required this.title, required this.people});
}

/// Other application entry for [AdwAboutDialog].
class AdwAboutOtherApp {
  final String appId;
  final String name;
  final String summary;
  final Widget? icon;
  final String? url;

  const AdwAboutOtherApp({
    required this.appId,
    required this.name,
    required this.summary,
    this.icon,
    this.url,
  });
}

/// Official GNOME Libadwaita about dialog (`AdwAboutDialog`).
///
/// Adaptive modal dialog on desktop (floating) and bottom sheet on mobile,
/// with subpage navigation for What's New, Details, Credits, Legal, and Other Apps.
class AdwAboutDialog extends StatefulWidget {
  final Widget? applicationIcon;
  final String applicationName;
  final String? developerName;
  final String? version;
  final String? releaseNotesVersion;
  final String? releaseNotes;
  final String? comments;
  final String? website;
  final String? issueUrl;
  final String? supportUrl;
  final String? copyright;
  final String? license;
  final List<String> developers;
  final List<String> artists;
  final String? translatorCredits;
  final List<AdwAboutLink> links;
  final List<AdwAboutLegalSection> legalSections;
  final List<AdwAboutAcknowledgement> acknowledgements;
  final List<AdwAboutOtherApp> otherApps;
  final String? otherAppsTitle;
  final ValueChanged<String>? onOpenUrl;

  const AdwAboutDialog({
    super.key,
    this.applicationIcon,
    required this.applicationName,
    this.developerName,
    this.version,
    this.releaseNotesVersion,
    this.releaseNotes,
    this.comments,
    this.website,
    this.issueUrl,
    this.supportUrl,
    this.copyright,
    this.license,
    this.developers = const [],
    this.artists = const [],
    this.translatorCredits,
    this.links = const [],
    this.legalSections = const [],
    this.acknowledgements = const [],
    this.otherApps = const [],
    this.otherAppsTitle,
    this.onOpenUrl,
  });

  @override
  State<AdwAboutDialog> createState() => _AdwAboutDialogState();
}

class _AdwAboutDialogState extends State<AdwAboutDialog> {
  late final AdwNavigationViewController _navController;
  late final ScrollController _mainScrollController;
  final FocusNode _legalFocusNode = FocusNode();
  bool _showScrolledTitle = false;
  String? _hoveredLink;

  @override
  void initState() {
    super.initState();
    _navController = AdwNavigationViewController();
    _mainScrollController = ScrollController()
      ..addListener(() {
        final show = _mainScrollController.hasClients &&
            _mainScrollController.offset > 140;
        if (show != _showScrolledTitle) {
          setState(() => _showScrolledTitle = show);
        }
      });
  }

  @override
  void dispose() {
    _legalFocusNode.dispose();
    _navController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }

  void _pushSubpage(
    String title,
    Widget Function(AdwThemeData theme) bodyBuilder,
  ) {
    _navController.push(
      AdwNavigationPage(
        title: title,
        child: AdwToolbarView(
          topBar: AdwHeaderBar(
            isFlat: true,
            title: Text(title),
          ),
          content: Builder(
            builder: (pageContext) => bodyBuilder(AdwTheme.of(pageContext)),
          ),
        ),
      ),
    );
  }

  bool get _hasDetails =>
      (widget.comments != null && widget.comments!.isNotEmpty) ||
      (widget.website != null && widget.website!.isNotEmpty);

  bool get _hasCredits =>
      widget.developers.isNotEmpty ||
      widget.artists.isNotEmpty ||
      (widget.translatorCredits != null &&
          widget.translatorCredits!.isNotEmpty);

  bool get _hasAcknowledgements => widget.acknowledgements.isNotEmpty;

  bool get _hasLegal =>
      (widget.copyright != null && widget.copyright!.isNotEmpty) ||
      (widget.license != null && widget.license!.isNotEmpty) ||
      widget.legalSections.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isNarrow = MediaQuery.sizeOf(context).width <= 600;

    return AdwDialog(
      contentWidth: 360,
      contentHeight: isNarrow ? math.max(480.0, screenHeight - 170.0) : 848.0,
      child: AdwToastOverlay(
        child: AdwNavigationView(
          controller: _navController,
          initialPage: AdwNavigationPage(
            title: widget.applicationName,
            canPop: false,
            child: AdwToolbarView(
              topBar: AdwHeaderBar(
                isFlat: true,
                title: AnimatedOpacity(
                  opacity: _showScrolledTitle ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSlide(
                    offset: _showScrolledTitle
                        ? Offset.zero
                        : const Offset(0, 0.35),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: Text(widget.applicationName),
                  ),
                ),
              ),
              content: Builder(
                builder: (pageContext) =>
                    _buildMainPage(AdwTheme.of(pageContext)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainPage(AdwThemeData theme) {
    return SingleChildScrollView(
      controller: _mainScrollController,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      child: Column(
        children: [
          if (widget.applicationIcon != null)
            widget.applicationIcon!
          else
            const AdwEmblem(size: 100),
          const SizedBox(height: 2),
          Text(
            widget.applicationName,
            style:
                theme.typography.title1.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          if (widget.developerName != null) ...[
            const SizedBox(height: 2),
            Text(
              widget.developerName!,
              style: theme.typography.body.copyWith(
                color: theme.colors.popoverForeground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (widget.version != null) ...[
            const SizedBox(height: 6),
            Builder(
              builder: (btnContext) {
                final accentHsl = HSLColor.fromColor(theme.colors.accentColor);
                final darkAccentText = accentHsl
                    .withHue((accentHsl.hue - 7) % 360)
                    .withSaturation(1.0)
                    .withLightness(0.745)
                    .toColor();
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colors.isDark
                        ? Color.lerp(
                            theme.colors.windowBackground,
                            darkAccentText,
                            0.14,
                          )
                        : theme.colors.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: AdwButton.flat(
                    height: 30,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
                    borderRadius: BorderRadius.circular(999),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.version!));
                      AdwToastOverlay.of(btnContext).addToast(
                        const AdwToast(title: Text('Copied to clipboard')),
                      );
                    },
                    child: Text(
                      widget.version!,
                      style: theme.typography.body.copyWith(
                        color: theme.colors.isDark
                            ? darkAccentText
                            : theme.colors.accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 24),
          if (_hasDetails || widget.releaseNotes != null) ...[
            AdwPreferencesGroup(
              margin: EdgeInsets.zero,
              children: [
                if (widget.releaseNotes != null)
                  AdwActionRow(
                    title: const Text("What's New"),
                    trailing: _ChevronRightIcon(
                      color: theme.colors.windowForeground,
                    ),
                    onPressed: () =>
                        _pushSubpage("What's New", _buildWhatsNewPage),
                  ),
                if (_hasDetails)
                  AdwActionRow(
                    title: const Text('Details'),
                    trailing: _ChevronRightIcon(
                      color: theme.colors.windowForeground,
                    ),
                    onPressed: () => _pushSubpage('Details', _buildDetailsPage),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (widget.supportUrl != null || widget.issueUrl != null) ...[
            AdwPreferencesGroup(
              margin: EdgeInsets.zero,
              children: [
                if (widget.supportUrl != null)
                  AdwActionRow(
                    title: const Text('Support Questions'),
                    trailing: _ExternalLinkIcon(
                      color: theme.colors.windowForeground,
                    ),
                    onPressed: widget.onOpenUrl != null
                        ? () => widget.onOpenUrl!(widget.supportUrl!)
                        : null,
                  ),
                if (widget.issueUrl != null)
                  AdwActionRow(
                    title: const Text('Report an Issue'),
                    trailing: _ExternalLinkIcon(
                      color: theme.colors.windowForeground,
                    ),
                    onPressed: widget.onOpenUrl != null
                        ? () => widget.onOpenUrl!(widget.issueUrl!)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (_hasCredits || _hasLegal || _hasAcknowledgements) ...[
            AdwPreferencesGroup(
              margin: EdgeInsets.zero,
              children: [
                if (_hasCredits)
                  AdwActionRow(
                    title: const Text('Credits'),
                    trailing: _ChevronRightIcon(
                      color: theme.colors.windowForeground,
                    ),
                    onPressed: () => _pushSubpage('Credits', _buildCreditsPage),
                  ),
                if (_hasLegal)
                  AdwActionRow(
                    title: const Text('Legal'),
                    trailing: _ChevronRightIcon(
                      color: theme.colors.windowForeground,
                    ),
                    onPressed: () => _pushSubpage('Legal', _buildLegalPage),
                  ),
                if (_hasAcknowledgements)
                  AdwActionRow(
                    title: const Text('Acknowledgements'),
                    trailing: _ChevronRightIcon(
                      color: theme.colors.windowForeground,
                    ),
                    onPressed: () => _pushSubpage(
                      'Acknowledgements',
                      _buildAcknowledgementsPage,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (widget.otherApps.isNotEmpty)
            AdwPreferencesGroup(
              margin: EdgeInsets.zero,
              title: Text(
                widget.otherAppsTitle ??
                    (widget.developerName != null
                        ? 'Other Apps by ${widget.developerName}'
                        : 'Other Apps'),
              ),
              children: [
                for (final app in widget.otherApps)
                  AdwActionRow(
                    prefix: app.icon,
                    title: Text(app.name),
                    subtitle: Text(app.summary),
                    trailing: _ExternalLinkIcon(
                      color: theme.colors.windowForeground,
                    ),
                    onPressed: app.url != null && widget.onOpenUrl != null
                        ? () => widget.onOpenUrl!(app.url!)
                        : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsPage(AdwThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.comments != null) ...[
            Text(
              widget.comments!,
              style: theme.typography.body.copyWith(
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (widget.website != null || widget.links.isNotEmpty)
            AdwPreferencesGroup(
              margin: EdgeInsets.zero,
              children: [
                if (widget.website != null)
                  AdwActionRow(
                    title: const Text('Website'),
                    trailing: _ExternalLinkIcon(
                      color: theme.colors.windowForeground,
                    ),
                    onPressed: widget.onOpenUrl != null
                        ? () => widget.onOpenUrl!(widget.website!)
                        : null,
                  ),
                for (final link in widget.links)
                  AdwActionRow(
                    title: Text(link.title),
                    trailing: _ExternalLinkIcon(
                      color: theme.colors.windowForeground,
                    ),
                    onPressed: widget.onOpenUrl != null
                        ? () => widget.onOpenUrl!(link.url)
                        : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  List<InlineSpan> _parseRichInline(
    String text,
    TextStyle baseStyle,
    AdwThemeData theme,
  ) {
    final spans = <InlineSpan>[];
    final tagRegex = RegExp(r'<(code|em|i|strong|b)>(.*?)</\1>');
    var lastIndex = 0;
    for (final match in tagRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }
      final tag = match.group(1)!;
      final inner = match.group(2)!;
      final style = switch (tag) {
        'code' => baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: theme.colors.windowForeground.withValues(
              alpha: 0.10,
            ),
          ),
        'em' || 'i' => baseStyle.copyWith(fontStyle: FontStyle.italic),
        'strong' || 'b' => baseStyle.copyWith(fontWeight: FontWeight.w700),
        _ => baseStyle,
      };
      spans.add(TextSpan(text: inner, style: style));
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }
    return spans;
  }

  Widget _buildWhatsNewPage(AdwThemeData theme) {
    final raw = (widget.releaseNotes ?? '').trim();
    final bodyStyle = theme.typography.body.copyWith(
      fontSize: 13.5,
      height: 1.45,
    );

    final blocks = <Widget>[];
    final hasHtmlBlocks =
        raw.contains('<p>') || raw.contains('<li>') || raw.contains('<ul>');

    if (hasHtmlBlocks) {
      final blockRegex = RegExp(r'<(p|li)>(.*?)</\1>', dotAll: true);
      for (final match in blockRegex.allMatches(raw)) {
        final tag = match.group(1)!;
        final inner = match.group(2)!.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (tag == 'p') {
          blocks.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text.rich(
                TextSpan(
                  style: bodyStyle,
                  children: _parseRichInline(inner, bodyStyle, theme),
                ),
              ),
            ),
          );
        } else {
          blocks.add(
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: bodyStyle),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: bodyStyle,
                        children: _parseRichInline(inner, bodyStyle, theme),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } else {
      blocks.add(
        Text.rich(
          TextSpan(
            style: bodyStyle,
            children: _parseRichInline(raw, bodyStyle, theme),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.releaseNotesVersion != null) ...[
            Text(
              'Version ${widget.releaseNotesVersion}',
              style: theme.typography.heading,
            ),
            const SizedBox(height: 10),
          ],
          ...blocks,
        ],
      ),
    );
  }

  Widget _buildPersonRow(AdwThemeData theme, String entry) {
    final emailMatch = RegExp(r'^(.+?)\s*<([^>]+)>$').firstMatch(entry);
    if (emailMatch != null) {
      final name = emailMatch.group(1)!.trim();
      final email = emailMatch.group(2)!.trim();
      return AdwActionRow(
        title: Text(name),
        trailing: _MailSendIcon(color: theme.colors.windowForeground),
        onPressed: widget.onOpenUrl != null
            ? () => widget.onOpenUrl!('mailto:$email')
            : null,
      );
    }
    return AdwActionRow(title: Text(entry));
  }

  Widget _buildCreditsPage(AdwThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.developers.isNotEmpty) ...[
            AdwPreferencesGroup(
              margin: EdgeInsets.zero,
              title: const Text('Developed by'),
              children: [
                for (final dev in widget.developers)
                  _buildPersonRow(theme, dev),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (widget.artists.isNotEmpty) ...[
            AdwPreferencesGroup(
              margin: EdgeInsets.zero,
              title: const Text('Artwork by'),
              children: [
                for (final artist in widget.artists)
                  _buildPersonRow(theme, artist),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (widget.translatorCredits != null) ...[
            AdwPreferencesGroup(
              margin: EdgeInsets.zero,
              title: const Text('Translated by'),
              children: [
                AdwActionRow(title: Text(widget.translatorCredits!)),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildAcknowledgementsPage(AdwThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final ack in widget.acknowledgements) ...[
            AdwPreferencesGroup(
              margin: EdgeInsets.zero,
              title: Text(ack.title),
              children: [
                for (final p in ack.people) AdwActionRow(title: Text(p)),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  InlineSpan _buildLinkSpan({
    required String id,
    required String label,
    required String url,
    required TextStyle baseStyle,
    required Color linkColor,
    required Color hoverColor,
    required StateSetter setLegalState,
  }) {
    final isHovered = _hoveredLink == id;
    final color = isHovered ? hoverColor : linkColor;
    return TextSpan(
      text: label,
      mouseCursor: SystemMouseCursors.click,
      onEnter: (_) => setLegalState(() => _hoveredLink = id),
      onExit: (_) => setLegalState(() {
        if (_hoveredLink == id) _hoveredLink = null;
      }),
      style: baseStyle.copyWith(
        color: color,
        decoration: TextDecoration.underline,
        decorationColor: color,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () => widget.onOpenUrl?.call(url),
    );
  }

  List<InlineSpan> _parseHtmlLinks(
    String text,
    TextStyle baseStyle,
    Color linkColor,
    Color hoverColor,
    StateSetter setLegalState,
  ) {
    final spans = <InlineSpan>[];
    final linkRegex = RegExp(r'''<a\s+href=['"]([^'"]+)['"]>(.*?)</a>''');
    var lastIndex = 0;
    for (final match in linkRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }
      final url = match.group(1)!;
      final label = match.group(2)!;
      spans.add(
        _buildLinkSpan(
          id: '$url::$label',
          label: label,
          url: url,
          baseStyle: baseStyle,
          linkColor: linkColor,
          hoverColor: hoverColor,
          setLegalState: setLegalState,
        ),
      );
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }
    return spans;
  }

  Widget _buildLegalPage(AdwThemeData theme) {
    return StatefulBuilder(
      builder: (context, setLegalState) {
        final accentHsl = HSLColor.fromColor(theme.colors.accentColor);
        final linkColor = theme.colors.isDark
            ? accentHsl.withLightness(0.75).toColor()
            : theme.colors.accentColor;
        final hoverColor = theme.colors.isDark
            ? accentHsl.withLightness(0.86).toColor()
            : accentHsl.withLightness(0.35).toColor();
        final bodyStyle = theme.typography.body.copyWith(height: 1.45);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: AdwSelectableRegion(
            focusNode: _legalFocusNode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.copyright != null) ...[
                  Text(widget.copyright!, style: theme.typography.body),
                  const SizedBox(height: 16),
                ],
                if (widget.license != null) ...[
                  Text.rich(
                    TextSpan(
                      style: bodyStyle,
                      children: [
                        const TextSpan(
                          text:
                              'This application comes with absolutely no warranty. See the ',
                        ),
                        _buildLinkSpan(
                          id: '__main_license__',
                          label: widget.license!,
                          url:
                              'https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html',
                          baseStyle: bodyStyle,
                          linkColor: linkColor,
                          hoverColor: hoverColor,
                          setLegalState: setLegalState,
                        ),
                        const TextSpan(text: ' for details.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                for (final section in widget.legalSections) ...[
                  SelectionContainer.disabled(
                    child: Text(section.title, style: theme.typography.heading),
                  ),
                  const SizedBox(height: 8),
                  if (section.copyright != null) ...[
                    Text(section.copyright!, style: theme.typography.body),
                    const SizedBox(height: 6),
                  ],
                  if (section.license != null)
                    Text.rich(
                      TextSpan(
                        style: bodyStyle,
                        children: _parseHtmlLinks(
                          section.license!,
                          bodyStyle,
                          linkColor,
                          hoverColor,
                          setLegalState,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChevronRightIcon extends StatelessWidget {
  const _ChevronRightIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _ChevronRightPainter(color: color)),
    );
  }
}

class _ChevronRightPainter extends CustomPainter {
  const _ChevronRightPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 16.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(6.0 * u, 3.5 * u)
      ..lineTo(10.5 * u, 8.0 * u)
      ..lineTo(6.0 * u, 12.5 * u);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronRightPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ExternalLinkIcon extends StatelessWidget {
  const _ExternalLinkIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _ExternalLinkPainter(color: color)),
    );
  }
}

class _ExternalLinkPainter extends CustomPainter {
  const _ExternalLinkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 16.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Open box sitting lower-left so the arrow protrudes top-right
    final box = Path()
      ..moveTo(7.5 * u, 3.5 * u)
      ..lineTo(3.5 * u, 3.5 * u)
      ..arcToPoint(Offset(2.0 * u, 5.0 * u), radius: Radius.circular(1.5 * u))
      ..lineTo(2.0 * u, 12.5 * u)
      ..arcToPoint(Offset(3.5 * u, 14.0 * u), radius: Radius.circular(1.5 * u))
      ..lineTo(11.0 * u, 14.0 * u)
      ..arcToPoint(Offset(12.5 * u, 12.5 * u), radius: Radius.circular(1.5 * u))
      ..lineTo(12.5 * u, 8.5 * u);
    canvas.drawPath(box, paint);

    // Protruding diagonal arrow top-right
    canvas.drawLine(Offset(7.5 * u, 8.5 * u), Offset(14.5 * u, 1.5 * u), paint);
    final head = Path()
      ..moveTo(10.0 * u, 1.5 * u)
      ..lineTo(14.5 * u, 1.5 * u)
      ..lineTo(14.5 * u, 6.0 * u);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(_ExternalLinkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Displays an adaptive [AdwAboutDialog] (floating modal on desktop, bottom sheet on mobile).
Future<void> showAdwAboutDialog({
  required BuildContext context,
  Widget? applicationIcon,
  required String applicationName,
  String? developerName,
  String? version,
  String? releaseNotesVersion,
  String? releaseNotes,
  String? comments,
  String? website,
  String? issueUrl,
  String? supportUrl,
  String? copyright,
  String? license,
  List<String> developers = const [],
  List<String> artists = const [],
  String? translatorCredits,
  List<AdwAboutLink> links = const [],
  List<AdwAboutLegalSection> legalSections = const [],
  List<AdwAboutAcknowledgement> acknowledgements = const [],
  List<AdwAboutOtherApp> otherApps = const [],
  String? otherAppsTitle,
  ValueChanged<String>? onOpenUrl,
}) {
  return showAdwDialog<void>(
    context: context,
    builder: (_) => AdwAboutDialog(
      applicationIcon: applicationIcon,
      applicationName: applicationName,
      developerName: developerName,
      version: version,
      releaseNotesVersion: releaseNotesVersion,
      releaseNotes: releaseNotes,
      comments: comments,
      website: website,
      issueUrl: issueUrl,
      supportUrl: supportUrl,
      copyright: copyright,
      license: license,
      developers: developers,
      artists: artists,
      translatorCredits: translatorCredits,
      links: links,
      legalSections: legalSections,
      acknowledgements: acknowledgements,
      otherApps: otherApps,
      otherAppsTitle: otherAppsTitle,
      onOpenUrl: onOpenUrl,
    ),
  );
}

class _MailSendIcon extends StatelessWidget {
  const _MailSendIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _MailSendPainter(color: color)),
    );
  }
}

class _MailSendPainter extends CustomPainter {
  const _MailSendPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 16.0;

    // Exact official Libadwaita adw-mail-send-symbolic SVG (16x16):
    final envPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * u
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round;

    final flap = Path()
      ..moveTo(14.49 * u, 10.68 * u)
      ..lineTo(8.0 * u, 15.0 * u)
      ..lineTo(1.52 * u, 10.67 * u);
    canvas.drawPath(flap, envPaint);

    final body = Path()
      ..moveTo(1.0 * u, 16.0 * u)
      ..lineTo(1.0 * u, 12.0 * u)
      ..cubicTo(1.0 * u, 10.9 * u, 1.9 * u, 10.0 * u, 3.0 * u, 10.0 * u)
      ..lineTo(13.0 * u, 10.0 * u)
      ..cubicTo(14.1 * u, 10.0 * u, 15.0 * u, 10.9 * u, 15.0 * u, 12.0 * u)
      ..lineTo(15.0 * u, 16.0 * u);
    canvas.drawPath(body, envPaint);

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final arrowHead = Path()
      ..moveTo(5.0 * u, 4.0 * u)
      ..lineTo(8.0 * u, 1.0 * u)
      ..lineTo(11.0 * u, 4.0 * u);
    canvas.drawPath(arrowHead, arrowPaint);
    canvas.drawLine(
        Offset(8.0 * u, 7.0 * u), Offset(8.0 * u, 1.0 * u), arrowPaint);
  }

  @override
  bool shouldRepaint(_MailSendPainter oldDelegate) =>
      oldDelegate.color != color;
}
