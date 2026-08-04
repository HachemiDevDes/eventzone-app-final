import 'dart:convert';
import 'dart:io';

void main() {
  final keys = {
    "Integrations": {
      "en": "Integrations",
      "fr": "Intégrations",
      "ar": "التكاملات"
    },
    "CRM Integrations": {
      "en": "CRM Integrations",
      "fr": "Intégrations CRM",
      "ar": "تكاملات إدارة علاقات العملاء (CRM)"
    },
    "Select Format": {
      "en": "Select Format",
      "fr": "Sélectionner le format",
      "ar": "اختر التنسيق"
    },
    "Excel Spreadsheet": {
      "en": "Excel Spreadsheet",
      "fr": "Feuille de calcul Excel",
      "ar": "جدول بيانات Excel"
    },
    "Plain CSV file": {
      "en": "Plain CSV file",
      "fr": "Fichier CSV simple",
      "ar": "ملف CSV عادي"
    },
    "Export Now": {
      "en": "Export Now",
      "fr": "Exporter maintenant",
      "ar": "تصدير الآن"
    },
    "Export Summary": {
      "en": "Export Summary",
      "fr": "Résumé de l'exportation",
      "ar": "ملخص التصدير"
    },
    "Done": {
      "en": "Done",
      "fr": "Terminé",
      "ar": "تم"
    }
  };

  final Map<String, String> files = {
    "en": "assets/translations/en.json",
    "fr": "assets/translations/fr.json",
    "ar": "assets/translations/ar.json"
  };

  for (var entry in files.entries) {
    final lang = entry.key;
    final path = entry.value;

    final file = File(path);
    if (file.existsSync()) {
      final content = file.readAsStringSync();
      final Map<String, dynamic> json = jsonDecode(content);

      for (var keyEntry in keys.entries) {
        if (!json.containsKey(keyEntry.key)) {
          json[keyEntry.key] = keyEntry.value[lang];
        }
      }

      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    }
  }
}
