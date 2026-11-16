import 'package:adwaitter/adwaitter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _combo({required bool search}) => AdwPreferencesGroup(
      children: [
        AdwComboRow<String>(
          title: const Text('Enumeration'),
          enableSearch: search,
          items: const ['unknown', 'custom', 'gpl-2-0', 'bsd'],
          selectedItem: 'unknown',
          onSelected: (_) {},
        ),
      ],
    );

Future<void> _run(
  WidgetTester tester, {
  required Widget Function(Widget combo) wrap,
  required bool search,
  bool changeInsets = true,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewInsets();
  });

  await tester.pumpWidget(AdwApplication(home: wrap(_combo(search: search))));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Enumeration'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byType(AdwPopoverSurface), findsOneWidget);

  if (changeInsets) {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
  }
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('A: AdwWindow home + search popover + keyboard insets',
      (tester) async {
    await _run(
      tester,
      search: true,
      wrap: (c) => AdwWindow(child: ListView(children: [c])),
    );
  });

  testWidgets('B: AdwWindow home + plain popover + keyboard insets',
      (tester) async {
    await _run(
      tester,
      search: false,
      wrap: (c) => AdwWindow(child: ListView(children: [c])),
    );
  });

  testWidgets('C: split view collapsed + plain popover + keyboard insets',
      (tester) async {
    await _run(
      tester,
      search: false,
      wrap: (c) => AdwNavigationSplitView(
        breakpoint: 540,
        sidebar: const Center(child: Text('Sidebar')),
        content: AdwWindow(child: ListView(children: [c])),
      ),
    );
  });

  testWidgets('D: split view collapsed + search popover, NO inset change',
      (tester) async {
    await _run(
      tester,
      search: true,
      changeInsets: false,
      wrap: (c) => AdwNavigationSplitView(
        breakpoint: 540,
        sidebar: const Center(child: Text('Sidebar')),
        content: AdwWindow(child: ListView(children: [c])),
      ),
    );
  });

  testWidgets('E: raw EditableText inside showAdwPopover with requestFocus',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final fn = FocusNode();
    final tc = TextEditingController();
    addTearDown(fn.dispose);
    addTearDown(tc.dispose);

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF3584E4),
        pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
            PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, __) => builder(context),
        ),
        builder: (context, child) => AdwTheme(
          data: AdwThemeData.dark(),
          child: child!,
        ),
        home: Builder(
          builder: (ctx) => AdwButton(
            onPressed: () {
              showAdwPopover(
                context: ctx,
                anchorRect: const Rect.fromLTWH(50, 50, 100, 40),
                builder: (_, __) => AdwPopoverSurface(
                  child: SizedBox(
                    width: 200,
                    height: 40,
                    child: EditableText(
                      controller: tc,
                      focusNode: fn,
                      selectionControls: EmptyTextSelectionControls(),
                      style: const TextStyle(color: Color(0xFFFFFFFF)),
                      cursorColor: const Color(0xFFFFFFFF),
                      backgroundCursorColor: const Color(0xFF000000),
                    ),
                  ),
                ),
              );
            },
            child: const Text('OpenRaw'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenRaw'));
    await tester.pump();
    fn.requestFocus();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
