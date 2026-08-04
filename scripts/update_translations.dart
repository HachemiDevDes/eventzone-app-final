import 'dart:convert';
import 'dart:io';

void main() async {
  final newEn = {
    "Language": "Language",
    "Select Language": "Select Language",
    "Preferences": "Preferences",
    "Subscription": "Subscription",
    "Active": "Active",
    "Expired": "Expired",
    "Information": "Information",
    "About us": "About us",
    "Contact us": "Contact us",
    "Account": "Account",
    "Support": "Support",
    "Terms and Privacy Policy": "Terms and Privacy Policy",
    "Logout": "Logout"
  };

  final newFr = {
    "Language": "Langue",
    "Select Language": "Choisir la langue",
    "Preferences": "Préférences",
    "Subscription": "Abonnement",
    "Active": "Actif",
    "Expired": "Expiré",
    "Information": "Informations",
    "About us": "À propos de nous",
    "Contact us": "Nous contacter",
    "Account": "Compte",
    "Support": "Assistance",
    "Terms and Privacy Policy": "Conditions et confidentialité",
    "Logout": "Déconnexion"
  };

  final newAr = {
    "Language": "اللغة",
    "Select Language": "اختر اللغة",
    "Preferences": "التفضيلات",
    "Subscription": "الاشتراك",
    "Active": "نشط",
    "Expired": "منتهي",
    "Information": "المعلومات",
    "About us": "من نحن",
    "Contact us": "اتصل بنا",
    "Account": "الحساب",
    "Support": "الدعم",
    "Terms and Privacy Policy": "الشروط والخصوصية",
    "Logout": "تسجيل الخروج"
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
