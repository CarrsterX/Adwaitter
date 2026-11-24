import 'dart:io' show File, Process;
import 'dart:typed_data';

Future<String?> querySystemEmojiFontPath() async {
  final res = await Process.run(
    'fc-match',
    <String>['--format=%{file}', 'emoji:color=true'],
  );
  if (res.exitCode == 0) {
    final out = (res.stdout as String).trim();
    if (out.isNotEmpty) return out;
  }
  return null;
}

Future<Uint8List?> readLocalFileBytes(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  return file.readAsBytes();
}
