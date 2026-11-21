import 'dart:io';

/// CLI UI starter generator for `adwaitter`.
///
/// Replaces Flutter's default Material counter template in `lib/main.dart` with
/// a pure Adwaita-styled counter app using `package:adwaitter/adwaitter.dart`.
///
/// Usage:
///   dart run adwaitter:setup [options]
void main(List<String> args) {
  final options = _parseArgs(args);
  if (options.showHelp) {
    _printUsage();
    return;
  }

  final cwd = Directory.current;
  final pubspecFile = File('${cwd.path}/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln(
      'Error: pubspec.yaml not found in ${cwd.path}. Run this command from the root of your Flutter project.',
    );
    exitCode = 1;
    return;
  }

  final resolvedTitle = options.title ?? _inferTitleFromPubspec(pubspecFile);
  final mainFile = File('${cwd.path}/lib/main.dart');

  if (options.dryRun) {
    stdout.writeln('[dry-run] Would generate Adwaitter counter app in: ${mainFile.path}');
    stdout.writeln('[dry-run] Title: "$resolvedTitle"');
    return;
  }

  if (mainFile.existsSync() &&
      options.backup &&
      !File('${mainFile.path}.bak').existsSync()) {
    mainFile.copySync('${mainFile.path}.bak');
    stdout.writeln('Backup created: lib/main.dart.bak');
  }

  mainFile.parent.createSync(recursive: true);
  mainFile.writeAsStringSync(_renderCounterMainDart(title: resolvedTitle));
  stdout.writeln('Generated lib/main.dart with the Adwaitter counter app.');
  stdout.writeln('\nRun your app with: flutter run');
}

class _SetupOptions {
  final bool showHelp;
  final bool dryRun;
  final bool backup;
  final String? title;

  const _SetupOptions({
    required this.showHelp,
    required this.dryRun,
    required this.backup,
    required this.title,
  });
}

_SetupOptions _parseArgs(List<String> args) {
  bool showHelp = false;
  bool dryRun = false;
  bool backup = true;
  String? title;

  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '-h' || arg == '--help') {
      showHelp = true;
    } else if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg == '--no-backup') {
      backup = false;
    } else if (arg == '--title' && i + 1 < args.length) {
      title = args[++i];
    } else if (arg.startsWith('--title=')) {
      title = arg.substring('--title='.length);
    }
  }

  return _SetupOptions(
    showHelp: showHelp,
    dryRun: dryRun,
    backup: backup,
    title: title,
  );
}

void _printUsage() {
  stdout.writeln('''
Adwaitter UI Starter Generator

Replaces Flutter's default Material counter app in lib/main.dart with a pure
GNOME Adwaita counter app powered by Adwaitter.

Usage:
  dart run adwaitter:setup [options]

Options:
  --title <name>   App and header bar title (defaults to pubspec.yaml name)
  --dry-run        Preview changes without writing files
  --no-backup      Skip creating lib/main.dart.bak
  -h, --help       Show this help message
''');
}

String _inferTitleFromPubspec(File pubspecFile) {
  final lines = pubspecFile.readAsLinesSync();
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('name:')) {
      final raw = trimmed.substring('name:'.length).trim();
      if (raw.isEmpty) break;
      return raw
          .split(RegExp(r'[_\-]+'))
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
    }
  }
  return 'Adwaitter App';
}

String _escapeDartSingleQuote(String input) {
  return input.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}

String _renderCounterMainDart({required String title}) {
  final escapedTitle = _escapeDartSingleQuote(title);
  return '''import 'package:flutter/widgets.dart';
import 'package:adwaitter/adwaitter.dart';

void main() {
  runApp(const CounterApp());
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdwApplication(
      title: '$escapedTitle',
      home: AdwWindow(
        child: CounterHomePage(),
      ),
    );
  }
}

class CounterHomePage extends StatefulWidget {
  const CounterHomePage({super.key});

  @override
  State<CounterHomePage> createState() => _CounterHomePageState();
}

class _CounterHomePageState extends State<CounterHomePage> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    final theme = AdwTheme.of(context);

    return AdwToolbarView(
      bottomSafeArea: false,
      topBar: const AdwHeaderBar(
        showWindowControls: true,
        title: Text('$escapedTitle'),
      ),
      content: AdwPreferencesPage(
        title: const Text('Counter Demo'),
        description: const Text(
          'Cross-platform Flutter application styled with Adwaitter.',
        ),
        children: [
          AdwPreferencesGroup(
            children: [
              AdwActionRow(
                title: const Text('Button Taps'),
                subtitle: const Text('You have pushed the button this many times'),
                suffix: Text(
                  '\$_counter',
                  style: theme.typography.title2,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AdwButton(
                onPressed: _counter > 0
                    ? () => setState(() => _counter = 0)
                    : null,
                child: const Text('Reset'),
              ),
              const SizedBox(width: 12),
              AdwButton.suggested(
                isPill: true,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                onPressed: () => setState(() => _counter++),
                child: const Text('Increment'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
''';
}
