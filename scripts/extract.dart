import 'dart:io';
import 'dart:convert';

void main() async {
  final directory = Directory('lib');
  final files = directory.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  final Map<String, String> translations = {};
  
  // Matches Text('Something') or Text("Something")
  // Group 1 is the quote type, Group 2 is the string content
  final textRegex = RegExp(r"Text\((['" r'"])([^' r"'" r'"\$]+)\1\)');
  
  // Matches const Text('Something')
  final constTextRegex = RegExp(r"const\s+Text\((['" r'"])([^' r"'" r'"\$]+)\1\)');
  
  // Matches hintText: 'Something'
  final hintRegex = RegExp(r"hintText:\s*(['" r'"])([^' r"'" r'"\$]+)\1');
  
  // Matches labelText: 'Something'
  final labelRegex = RegExp(r"labelText:\s*(['" r'"])([^' r"'" r'"\$]+)\1');

  // Regex to remove 'const' when the widget tree inside it gets a .tr() which makes it non-const
  // We'll just do a simpler pass: if a line has .tr(), we try to strip leading 'const ' on that line if it applies to Text
  // Actually the regex constTextRegex handles `const Text('...')` -> `Text('...'.tr())`.

  for (final file in files) {
    String content = await file.readAsString();
    bool modified = false;

    // Handle const Text('...')
    content = content.replaceAllMapped(constTextRegex, (match) {
      final quote = match.group(1)!;
      final text = match.group(2)!;
      if (text.trim().isEmpty) return match.group(0)!; // skip empty
      translations[text] = text;
      modified = true;
      return "Text($quote$text$quote.tr())";
    });

    // Handle Text('...')
    content = content.replaceAllMapped(textRegex, (match) {
      final quote = match.group(1)!;
      final text = match.group(2)!;
      if (text.trim().isEmpty) return match.group(0)!;
      translations[text] = text;
      modified = true;
      return "Text($quote$text$quote.tr())";
    });

    // Handle hintText: '...'
    content = content.replaceAllMapped(hintRegex, (match) {
      final quote = match.group(1)!;
      final text = match.group(2)!;
      if (text.trim().isEmpty) return match.group(0)!;
      translations[text] = text;
      modified = true;
      return "hintText: $quote$text$quote.tr()";
    });

    // Handle labelText: '...'
    content = content.replaceAllMapped(labelRegex, (match) {
      final quote = match.group(1)!;
      final text = match.group(2)!;
      if (text.trim().isEmpty) return match.group(0)!;
      translations[text] = text;
      modified = true;
      return "labelText: $quote$text$quote.tr()";
    });

    if (modified) {
      if (!content.contains("import 'package:easy_localization/easy_localization.dart';")) {
        // Add import after the last import, or at top
        final importIdx = content.lastIndexOf(RegExp(r"^import '.*';$", multiLine: true));
        if (importIdx != -1) {
          final insertIdx = content.indexOf('\n', importIdx) + 1;
          content = "${content.substring(0, insertIdx)}import 'package:easy_localization/easy_localization.dart';\n${content.substring(insertIdx)}";
        } else {
          content = "import 'package:easy_localization/easy_localization.dart';\n\n$content";
        }
      }
      await file.writeAsString(content);
      print("Modified ${file.path}");
    }
  }

  // Also read existing en.json if it exists and merge
  final jsonFile = File('assets/translations/en.json');
  Map<String, dynamic> existing = {};
  if (jsonFile.existsSync()) {
    try {
      existing = jsonDecode(jsonFile.readAsStringSync());
    } catch (_) {}
  }
  
  for (final key in translations.keys) {
    if (!existing.containsKey(key)) {
      existing[key] = translations[key];
    }
  }
  
  final encoder = JsonEncoder.withIndent('  ');
  await jsonFile.writeAsString(encoder.convert(existing));
  print("Wrote ${existing.length} keys to en.json");
}
