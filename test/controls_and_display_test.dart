import 'package:adwaitter/adwaitter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Controls', () {
    testWidgets('AdwButton variants invoke onPressed and ignore taps when disabled',
        (WidgetTester tester) async {
      int regularTaps = 0;
      int suggestedTaps = 0;
      int destructiveTaps = 0;
      int flatTaps = 0;
      int pillTaps = 0;

      await tester.pumpWidget(
        AdwApplication(
          home: AdwWindow(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdwButton(
                  onPressed: () => regularTaps++,
                  child: const Text('Regular'),
                ),
                AdwButton.suggested(
                  onPressed: () => suggestedTaps++,
                  child: const Text('Suggested'),
                ),
                AdwButton.destructive(
                  onPressed: () => destructiveTaps++,
                  child: const Text('Destructive'),
                ),
                AdwButton.flat(
                  onPressed: () => flatTaps++,
                  child: const Text('Flat'),
                ),
                AdwButton.pill(
                  onPressed: () => pillTaps++,
                  child: const Text('Pill'),
                ),
                const AdwButton(
                  onPressed: null,
                  child: Text('Disabled'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Regular'));
      await tester.tap(find.text('Suggested'));
      await tester.tap(find.text('Destructive'));
      await tester.tap(find.text('Flat'));
      await tester.tap(find.text('Pill'));
      await tester.tap(find.text('Disabled'));
      await tester.pump();

      expect(regularTaps, 1);
      expect(suggestedTaps, 1);
      expect(destructiveTaps, 1);
      expect(flatTaps, 1);
      expect(pillTaps, 1);
    });

    testWidgets('AdwSwitch and AdwSwitchRow toggle state on tap',
        (WidgetTester tester) async {
      bool switchValue = false;
      bool rowValue = true;

      await tester.pumpWidget(
        AdwApplication(
          home: StatefulBuilder(
            builder: (context, setState) {
              return AdwWindow(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AdwSwitch(
                      value: switchValue,
                      onChanged: (v) => setState(() => switchValue = v),
                    ),
                    AdwPreferencesGroup(
                      children: [
                        AdwSwitchRow(
                          title: const Text('Enable feature'),
                          value: rowValue,
                          onChanged: (v) => setState(() => rowValue = v),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AdwSwitch).first);
      await tester.pumpAndSettle();
      expect(switchValue, isTrue);

      await tester.tap(find.text('Enable feature'));
      await tester.pumpAndSettle();
      expect(rowValue, isFalse);
    });

    testWidgets('AdwCheckbox and AdwRadio update selection on tap',
        (WidgetTester tester) async {
      bool checked = false;
      String? radioGroup = 'a';

      await tester.pumpWidget(
        AdwApplication(
          home: StatefulBuilder(
            builder: (context, setState) {
              return AdwWindow(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AdwCheckbox(
                      value: checked,
                      onChanged: (v) => setState(() => checked = v),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AdwRadio<String>(
                          value: 'a',
                          groupValue: radioGroup,
                          onChanged: (v) => setState(() => radioGroup = v),
                        ),
                        AdwRadio<String>(
                          value: 'b',
                          groupValue: radioGroup,
                          onChanged: (v) => setState(() => radioGroup = v),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AdwCheckbox));
      await tester.pump();
      expect(checked, isTrue);

      await tester.tap(find.byType(AdwRadio<String>).last);
      await tester.pump();
      expect(radioGroup, 'b');
    });

    testWidgets('AdwSpinRow increments, decrements, clamps, and responds to arrows',
        (WidgetTester tester) async {
      double value = 5;

      await tester.pumpWidget(
        AdwApplication(
          home: StatefulBuilder(
            builder: (context, setState) {
              return AdwWindow(
                child: AdwPreferencesGroup(
                  children: [
                    AdwSpinRow(
                      title: const Text('Count'),
                      value: value,
                      min: 4,
                      max: 6,
                      step: 1,
                      onChanged: (v) => setState(() => value = v),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus the spin row and step up via keyboard
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(value, 6);

      // Clamped at max (6)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(value, 6);

      // Step down twice to hit min (4)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(value, 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(value, 4);
    });

    testWidgets('AdwToggleGroup switches selected segment',
        (WidgetTester tester) async {
      String selected = 'day';

      await tester.pumpWidget(
        AdwApplication(
          home: StatefulBuilder(
            builder: (context, setState) {
              return AdwWindow(
                child: Center(
                  child: AdwToggleGroup<String>(
                    selectedValue: selected,
                    onChanged: (v) => setState(() => selected = v),
                    items: const [
                      AdwToggleItem(value: 'day', child: Text('Day')),
                      AdwToggleItem(value: 'week', child: Text('Week')),
                      AdwToggleItem(value: 'month', child: Text('Month')),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(selected, 'month');
    });

    testWidgets('AdwExpanderRow expands and reveals child rows',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const AdwApplication(
          home: AdwWindow(
            child: AdwPreferencesGroup(
              children: [
                AdwExpanderRow(
                  title: Text('Advanced'),
                  children: [
                    AdwActionRow(title: Text('Hidden Option')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();
      expect(find.text('Hidden Option'), findsOneWidget);
    });

    testWidgets('AdwButtonRow invokes onPressed', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        AdwApplication(
          home: AdwWindow(
            child: AdwPreferencesGroup(
              children: [
                AdwButtonRow(
                  title: const Text('Reset Settings'),
                  onPressed: () => taps++,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset Settings'));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('Display widgets', () {
    testWidgets(
        'AdwAvatar, AdwProgressBar, AdwLevelBar, AdwSpinner, AdwStatusPage, AdwCard render cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const AdwApplication(
          home: AdwWindow(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AdwAvatar(size: 48, text: 'Ada Lovelace', showInitials: true),
                  SizedBox(height: 8),
                  AdwProgressBar(value: 0.65),
                  SizedBox(height: 8),
                  AdwLevelBar(value: 3, minValue: 0, maxValue: 5, segments: 5),
                  SizedBox(height: 8),
                  AdwSpinner(),
                  SizedBox(height: 8),
                  AdwCard(child: Text('Card Body')),
                  SizedBox(height: 8),
                  AdwStatusPage(
                    title: Text('Empty State'),
                    description: Text('Nothing to show yet.'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('AL'), findsOneWidget);
      expect(find.byType(AdwProgressBar), findsOneWidget);
      expect(find.byType(AdwLevelBar), findsOneWidget);
      expect(find.byType(AdwSpinner), findsOneWidget);
      expect(find.text('Card Body'), findsOneWidget);
      expect(find.text('Empty State'), findsOneWidget);
    });
  });
}
