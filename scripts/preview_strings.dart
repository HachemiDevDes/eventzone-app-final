import 'dart:io';

void main() async {
  final directory = Directory('lib');
  final files = directory.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  final stringPattern = RegExp(r'(?:Text\(\s*|hintText:\s*|labelText:\s*|tooltip:\s*)([\x27\x22])(.*?)\1');
  
  final totalStrings = <String>{};
  
  for (final file in files) {
    final content = await file.readAsString();
    final matches = stringPattern.allMatches(content);
    for (final match in matches) {
      final text = match.group(2)!;
      if (!text.contains(r'$') && !text.contains('{') && text.trim().isNotEmpty) {
        totalStrings.add(text);
      }
    }
  }
  
  print('Total Dart files: ${files.length}');
  print('Total unique translatable strings found: ${totalStrings.length}');
  
  final outList = totalStrings.toList()..sort();
  final outFile = File('extracted_strings_preview.txt');
  await outFile.writeAsString(outList.join('\n'));
}
