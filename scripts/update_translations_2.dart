import 'dart:convert';
import 'dart:io';

void main() async {
  final newEn = {
    "English": "English",
    "French": "French",
    "Arabic": "Arabic",
    "Français": "Français",
    "العربية": "العربية"
  };

  final newFr = {
    "English": "Anglais",
    "French": "Français",
    "Arabic": "Arabe",
    "Français": "Français",
    "العربية": "العربية"
  };

  final newAr = {
    "English": "الإنجليزية",
    "French": "الفرنسية",
    "Arabic": "العربية",
    "Français": "Français",
    "العربية": "العربية"
  };

  Future<void> updateJson(String filepath, Map<String, String> newData) async {
    final file = File(filepath);
    final String content = await file.readAsString();
    final Map<String, dynamic> data = json.decode(content);
    data.addAll(newData);
    await file.writeAsString(json.encode(data));
  }

  final basePath = 'assets/translations';
  await updateJson('$basePath/en.json', newEn);
  await updateJson('$basePath/fr.json', newFr);
  await updateJson('$basePath/ar.json', newAr);
  print('Updated JSON files successfully.');
}
