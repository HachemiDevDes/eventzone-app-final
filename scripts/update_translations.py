import json
import os

new_en = {
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
}

new_fr = {
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
}

new_ar = {
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
}

def update_json(filepath, new_data):
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    data.update(new_data)
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

base_path = "d:/Antigravity Projects/Eventzone app/assets/translations"
update_json(f"{base_path}/en.json", new_en)
update_json(f"{base_path}/fr.json", new_fr)
update_json(f"{base_path}/ar.json", new_ar)
print("Updated JSON files")
