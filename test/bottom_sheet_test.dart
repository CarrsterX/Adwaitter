import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adwaitter/adwaitter.dart';

void main() {
  testWidgets('AdwBottomSheet opens on bottomBar tap and closes via header close button',
      (tester) async {
    await tester.pumpWidget(
      AdwApplication(
        home: SizedBox(
          width: 600,
          height: 600,
          child: AdwBottomSheet(
            content: const Center(child: Text('Main Content')),
            sheet: const AdwToolbarView(
              topBar: AdwHeaderBar(isFlat: true, title: Text('Hidden Title')),
              content: Center(child: Text('Sheet Body')),
            ),
            bottomBar: const SizedBox(
              height: 46,
              child: Center(child: Text('Pull Up Here')),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Pull Up Here'), findsOneWidget);
    expect(find.text('Sheet Body'), findsNothing);

    await tester.tap(find.text('Pull Up Here'));
    await tester.pumpAndSettle();

    expect(find.text('Sheet Body'), findsOneWidget);
    // Title is suppressed when showDragHandle is true.
    expect(find.text('Hidden Title'), findsNothing);

    // Drag down to close.
    await tester.drag(find.text('Sheet Body'), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.text('Pull Up Here'), findsOneWidget);

    // Partial drag up from closed (< 50%) and release -> snaps back to closed.
    await tester.drag(find.text('Pull Up Here'), const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(find.text('Pull Up Here'), findsOneWidget);
    expect(find.text('Sheet Body'), findsNothing);

    // Open again, drag upward (overshoot) and release -> springs back cleanly.
    await tester.tap(find.text('Pull Up Here'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Sheet Body'), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(find.text('Sheet Body'), findsOneWidget);
  });
}
