import 'package:adwaitter/adwaitter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AdwCarousel renders with independent Dots and Lines indicators',
      (tester) async {
    final controller = AdwCarouselController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AdwApplication(
        home: SizedBox(
          width: 400,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: AdwCarousel(
                  controller: controller,
                  allowScrollWheel: true,
                  children: [
                    const Center(child: Text('Page 1')),
                    const Center(child: Text('Page 2')),
                    Center(
                      child: AdwButton(
                        onPressed: () => controller.animateToPage(0),
                        child: const Text('Return to First'),
                      ),
                    ),
                  ],
                ),
              ),
              AdwCarouselIndicatorDots(controller: controller),
              AdwCarouselIndicatorLines(controller: controller),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Page 1'), findsOneWidget);
    expect(controller.currentPage, 0);

    // Scroll wheel advances page when allowScrollWheel is true.
    final center = tester.getCenter(find.byType(AdwCarousel));
    final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
    await tester.pumpAndSettle();

    expect(controller.currentPage, 1);

    // Clicking third segment of Lines indicator animates to Page 3.
    final linesFinder = find.byType(AdwCarouselIndicatorLines);
    final linesBox = tester.getRect(linesFinder);
    await tester.tapAt(Offset(linesBox.right - 10, linesBox.center.dy));
    await tester.pumpAndSettle();

    expect(controller.currentPage, 2);

    // Tapping button inside Page 3 animates all the way back to Page 0.
    await tester.tap(find.text('Return to First'));
    await tester.pumpAndSettle();
    expect(controller.currentPage, 0);

    // Verify allowLongSwipes: false caps a huge drag at Page 1.
    await tester.drag(find.byType(AdwCarousel), const Offset(-900, 0));
    await tester.pumpAndSettle();
    expect(controller.currentPage, 1);
  });

  testWidgets(
      'AdwCarousel updates allowLongSwipes dynamically, handles slow return gestures, and AdwSwitch ignores trackpad',
      (tester) async {
    final controller = AdwCarouselController();
    addTearDown(controller.dispose);
    bool allowLongSwipes = false;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return AdwApplication(
            home: SizedBox(
              width: 400,
              height: 400,
              child: AdwCarousel(
                controller: controller,
                allowLongSwipes: allowLongSwipes,
                children: [
                  const Center(child: Text('View 0')),
                  Center(
                    child: AdwSwitch(
                      value: allowLongSwipes,
                      onChanged: (v) => setState(() => allowLongSwipes = v),
                    ),
                  ),
                  const Center(child: Text('View 2')),
                ],
              ),
            ),
          );
        },
      ),
    );

    // Move to View 1 and toggle Long Swipes ON via tap.
    controller.jumpToPage(1);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AdwSwitch));
    await tester.pumpAndSettle();
    expect(allowLongSwipes, isTrue);

    // Trackpad two-finger swipe directly over AdwSwitch must NOT toggle AdwSwitch,
    // and must instead scroll the carousel.
    final switchCenter = tester.getCenter(find.byType(AdwSwitch));
    final trackpad = TestPointer(2, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(
      trackpad.panZoomStart(
        switchCenter,
        timeStamp: const Duration(milliseconds: 10),
      ),
    );
    await tester.sendEventToBinding(
      trackpad.panZoomUpdate(
        switchCenter,
        pan: const Offset(25, 0),
        timeStamp: const Duration(milliseconds: 20),
      ),
    );
    await tester.sendEventToBinding(
      trackpad.panZoomUpdate(
        switchCenter,
        pan: const Offset(600, 0),
        timeStamp: const Duration(milliseconds: 40),
      ),
    );
    await tester.sendEventToBinding(
      trackpad.panZoomEnd(timeStamp: const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(allowLongSwipes, isTrue);
    expect(controller.currentPage, 0);

    // Slow multi-page gesture from View 0 -> View 1 -> View 2 and slowly back to View 0 in the same gesture.
    final carouselRect = tester.getRect(find.byType(AdwCarousel));
    final pageWidth = carouselRect.width;
    final carouselCenter = carouselRect.center;
    final gesture = await tester.startGesture(carouselCenter);
    // Drag slowly across View 0 -> View 1 -> View 2 (-2 * pageWidth total in small steps)
    final forwardStep = -(pageWidth * 2 + 20) / 40.0;
    for (int i = 0; i < 40; i++) {
      await gesture.moveBy(Offset(forwardStep, 0),
          timeStamp: Duration(milliseconds: 20 * (i + 1)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(controller.page, closeTo(2.0, 0.05));

    // In the same gesture, return very slowly all the way back to View 0 (+2 * pageWidth in small steps)
    final returnStep = (pageWidth * 2) / 80.0;
    for (int i = 0; i < 80; i++) {
      await gesture.moveBy(Offset(returnStep, 0),
          timeStamp: Duration(milliseconds: 800 + 25 * (i + 1)));
      await tester.pump(const Duration(milliseconds: 25));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.currentPage, 0);
  });
}
