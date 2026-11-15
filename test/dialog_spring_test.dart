import 'package:adwaitter/adwaitter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showAdwDialog animates floating and bottomSheet modes without NaN',
      (WidgetTester tester) async {
    Future<void> openAndClose(Size windowSize) async {
      await tester.pumpWidget(
        AdwApplication(
          home: Center(
            child: SizedBox(
              width: windowSize.width,
              height: windowSize.height,
              child: Builder(
                builder: (context) => AdwButton(
                  onPressed: () {
                    showAdwDialog<void>(
                      context: context,
                      barrierDismissible: true,
                      builder: (_) => const AdwDialog(
                        title: 'Test Dialog',
                        child: Center(child: Text('Dialog Body')),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Dialog Body'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }

    // Floating mode
    await tester.binding.setSurfaceSize(const Size(800, 600));
    await openAndClose(const Size(800, 600));

    // Bottom sheet mode
    await tester.binding.setSurfaceSize(const Size(380, 600));
    await openAndClose(const Size(380, 600));

    await tester.binding.setSurfaceSize(null);
  });
}
