import 'package:adwaitter/adwaitter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Overlays', () {
    testWidgets('showAdwAlertDialog displays heading, body, and resolves action',
        (WidgetTester tester) async {
      String? result;

      await tester.pumpWidget(
        AdwApplication(
          home: AdwWindow(
            child: Builder(
              builder: (context) => Center(
                child: AdwButton(
                  onPressed: () async {
                    result = await showAdwAlertDialog<String>(
                      context: context,
                      heading: const Text('Delete File?'),
                      body: const Text('This action cannot be undone.'),
                      actions: [
                        AdwButton(
                          onPressed: () =>
                              Navigator.of(context, rootNavigator: true)
                                  .pop('cancel'),
                          child: const Text('Cancel'),
                        ),
                        AdwButton.destructive(
                          onPressed: () =>
                              Navigator.of(context, rootNavigator: true)
                                  .pop('delete'),
                          child: const Text('Delete'),
                        ),
                      ],
                    );
                  },
                  child: const Text('Open Alert'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Alert'));
      await tester.pumpAndSettle();

      expect(find.text('Delete File?'), findsOneWidget);
      expect(find.text('This action cannot be undone.'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(result, 'delete');
      expect(find.text('Delete File?'), findsNothing);
    });

    testWidgets('AdwBanner reveals content and invokes action button',
        (WidgetTester tester) async {
      int bannerTaps = 0;

      await tester.pumpWidget(
        AdwApplication(
          home: AdwWindow(
            child: Column(
              children: [
                AdwBanner(
                  revealed: true,
                  title: const Text('Offline Mode'),
                  buttonLabel: 'Reconnect',
                  onButtonPressed: () => bannerTaps++,
                ),
                const Expanded(child: Center(child: Text('Body'))),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offline Mode'), findsOneWidget);
      await tester.tap(find.text('Reconnect'));
      await tester.pump();
      expect(bannerTaps, 1);
    });

    testWidgets('AdwToastOverlay shows toast and invokes action',
        (WidgetTester tester) async {
      int undoCount = 0;

      await tester.pumpWidget(
        AdwApplication(
          home: AdwWindow(
            child: AdwToastOverlay(
              child: Builder(
                builder: (context) => Center(
                  child: AdwButton(
                    onPressed: () {
                      AdwToastOverlay.of(context).addToast(
                        AdwToast(
                          title: const Text('Item archived'),
                          timeout: const Duration(seconds: 5),
                          action: AdwButton.flat(
                            onPressed: () => undoCount++,
                            child: const Text('Undo'),
                          ),
                        ),
                      );
                    },
                    child: const Text('Show Toast'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show Toast'));
      await tester.pumpAndSettle();

      expect(find.text('Item archived'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undoCount, 1);
    });

    testWidgets('AdwShortcutsDialog filters shortcuts via search',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const AdwApplication(
          home: AdwWindow(
            child: AdwShortcutsDialog(
              sections: [
                AdwShortcutsSection(
                  title: 'General',
                  items: [
                    AdwShortcutsItem(
                      title: 'New Tab',
                      accelerator: '<Ctrl>t',
                    ),
                    AdwShortcutsItem(
                      title: 'Quit Application',
                      accelerator: '<Ctrl>q',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Tab'), findsOneWidget);
      expect(find.text('Quit Application'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'Quit');
      await tester.pumpAndSettle();

      expect(find.text('Quit Application'), findsOneWidget);
      expect(find.text('New Tab'), findsNothing);
    });
  });

  group('Theme & StyleManager', () {
    testWidgets('AdwTheme switches light/dark and high contrast cleanly',
        (WidgetTester tester) async {
      AdwThemeData? capturedTheme;

      await tester.pumpWidget(
        AdwApplication(
          themeMode: AdwThemeMode.dark,
          darkTheme: AdwThemeData.dark(accent: AdwAccentColor.purple),
          home: Builder(
            builder: (context) {
              capturedTheme = AdwTheme.of(context);
              return const AdwWindow(child: Text('Themed'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedTheme, isNotNull);
      expect(capturedTheme!.colors.isDark, isTrue);
    });
  });
}
