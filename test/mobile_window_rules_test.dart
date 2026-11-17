import 'package:adwaitter/adwaitter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'AdwHeaderBar hides window controls on Android and iOS but keeps them on Linux',
      (WidgetTester tester) async {
    Widget buildHeaderBar() {
      return AdwApplication(
        home: AdwWindow(
          headerBar: const AdwHeaderBar(
            title: Text('Mobile Test'),
          ),
          child: const Center(child: Text('Body')),
        ),
      );
    }

    // Linux: window controls are visible.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(buildHeaderBar());
    await tester.pumpAndSettle();
    expect(find.byType(AdwWindowControlButton), findsWidgets);

    // Android: window controls are hidden.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(buildHeaderBar());
    await tester.pumpAndSettle();
    expect(find.byType(AdwWindowControlButton), findsNothing);

    // iOS: window controls are hidden.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(buildHeaderBar());
    await tester.pumpAndSettle();
    expect(find.byType(AdwWindowControlButton), findsNothing);
  });

  testWidgets(
      'AdwWindow applies SafeArea for system bar and navbar on Android and iOS',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 48);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    await tester.pumpWidget(
      const AdwApplication(
        home: AdwWindow(
          headerBar: AdwHeaderBar(title: Text('TopBar')),
          child: AdwToolbarView(
            content: Center(child: Text('Body')),
            bottomBar: Text('BottomBar'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final topBarRect = tester.getRect(find.byType(AdwHeaderBar));
    final bottomBarRect = tester.getRect(find.text('BottomBar'));

    expect(topBarRect.top, 32.0);
    expect(bottomBarRect.bottom, lessThanOrEqualTo(800.0 - 48.0));
  });

  testWidgets(
      'AdwTextSelectionControls uses Adwaita handles on mobile and Empty on Linux',
      (WidgetTester tester) async {
    late TextSelectionControls resolved;

    Widget buildHarness() {
      return AdwApplication(
        home: Builder(
          builder: (ctx) {
            resolved = AdwTextSelectionControls.forPlatform(ctx);
            return AdwWindow(
              child: AdwEntryRow(
                title: const Text('Name'),
                controller: TextEditingController(text: 'Adwaita'),
              ),
            );
          },
        ),
      );
    }

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();
    expect(resolved, isA<EmptyTextSelectionControls>());

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();
    expect(resolved, isA<AdwTextSelectionControls>());

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();
    expect(resolved, isA<AdwTextSelectionControls>());
  });

  testWidgets(
      'AdwStyleManager supports custom/dynamic accent color and Adwaita accent overrides',
      (WidgetTester tester) async {
    const customWallpaperColor = Color(0xFF8E44AD);
    AdwStyleManager.instance.customAccentColor = customWallpaperColor;
    addTearDown(() {
      AdwStyleManager.instance.customAccentColor = null;
      AdwStyleManager.instance.accentColor = null;
    });

    await tester.pumpWidget(
      AdwApplication(
        home: Builder(
          builder: (ctx) => Container(
            color: AdwTheme.of(ctx).colors.accentColor,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.color, customWallpaperColor);

    AdwStyleManager.instance.accentColor = AdwAccentColor.teal;
    await tester.pumpAndSettle();
    final updatedContainer =
        tester.widget<Container>(find.byType(Container).first);
    expect(updatedContainer.color, AdwColors.accentTeal);
  });

  testWidgets(
      'AdwPopoverSurface aligns arrow with anchorRect instead of forcing center',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final buttonKey = GlobalKey();
    await tester.pumpWidget(
      AdwApplication(
        home: AdwWindow(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 16, right: 12),
              child: AdwButton(
                key: buttonKey,
                onPressed: () {
                  final box =
                      buttonKey.currentContext!.findRenderObject() as RenderBox;
                  final rect = box.localToGlobal(Offset.zero) & box.size;
                  showAdwPopover(
                    context: buttonKey.currentContext!,
                    anchorRect: rect,
                    parentAnchor: AdwPopoverAnchor.bottom,
                    childAnchor: AdwPopoverAnchor.top,
                    constraints: const BoxConstraints(minWidth: 220, maxWidth: 220),
                    builder: (_, __) => const AdwPopoverSurface(
                      arrowSide: AdwPopoverArrowSide.top,
                      child: SizedBox(height: 60, child: Text('Menu')),
                    ),
                  );
                },
                child: const Text('Invoke'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invoke'));
    await tester.pumpAndSettle();

    expect(find.text('Menu'), findsOneWidget);
    final surfaceRect = tester.getRect(find.byType(AdwPopoverSurface));
    final buttonRect = tester.getRect(find.byKey(buttonKey));
    // Popover is clamped near the right edge, so button center is right of surface center.
    expect(buttonRect.center.dx, greaterThan(surfaceRect.center.dx));
  });

  testWidgets(
      'AdwPopoverSurface flips arrow to bottom when invoked near bottom edge',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final buttonKey = GlobalKey();
    await tester.pumpWidget(
      AdwApplication(
        home: AdwWindow(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AdwButton(
                key: buttonKey,
                onPressed: () {
                  final box =
                      buttonKey.currentContext!.findRenderObject() as RenderBox;
                  final rect = box.localToGlobal(Offset.zero) & box.size;
                  showAdwPopover(
                    context: buttonKey.currentContext!,
                    anchorRect: rect,
                    parentAnchor: AdwPopoverAnchor.bottom,
                    childAnchor: AdwPopoverAnchor.top,
                    constraints: const BoxConstraints(minWidth: 200, maxWidth: 200),
                    builder: (_, __) => const AdwPopoverSurface(
                      arrowSide: AdwPopoverArrowSide.top,
                      child: SizedBox(height: 120, child: Text('BottomMenu')),
                    ),
                  );
                },
                child: const Text('BottomInvoke'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('BottomInvoke'));
    await tester.pumpAndSettle();

    expect(find.text('BottomMenu'), findsOneWidget);
    final surfaceRect = tester.getRect(find.byType(AdwPopoverSurface));
    final buttonRect = tester.getRect(find.byKey(buttonKey));
    expect(surfaceRect.bottom, lessThanOrEqualTo(buttonRect.top));

    // Arrow inset should be on the bottom edge (top padding == 6, bottom == 6 + 9).
    final innerPaddings = tester
        .widgetList<Padding>(
          find.descendant(
            of: find.byType(AdwPopoverSurface),
            matching: find.byType(Padding),
          ),
        )
        .toList();
    expect(
      innerPaddings.any(
        (p) => p.padding == const EdgeInsets.only(bottom: 9.0),
      ),
      isTrue,
    );
  });

  testWidgets('AdwTextSelectionControls renders vertical bar handle that widens on touch',
      (WidgetTester tester) async {
    final controls = AdwTextSelectionControls(accentColor: AdwColors.accentBlue);
    await tester.pumpWidget(
      AdwApplication(
        home: Center(
          child: Builder(
            builder: (ctx) => controls.buildHandle(
              ctx,
              TextSelectionHandleType.left,
              18.0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final containerFinder = find.byType(AnimatedContainer);
    expect(tester.getSize(containerFinder).width, 3.0);

    final gesture = await tester.startGesture(tester.getCenter(containerFinder));
    await tester.pumpAndSettle();
    expect(tester.getSize(containerFinder).width, 7.0);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getSize(containerFinder).width, 3.0);
  });

  testWidgets('Open AdwDialog blocks scrolling on underlying view',
      (WidgetTester tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      AdwApplication(
        home: AdwWindow(
          child: Builder(
            builder: (ctx) => ListView(
              controller: scrollController,
              children: [
                AdwButton(
                  onPressed: () => showAdwDialog<void>(
                    context: ctx,
                    builder: (_) => const AdwDialog(
                      title: 'BlockingDialog',
                      child: SizedBox(height: 100, child: Text('DialogBody')),
                    ),
                  ),
                  child: const Text('OpenBlockingDialog'),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OpenBlockingDialog'));
    await tester.pumpAndSettle();
    expect(find.text('DialogBody'), findsOneWidget);

    // Dragging on the scrim outside the dialog must NOT scroll the background ListView.
    await tester.dragFrom(const Offset(20, 40), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(scrollController.offset, 0.0);
  });

  testWidgets('Open AdwPopover blocks scrolling on underlying view',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final scrollController = ScrollController();
    final buttonKey = GlobalKey();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      AdwApplication(
        home: AdwWindow(
          child: ListView(
            controller: scrollController,
            children: [
              AdwButton(
                key: buttonKey,
                onPressed: () {
                  final box =
                      buttonKey.currentContext!.findRenderObject() as RenderBox;
                  final rect = box.localToGlobal(Offset.zero) & box.size;
                  showAdwPopover(
                    context: buttonKey.currentContext!,
                    anchorRect: rect,
                    parentAnchor: AdwPopoverAnchor.bottom,
                    childAnchor: AdwPopoverAnchor.top,
                    builder: (_, __) => const AdwPopoverSurface(
                      child: Text('PopoverMenu'),
                    ),
                  );
                },
                child: const Text('OpenPopover'),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OpenPopover'));
    await tester.pumpAndSettle();
    expect(find.text('PopoverMenu'), findsOneWidget);

    // Dragging outside the popover must NOT scroll the background ListView.
    await tester.dragFrom(const Offset(200, 400), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(scrollController.offset, 0.0);
  });

  testWidgets(
      'AdwWindow and AdwDialog resize/shift above virtual keyboard viewInsets on Android',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(
      AdwApplication(
        home: AdwWindow(
          headerBar: const AdwHeaderBar(title: Text('KeyboardTest')),
          child: Builder(
            builder: (ctx) => Align(
              alignment: Alignment.bottomCenter,
              child: AdwButton(
                onPressed: () => showAdwDialog<void>(
                  context: ctx,
                  builder: (_) => const AdwDialog(
                    title: 'InputDialog',
                    child: SizedBox(height: 100, child: Text('InputBody')),
                  ),
                ),
                child: const Text('BottomButton'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buttonRect = tester.getRect(find.text('BottomButton'));
    // Must sit right above the 300px keyboard without adding the 48px navbar twice.
    expect(buttonRect.bottom, lessThanOrEqualTo(500.0));
    expect(buttonRect.bottom, greaterThan(452.0));

    await tester.tap(find.text('BottomButton'));
    await tester.pumpAndSettle();
    final dialogRect = tester.getRect(find.byType(AdwDialog));
    expect(dialogRect.bottom, lessThanOrEqualTo(500.0));
  });

  testWidgets(
      'Transitioning viewInsets from 0 to >0 preserves widget state and focus',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding.zero;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(
      const AdwApplication(
        home: AdwWindow(
          child: Center(
            child: AdwEntryRow(
              title: Text('Entry'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AdwEntryRow));
    await tester.pump();
    final editableBefore = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editableBefore.widget.focusNode.hasFocus, isTrue);

    // Simulate virtual keyboard opening without unmounting AdwEntryRow.
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump(const Duration(milliseconds: 300));
    final editableAfter = tester.state<EditableTextState>(find.byType(EditableText));
    expect(identical(editableBefore, editableAfter), isTrue);
    expect(editableAfter.widget.focusNode.hasFocus, isTrue);
  });

  testWidgets('AdwSwitch triggers haptic lock on Android and iOS but not Linux',
      (WidgetTester tester) async {
    final List<String> hapticCalls = <String>[];
    final List<bool> androidChannelCalls = <bool>[];
    const styleChannel = MethodChannel('libadwaitter/style');

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'HapticFeedback.vibrate') {
          hapticCalls.add(methodCall.arguments as String? ?? 'default');
        }
        return null;
      },
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      styleChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'performSwitchHaptic') {
          final args = methodCall.arguments as Map<dynamic, dynamic>;
          androidChannelCalls.add(args['checked'] as bool);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(styleChannel, null);
    });

    bool value = false;
    Widget buildSwitch() => AdwApplication(
          home: AdwWindow(
            child: Center(
              child: StatefulBuilder(
                builder: (_, setState) => AdwSwitch(
                  value: value,
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
            ),
          ),
        );

    // Android: tap triggers native performSwitchHaptic with target checked state.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(buildSwitch());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AdwSwitch));
    await tester.pumpAndSettle();
    expect(androidChannelCalls, [true]);

    // iOS: tap triggers lightImpact haptic.
    hapticCalls.clear();
    androidChannelCalls.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(buildSwitch());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AdwSwitch));
    await tester.pumpAndSettle();
    expect(hapticCalls, ['HapticFeedbackType.lightImpact']);

    // Linux: no haptic feedback.
    hapticCalls.clear();
    androidChannelCalls.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(buildSwitch());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AdwSwitch));
    await tester.pumpAndSettle();
    expect(hapticCalls, isEmpty);
    expect(androidChannelCalls, isEmpty);
  });

  testWidgets('AdwWindow removes top safe area in Android desktop/multi-window mode',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 0);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    const styleChannel = MethodChannel('libadwaitter/style');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      styleChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'isInMultiWindowMode') {
          return true;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(styleChannel, null);
    });

    await tester.pumpWidget(
      const AdwApplication(
        home: AdwWindow(
          headerBar: AdwHeaderBar(title: Text('DesktopAndroid')),
          child: Center(child: Text('Body')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final topBarRect = tester.getRect(find.byType(AdwHeaderBar));
    expect(topBarRect.top, 0.0);
  });

  testWidgets(
      'AdwNavigationSplitView + AdwToolbarView protects non-scrollable bottom content on mobile',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 48);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    final controller = AdwCarouselController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AdwApplication(
        home: AdwWindow(
          child: AdwNavigationSplitView(
            breakpoint: 600,
            sidebar: const AdwToolbarView(
              bottomSafeArea: false,
              topBar: AdwHeaderBar(title: Text('Sidebar')),
              content: SizedBox.expand(child: Text('SidebarBody')),
            ),
            content: AdwToolbarView(
              topBar: const AdwHeaderBar(title: Text('Content')),
              content: Column(
                children: [
                  Expanded(
                    child: AdwCarousel(
                      controller: controller,
                      children: const [Center(child: Text('Slide1'))],
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    child: Center(
                      child: AdwCarouselIndicatorDots(controller: controller),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final indicatorRect = tester.getRect(find.byType(AdwCarouselIndicatorDots));
    expect(indicatorRect.bottom, lessThanOrEqualTo(800.0 - 48.0));

    // Expanded (landscape) split view also protects non-scrollable bottom content
    // while allowing scrollable panes with bottomSafeArea: false to go edge-to-edge.
    tester.view.physicalSize = const Size(900, 500);
    tester.view.padding = const FakeViewPadding(top: 24, left: 48, bottom: 32);
    await tester.pumpAndSettle();

    final expandedIndicatorRect =
        tester.getRect(find.byType(AdwCarouselIndicatorDots));
    expect(expandedIndicatorRect.bottom, lessThanOrEqualTo(500.0 - 32.0));

    final sidebarRect = tester.getRect(find.text('SidebarBody'));
    expect(sidebarRect.bottom, 500.0);
  });

  testWidgets(
      'AdwDialog bottom sheet avoids double bottom padding when wrapping AdwToolbarView',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 48);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    await tester.pumpWidget(
      const AdwApplication(
        home: AdwDialog(
          title: 'Sheet',
          contentHeight: 300,
          child: AdwToolbarView(
            topBar: AdwHeaderBar(isFlat: true, title: Text('Sheet')),
            content: Align(
              alignment: Alignment.bottomCenter,
              child: Text('SheetFooter'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final footerRect = tester.getRect(find.text('SheetFooter'));
    // Exactly 48px above bottom (not 96px from double SafeArea).
    expect(footerRect.bottom, 800.0 - 48.0);
  });

  testWidgets('Floating AdwDialog does not reserve system navbar inset',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 48);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    await tester.pumpWidget(
      const AdwApplication(
        home: AdwDialog(
          title: 'Floating',
          presentationMode: AdwDialogPresentationMode.floating,
          contentHeight: 300,
          child: AdwToolbarView(
            content: Align(
              alignment: Alignment.bottomCenter,
              child: Text('FloatFooter'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dialogRect = tester.getRect(find.byType(AdwToolbarView));
    final footerRect = tester.getRect(find.text('FloatFooter'));
    expect(footerRect.bottom, lessThanOrEqualTo(dialogRect.bottom));
    expect(dialogRect.bottom - footerRect.bottom, lessThan(10.0));
  });
}
