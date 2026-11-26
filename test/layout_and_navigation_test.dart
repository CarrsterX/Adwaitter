import 'package:adwaitter/adwaitter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Layout widgets', () {
    testWidgets('AdwClamp respects maximumSize and minimumSize',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const AdwApplication(
          home: AdwWindow(
            child: Center(
              child: AdwClamp(
                maximumSize: 500,
                minimumSize: 280,
                child: SizedBox(
                  key: ValueKey('clamped'),
                  width: double.infinity,
                  height: 40,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byKey(const ValueKey('clamped')));
      expect(size.width, 500);
    });

    testWidgets('AdwBreakpointBin switches breakpoint on width change',
        (WidgetTester tester) async {
      String? activeBreakpoint;

      Widget buildApp() {
        return AdwApplication(
          home: AdwWindow(
            child: AdwBreakpointBin(
              breakpoints: const [
                AdwBreakpoint(name: 'compact', maxWidth: 500),
              ],
              builder: (context, breakpoint, constraints) {
                activeBreakpoint = breakpoint?.name ?? 'wide';
                return Text('Mode: $activeBreakpoint');
              },
            ),
          ),
        );
      }

      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Mode: wide'), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(400, 600));
      await tester.pumpAndSettle();
      expect(find.text('Mode: compact'), findsOneWidget);
    });

    testWidgets('AdwMultiLayoutView swaps active layout by name',
        (WidgetTester tester) async {
      String layoutName = 'row';

      await tester.pumpWidget(
        AdwApplication(
          home: StatefulBuilder(
            builder: (context, setState) {
              return AdwWindow(
                child: Column(
                  children: [
                    AdwButton(
                      onPressed: () => setState(() => layoutName = 'column'),
                      child: const Text('Switch Layout'),
                    ),
                    Expanded(
                      child: AdwMultiLayoutView(
                        layoutName: layoutName,
                        children: const {
                          'a': Text('Slot A'),
                          'b': Text('Slot B'),
                        },
                        layouts: const [
                          AdwLayout(
                            name: 'row',
                            content: Row(
                              key: ValueKey('row-layout'),
                              children: [
                                AdwLayoutSlot(id: 'a'),
                                AdwLayoutSlot(id: 'b'),
                              ],
                            ),
                          ),
                          AdwLayout(
                            name: 'column',
                            content: Column(
                              key: ValueKey('col-layout'),
                              children: [
                                AdwLayoutSlot(id: 'a'),
                                AdwLayoutSlot(id: 'b'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('row-layout')), findsOneWidget);
      expect(find.text('Slot A'), findsOneWidget);
      expect(find.text('Slot B'), findsOneWidget);

      await tester.tap(find.text('Switch Layout'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('col-layout')), findsOneWidget);
    });

    testWidgets('AdwWrapBox lays out all children', (WidgetTester tester) async {
      await tester.pumpWidget(
        const AdwApplication(
          home: AdwWindow(
            child: AdwWrapBox(
              childSpacing: 8,
              lineSpacing: 8,
              children: [
                Text('Tag 1'),
                Text('Tag 2'),
                Text('Tag 3'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tag 1'), findsOneWidget);
      expect(find.text('Tag 2'), findsOneWidget);
      expect(find.text('Tag 3'), findsOneWidget);
    });
  });

  group('Navigation widgets', () {
    testWidgets('AdwNavigationView pushes and pops pages',
        (WidgetTester tester) async {
      final controller = AdwNavigationViewController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        AdwApplication(
          home: AdwWindow(
            child: AdwNavigationView(
              controller: controller,
              initialPage: AdwNavigationPage(
                title: 'Home',
                child: AdwToolbarView(
                  topBar: const AdwHeaderBar(
                    title: Text('Home'),
                    showWindowControls: false,
                  ),
                  content: Center(
                    child: AdwButton(
                      onPressed: () {
                        controller.push(
                          const AdwNavigationPage(
                            title: 'Details',
                            child: AdwToolbarView(
                              topBar: AdwHeaderBar(
                                title: Text('Details'),
                                showWindowControls: false,
                              ),
                              content: Center(child: Text('Detail Body')),
                            ),
                          ),
                        );
                      },
                      child: const Text('Open Details'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open Details'), findsOneWidget);

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Body'), findsOneWidget);
      expect(controller.canPop, isTrue);

      controller.pop();
      await tester.pumpAndSettle();
      expect(find.text('Open Details'), findsOneWidget);
      expect(controller.canPop, isFalse);
    });

    testWidgets('AdwTabView and AdwTabBar add, switch, and close tabs',
        (WidgetTester tester) async {
      final controller = AdwTabViewController(
        initialPages: [
          AdwTabPage(title: 'Tab 1', child: const Center(child: Text('Body 1'))),
          AdwTabPage(title: 'Tab 2', child: const Center(child: Text('Body 2'))),
        ],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        AdwApplication(
          home: AdwWindow(
            child: AdwToolbarView(
              topBar: AdwTabBar(controller: controller, autohide: false),
              content: AdwTabView(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Body 1'), findsOneWidget);

      await tester.tap(find.text('Tab 2'));
      await tester.pumpAndSettle();
      expect(controller.selectedIndex, 1);
      expect(find.text('Body 2'), findsOneWidget);

      controller.addPage(
        AdwTabPage(title: 'Tab 3', child: const Center(child: Text('Body 3'))),
      );
      await tester.pumpAndSettle();
      expect(controller.pages.length, 3);

      controller.closePage(controller.pages.last);
      await tester.pumpAndSettle();
      expect(controller.pages.length, 2);
    });

    testWidgets('AdwViewSwitcher switches currentIndex on tap',
        (WidgetTester tester) async {
      int index = 0;

      await tester.pumpWidget(
        AdwApplication(
          home: StatefulBuilder(
            builder: (context, setState) {
              return AdwWindow(
                child: Center(
                  child: AdwViewSwitcher(
                    currentIndex: index,
                    onIndexChanged: (i) => setState(() => index = i),
                    items: const [
                      AdwViewSwitcherItem(title: 'Overview'),
                      AdwViewSwitcherItem(title: 'Settings'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(index, 1);
    });

    testWidgets('AdwOverlaySplitView toggles sidebar visibility',
        (WidgetTester tester) async {
      bool showSidebar = true;

      await tester.binding.setSurfaceSize(const Size(1000, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        AdwApplication(
          home: StatefulBuilder(
            builder: (context, setState) {
              return AdwWindow(
                child: AdwOverlaySplitView(
                  showSidebar: showSidebar,
                  onShowSidebarChanged: (v) => setState(() => showSidebar = v),
                  sidebar: const Center(child: Text('Sidebar Pane')),
                  content: Center(
                    child: AdwButton(
                      onPressed: () =>
                          setState(() => showSidebar = !showSidebar),
                      child: const Text('Toggle Sidebar'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sidebar Pane'), findsOneWidget);

      await tester.tap(find.text('Toggle Sidebar'));
      await tester.pumpAndSettle();
      expect(showSidebar, isFalse);
    });
  });
}
