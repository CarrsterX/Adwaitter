import 'package:adwaitter/adwaitter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Tab traverses Search -> Menu -> Sidebar (1 stop) -> Content buttons, and ArrowDown moves within sidebar',
    (WidgetTester tester) async {
      int button1Clicks = 0;
      int button2Clicks = 0;
      String? activatedSidebar;

      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        AdwApplication(
          home: AdwNavigationSplitView(
            sidebar: AdwToolbarView(
              topBar: AdwHeaderBar(
                isFlat: true,
                showWindowControls: false,
                start: AdwButton.flat(
                  onPressed: () {},
                  child: const Text('Search'),
                ),
                end: AdwButton.flat(
                  onPressed: () {},
                  child: const Text('Menu'),
                ),
              ),
              content: AdwSidebarFocusGroup(
                child: ListView(
                  children: [
                    AdwSidebarItem(
                      title: const Text('Item A'),
                      isSelected: true,
                      onTap: () => activatedSidebar = 'A',
                    ),
                    AdwSidebarItem(
                      title: const Text('Item B'),
                      onTap: () => activatedSidebar = 'B',
                    ),
                    AdwSidebarItem(
                      title: const Text('Item C'),
                      onTap: () => activatedSidebar = 'C',
                    ),
                  ],
                ),
              ),
            ),
            content: AdwToolbarView(
              topBar: const AdwHeaderBar(
                isFlat: true,
                showWindowControls: false,
              ),
              content: AdwStatusPage(
                title: const Text('Split Views'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AdwButton.pill(
                      onPressed: () => button1Clicks++,
                      child: const Text('Navigation Split View'),
                    ),
                    const SizedBox(height: 12),
                    AdwButton.pill(
                      onPressed: () => button2Clicks++,
                      child: const Text('Overlay Split View'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      String? focusedLabel() {
        final ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx == null) return null;
        String? found;
        void visit(Element e) {
          if (found != null) return;
          if (e.widget is Text) {
            found = (e.widget as Text).data;
            return;
          }
          e.visitChildren(visit);
        }

        ctx.visitChildElements(visit);
        return found;
      }

      // 1. Tab -> Search
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedLabel(), 'Search');

      // 2. Tab -> Menu
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedLabel(), 'Menu');

      // 3. Tab -> Sidebar (Item A)
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedLabel(), 'Item A');

      // 4. ArrowDown inside sidebar -> Item B, Enter activates Item B
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusedLabel(), 'Item B');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activatedSidebar, 'B');

      // 5. Tab from sidebar -> MUST jump straight to Content Button 1 (NOT Item C, NOT Search!)
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedLabel(), 'Navigation Split View');

      // 6. Enter activates Button 1
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(button1Clicks, 1);

      // 7. Tab -> Content Button 2, Space activates Button 2
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedLabel(), 'Overlay Split View');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(button2Clicks, 1);
    },
  );
}
