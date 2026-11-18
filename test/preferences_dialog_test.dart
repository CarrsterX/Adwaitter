import 'package:adwaitter/adwaitter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AdwPreferencesDialog switches tabs, searches, shows toast, and opens subpage',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      AdwApplication(
        home: Builder(
          builder: (context) => Center(
            child: AdwButton(
              onPressed: () {
                showAdwPreferencesDialog<void>(
                  context: context,
                  pages: [
                    AdwPreferencesDialogPage(
                      title: 'Layout',
                      icon: const SizedBox(width: 16, height: 16),
                      children: [
                        Builder(
                          builder: (innerContext) => AdwPreferencesGroup(
                            title: const Text('Group 1'),
                            children: [
                              AdwActionRow(
                                title: const Text('Open Subpage'),
                                onPressed: () {
                                  AdwPreferencesDialogScope.of(innerContext)
                                      .pushSubpage(
                                    const AdwNavigationPage(
                                      title: 'Subpage',
                                      child: AdwToolbarView(
                                        topBar: AdwHeaderBar(isFlat: true),
                                        content: Center(child: Text('Subpage Body')),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const AdwPreferencesDialogPage(
                      title: 'Search',
                      icon: SizedBox(width: 16, height: 16),
                      children: [
                        AdwPreferencesGroup(
                          title: Text('Searching'),
                          children: [
                            AdwActionRow(
                              title: Text('Activate the Search Button'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
              child: const Text('Open Prefs'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Prefs'));
    await tester.pumpAndSettle();

    expect(find.text('Open Subpage'), findsOneWidget);

    // Switch to Search tab
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Activate the Search Button'), findsOneWidget);

    // Switch back to Layout tab
    await tester.tap(find.text('Layout'));
    await tester.pumpAndSettle();
    expect(find.text('Open Subpage'), findsOneWidget);

    // Open Subpage
    await tester.tap(find.text('Open Subpage'));
    await tester.pumpAndSettle();
    expect(find.text('Subpage Body'), findsOneWidget);
  });
}
