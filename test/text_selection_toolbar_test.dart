import 'package:adwaitter/adwaitter.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AdwEntry shows selection toolbar on Android long-press and Linux right-click',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final controller = TextEditingController(text: 'Hello Adwaita world');
      await tester.pumpWidget(
        AdwApplication(
          home: AdwWindow(
            child: Center(
              child: SizedBox(
                width: 300,
                child: AdwEntry(controller: controller),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long-press and drag on the entry text (touch): selects character-by-
      // character and shows OSD touch-selection popover + teardrop handles.
      final entryRect = tester.getRect(find.byType(EditableText));
      final start = entryRect.centerLeft + const Offset(10, 0);
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(start + const Offset(48, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final surfaceFinder = find.byType(AdwPopoverSurface);
      final surface = tester.widget<AdwPopoverSurface>(surfaceFinder);
      expect(surface.isOsd, isTrue);
      expect(surface.arrowSide, isNot(AdwPopoverArrowSide.none));
      // Touch selection popover must stay compact vertically (never expand to
      // full screen height due to horizontal SingleChildScrollView).
      expect(tester.getSize(surfaceFinder).height, lessThan(80.0));
      expect(find.bySemanticsLabel('Copy'), findsOneWidget);
      expect(find.bySemanticsLabel('Cut'), findsOneWidget);
      expect(find.bySemanticsLabel('Share'), findsOneWidget);

      final editableState =
          tester.state<EditableTextState>(find.byType(EditableText));
      expect(editableState.widget.showSelectionHandles, isTrue);
      expect(editableState.selectionOverlay?.handlesAreVisible, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('AdwEntry shows selection toolbar on Linux secondary tap (right-click)',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final controller = TextEditingController(text: 'Hello Linux world');
      await tester.pumpWidget(
        AdwApplication(
          home: AdwWindow(
            child: Center(
              child: SizedBox(
                width: 300,
                child: AdwEntry(controller: controller),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final entryCenter = tester.getCenter(find.byType(AdwEntry));
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.addPointer(location: entryCenter);
      await gesture.down(entryCenter);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byType(AdwPopoverSurface), findsOneWidget);
      expect(find.byType(AdwPopoverMenuItem), findsAtLeastNWidgets(5));
      expect(find.byType(AdwPopoverDivider), findsNWidgets(2));
      expect(find.text('Cut'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Select All'), findsOneWidget);
      expect(find.text('Insert Emoji'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('AdwEntryRow shows selection toolbar on Android long-press',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final controller = TextEditingController(text: 'Hello EntryRow');
      await tester.pumpWidget(
        AdwApplication(
          home: AdwWindow(
            child: Center(
              child: SizedBox(
                width: 300,
                child: AdwEntryRow(
                  title: const Text('Name'),
                  controller: controller,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editableRect = tester.getRect(find.byType(EditableText));
      final start = editableRect.centerLeft + const Offset(10, 0);
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(start + const Offset(44, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.bySemanticsLabel('Copy'), findsOneWidget);
      expect(find.bySemanticsLabel('Cut'), findsOneWidget);
      expect(find.bySemanticsLabel('Share'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('AdwEntry shows Libadwaita OSD magnifier during touch long-press on Linux and Android',
      (WidgetTester tester) async {
    for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final controller = TextEditingController(text: 'hola mundo');
        await tester.pumpWidget(
          AdwApplication(
            home: AdwWindow(
              child: Center(
                child: SizedBox(
                  width: 300,
                  child: AdwEntry(controller: controller),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final rect = tester.getRect(find.byType(EditableText));
        final gesture = await tester.startGesture(
          rect.centerLeft + const Offset(20, 0),
          kind: PointerDeviceKind.touch,
        );
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byKey(AdwTextSelectionControls.magnifierKey), findsOneWidget);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byKey(AdwTextSelectionControls.magnifierKey), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
