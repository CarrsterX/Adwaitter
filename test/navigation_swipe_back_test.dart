import 'package:adwaitter/adwaitter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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

  testWidgets(
      'Android gesture navigation disables window drag and pops via system predictive back',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.systemGestureInsets = const FakeViewPadding(left: 24, right: 24);
    addTearDown(tester.view.resetSystemGestureInsets);

    await tester.pumpWidget(
      AdwApplication(
        home: AdwNavigationSplitView(
          breakpoint: 540,
          sidebar: const Center(child: Text('Sidebar')),
          content: const Center(child: Text('Content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Content'), findsOneWidget);

    // Window horizontal drag should NOT pop on Android gesture navigation.
    await tester.drag(find.text('Content'), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Content'), findsOneWidget);

    // System predictive back SHOULD pop using the same Libadwaita transition.
    final binding = TestWidgetsFlutterBinding.instance;
    const StandardMethodCodec codec = StandardMethodCodec();
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      codec.encodeMethodCall(const MethodCall('startBackGesture', <String, dynamic>{
        'touchOffset': <double>[0.0, 300.0],
        'progress': 0.0,
        'swipeEdge': 0,
      })),
      (_) {},
    );
    await tester.pump();
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      codec.encodeMethodCall(const MethodCall('updateBackGestureProgress', <String, dynamic>{
        'touchOffset': <double>[180.0, 300.0],
        'progress': 0.45,
        'swipeEdge': 0,
      })),
      (_) {},
    );
    await tester.pump();
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      codec.encodeMethodCall(const MethodCall('commitBackGesture')),
      (_) {},
    );
    await tester.pumpAndSettle();

    expect(find.text('Content'), findsNothing);
    expect(find.text('Sidebar'), findsOneWidget);
  });

  testWidgets(
      'Android button navigation allows window swipe and system didPopRoute',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      AdwApplication(
        home: AdwNavigationSplitView(
          breakpoint: 540,
          sidebar: const Center(child: Text('Sidebar')),
          content: const Center(child: Text('Content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Content'), findsOneWidget);

    // System back button (didPopRoute) pops nested AdwNavigationView.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Content'), findsNothing);
    expect(find.text('Sidebar'), findsOneWidget);

    // Reset tree before mounting a fresh AdwApplication to test window swipe.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final controller = AdwNavigationViewController();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 600),
          systemGestureInsets: EdgeInsets.zero,
        ),
        child: AdwApplication(
          home: SizedBox(
            width: 400,
            height: 600,
            child: AdwNavigationView(
              controller: controller,
              initialPages: const [
                AdwNavigationPage(
                  title: 'Root',
                  child: Center(child: Text('RootPage')),
                ),
                AdwNavigationPage(
                  title: 'Detail',
                  child: Center(child: Text('DetailPage')),
                ),
              ],
              initialPage: const AdwNavigationPage(
                title: 'Root',
                child: Center(child: Text('RootPage')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('DetailPage'), findsOneWidget);

    // Window swipe-back works like Linux when Android is in button mode.
    await tester.drag(find.text('DetailPage'), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('RootPage'), findsOneWidget);
  });

  testWidgets('iOS restricts swipe-back to left screen edge',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      AdwApplication(
        home: AdwNavigationSplitView(
          breakpoint: 540,
          sidebar: const Center(child: Text('Sidebar')),
          content: const Center(child: Text('Content')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Content'), findsOneWidget);

    // Drag from center of screen should NOT pop on iOS.
    await tester.dragFrom(const Offset(200, 300), const Offset(280, 0));
    await tester.pumpAndSettle();
    expect(find.text('Content'), findsOneWidget);

    // Drag from left screen edge SHOULD pop on iOS.
    await tester.dragFrom(const Offset(10, 300), const Offset(280, 0));
    await tester.pumpAndSettle();
    expect(find.text('Content'), findsNothing);
    expect(find.text('Sidebar'), findsOneWidget);
  });

  testWidgets(
      'Closing modal dialog keeps frameworkHandlesBack true while collapsed split view can pop',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.systemGestureInsets = const FakeViewPadding(left: 24, right: 24);
    addTearDown(tester.view.resetSystemGestureInsets);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    final List<bool> frameworkHandlesBackCalls = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'SystemNavigator.setFrameworkHandlesBack') {
          frameworkHandlesBackCalls.add(methodCall.arguments as bool);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      AdwApplication(
        home: AdwNavigationSplitView(
          breakpoint: 540,
          sidebar: const Center(child: Text('Sidebar')),
          content: Builder(
            builder: (ctx) => Center(
              child: AdwButton(
                onPressed: () => showAdwDialog<void>(
                  context: ctx,
                  builder: (_) => const AdwDialog(
                    title: 'Modal',
                    child: Text('ModalBody'),
                  ),
                ),
                child: const Text('OpenModal'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OpenModal'));
    await tester.pumpAndSettle();
    expect(find.text('ModalBody'), findsOneWidget);

    // Clear recorded calls and dismiss modal via system back.
    frameworkHandlesBackCalls.clear();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('ModalBody'), findsNothing);
    expect(find.text('OpenModal'), findsOneWidget);
    expect(frameworkHandlesBackCalls.last, isTrue);

    // Subsequent system back returns to Sidebar instead of exiting the app.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.pump();
    expect(find.text('OpenModal'), findsNothing);
    expect(find.text('Sidebar'), findsOneWidget);
    expect(frameworkHandlesBackCalls.last, isFalse);
  });
}
