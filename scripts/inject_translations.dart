import 'dart:io';

void main() async {
  final directory = Directory('lib');
  final files = directory.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  // This matches Text('...'), hintText: '...', labelText: '...', tooltip: '...', label: Text('...')
  // but only if NOT followed by .tr()
  final stringPattern = RegExp(r'(Text\(\s*|hintText:\s*|labelText:\s*|tooltip:\s*|label:\s*Text\(\s*|title:\s*Text\(\s*|subtitle:\s*Text\(\s*)([\x27\x22])(.*?)\2(?!\s*\.tr\(\))');
  
  for (final file in files) {
    String content = await file.readAsString();
    final original = content;
    
    content = content.replaceAllMapped(stringPattern, (match) {
      final prefix = match.group(1)!;
      final quote = match.group(2)!;
      final text = match.group(3)!;
      
      if (text.contains(r'$') || text.contains('{') || text.trim().isEmpty) {
        return match.group(0)!;
      }
      
      return '$prefix$quote$text$quote.tr()';
    });
    
    // Attempt to remove some const keywords that might break
    content = content.replaceAll(RegExp(r'const\s+Text\('), 'Text(');
    content = content.replaceAll(RegExp(r'const\s+Center\(\s*child:\s*Text\('), 'Center(child: Text(');
    content = content.replaceAll(RegExp(r'const\s+Padding\('), 'Padding(');
    content = content.replaceAll(RegExp(r'const\s+SizedBox\('), 'SizedBox(');
    content = content.replaceAll(RegExp(r'const\s+Expanded\('), 'Expanded(');
    
    if (content != original) {
      // make sure easy_localization is imported if we added .tr()
      if (!content.contains('package:easy_localization/easy_localization.dart')) {
        content = "import 'package:easy_localization/easy_localization.dart';\n$content";
      }
      await file.writeAsString(content);
      print('Updated ${file.path}');
    }
  }
}
