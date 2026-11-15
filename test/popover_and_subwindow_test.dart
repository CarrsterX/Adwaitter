import 'package:adwaitter/adwaitter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AdwComboRow opens AdwPopoverSurface and selects an option',
      (tester) async {
    String selected = 'Horizontal';

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return AdwApplication(
            home: AdwWindow(
              showShadow: false,
              showBorder: false,
              child: Center(
                child: SizedBox(
                  width: 320,
                  child: AdwPreferencesGroup(
                    children: [
                      AdwComboRow<String>(
                        title: const Text('Orientation'),
                        items: const ['Horizontal', 'Vertical'],
                        selectedItem: selected,
                        onSelected: (value) =>
                            setState(() => selected = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('Orientation'));
    await tester.pumpAndSettle();

    expect(find.byType(AdwPopoverSurface), findsOneWidget);
    expect(find.text('Vertical'), findsOneWidget);

    await tester.tap(find.text('Vertical'));
    await tester.pumpAndSettle();

    expect(selected, 'Vertical');
    expect(find.byType(AdwPopoverSurface), findsNothing);
  });

  testWidgets(
      'AdwSubWindowManager.openWindow falls back to an additional screen when non-Linux',
      (tester) async {
    late AdwSubWindowHandle handle;

    await tester.pumpWidget(
      AdwApplication(
        home: Builder(
          builder: (context) {
            return Center(
              child: AdwButton(
                onPressed: () {
                  handle = AdwSubWindowManager.instance.openWindow(
                    title: 'Secondary Screen',
                    builder: (innerContext, win) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Inside Additional Screen'),
                        AdwButton(
                          onPressed: win.close,
                          child: const Text('Close Screen'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open Window'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Window'));
    await tester.pumpAndSettle();

    expect(handle.isNativeWindow, isFalse);
    expect(find.text('Inside Additional Screen'), findsOneWidget);

    await tester.tap(find.text('Close Screen'));
    await tester.pumpAndSettle();

    expect(find.text('Inside Additional Screen'), findsNothing);
    expect(find.text('Open Window'), findsOneWidget);
  });
}
