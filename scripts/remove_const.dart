import 'dart:io';

void main() async {
  final directory = Directory('lib');
  final files = directory.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  final constWidgetRegex = RegExp(r"const\s+([A-Z])");

  for (final file in files) {
    String content = await file.readAsString();
    if (content.contains(constWidgetRegex)) {
      content = content.replaceAllMapped(constWidgetRegex, (match) {
        return match.group(1)!;
      });
      await file.writeAsString(content);
    }
  }
}
