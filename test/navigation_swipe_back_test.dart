import 'package:adwaitter/adwaitter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Cancelled swipe-back gesture in collapsed AdwNavigationSplitView leaves content interactive',
      (WidgetTester tester) async {
    int tapCount = 0;

    await tester.pumpWidget(
      AdwApplication(
        home: SizedBox(
          width: 400,
          height: 600,
          child: AdwNavigationSplitView(
            breakpoint: 540,
            sidebar: const Center(child: Text('Sidebar')),
            content: Center(
              child: AdwButton(
                onPressed: () => tapCount++,
                child: const Text('Tap Me'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial tap works
    await tester.tap(find.text('Tap Me'));
    await tester.pumpAndSettle();
    expect(tapCount, 1);

    final center = tester.getCenter(find.text('Tap Me'));

    // 1. Trackpad swipe right slightly (not enough to pop) and release
    final TestGesture trackpad = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await trackpad.panZoomStart(center);
    await tester.pump();
    await trackpad.panZoomUpdate(center, pan: const Offset(30, 0));
    await tester.pump();
    await trackpad.panZoomUpdate(center, pan: const Offset(60, 0));
    await tester.pump();
    await trackpad.panZoomEnd();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tap Me'));
    await tester.pumpAndSettle();
    expect(tapCount, 2,
        reason: 'Button should be tappable after cancelled trackpad swipe');

    // 2. Trackpad swipe right then back left to 0, then release
    await trackpad.panZoomStart(center);
    await tester.pump();
    await trackpad.panZoomUpdate(center, pan: const Offset(40, 0));
    await tester.pump();
    await trackpad.panZoomUpdate(center, pan: const Offset(0, 0));
    await tester.pump();
    await trackpad.panZoomEnd();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tap Me'));
    await tester.pumpAndSettle();
    expect(tapCount, 3,
        reason: 'Button should be tappable after swipe right then back left');

    // 3. Overlapping trackpad swipes during spring settle
    await trackpad.panZoomStart(center);
    await tester.pump();
    await trackpad.panZoomUpdate(center, pan: const Offset(50, 0));
    await tester.pump();
    await trackpad.panZoomEnd();
    await tester.pump(const Duration(milliseconds: 50));

    // Start second swipe while spring is still animating
    await trackpad.panZoomStart(center);
    await tester.pump();
    await trackpad.panZoomUpdate(center, pan: const Offset(30, 0));
    await tester.pump();
    await trackpad.panZoomEnd();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tap Me'));
    await tester.pumpAndSettle();
    expect(tapCount, 4,
        reason: 'Button should be tappable after overlapping swipes');

    // 4. Mouse drag right slightly (not enough to pop) and release
    await tester.drag(find.text('Tap Me'), const Offset(60, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tap Me'));
    await tester.pumpAndSettle();
    expect(tapCount, 5,
        reason: 'Button should be tappable after cancelled mouse drag');

    // 5. Interrupted trackpad panZoomStart while a trackpad gesture was active
    await trackpad.panZoomStart(center);
    await tester.pump();
    await trackpad.panZoomUpdate(center, pan: const Offset(40, 0));
    await tester.pump();
    final TestGesture trackpad2 = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await trackpad2.panZoomStart(center);
    await tester.pump();
    await trackpad2.panZoomEnd();
    await trackpad.panZoomEnd();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tap Me'));
    await tester.pumpAndSettle();
    expect(tapCount, 6,
        reason:
            'Button should remain interactive if panZoomStart interrupts active gesture');
  });
}
