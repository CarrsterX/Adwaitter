import 'package:adwaitter/adwaitter.dart';
import 'package:flutter/widgets.dart';

void main() {
  runApp(const AdwaitterExampleApp());
}

/// Minimal example showcasing [AdwApplication], [AdwWindow], [AdwToolbarView],
/// [AdwHeaderBar], [AdwPreferencesPage], and [AdwButton].
class AdwaitterExampleApp extends StatelessWidget {
  const AdwaitterExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdwApplication(
      title: 'Adwaitter Example',
      home: _ExampleHomePage(),
    );
  }
}

class _ExampleHomePage extends StatefulWidget {
  const _ExampleHomePage();

  @override
  State<_ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<_ExampleHomePage> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return AdwWindow(
      child: AdwToolbarView(
        topBar: const AdwHeaderBar(
          title: Text('Adwaitter Example'),
        ),
        content: AdwPreferencesPage(
          children: [
            AdwPreferencesGroup(
              title: const Text('Counter'),
              children: [
                AdwActionRow(
                  title: const Text('Button presses'),
                  subtitle: Text('$_counter'),
                  trailing: AdwButton.suggested(
                    onPressed: () => setState(() => _counter++),
                    child: const Text('Increment'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
