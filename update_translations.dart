import 'dart:convert';
import 'dart:io';

void main() {
  final keys = {
    "scan_qr_error_invalid_code": {
      "en": "Error: Not a valid Eventzone Profile QR code.",
      "fr": "Erreur : Code QR du profil Eventzone non valide.",
      "ar": "خطأ: رمز استجابة سريعة لملف Eventzone غير صالح."
    },
    "scan_qr_detecting_alignment": {
      "en": "Detecting contact alignment...",
      "fr": "Détection de l'alignement du contact...",
      "ar": "جاري اكتشاف محاذاة جهة الاتصال..."
    },
    "scan_qr_fetching_profile": {
      "en": "Fetching profile from database...",
      "fr": "Récupération du profil depuis la base de données...",
      "ar": "جاري جلب الملف الشخصي من قاعدة البيانات..."
    },
    "scan_qr_error_connect_self": {
      "en": "You cannot connect with yourself!",
      "fr": "Vous ne pouvez pas vous connecter avec vous-même !",
      "ar": "لا يمكنك الاتصال بنفسك!"
    },
    "scan_qr_error_already_connected": {
      "en": "You are already connected with {}!",
      "fr": "Vous êtes déjà connecté avec {} !",
      "ar": "أنت متصل بالفعل مع {}!"
    },
    "scan_qr_eventzone_user": {
      "en": "Eventzone User",
      "fr": "Utilisateur Eventzone",
      "ar": "مستخدم Eventzone"
    },
    "scan_qr_job_at_comp": {
      "en": "{} at {}",
      "fr": "{} chez {}",
      "ar": "{} في {}"
    },
    "scan_qr_professional_at_comp": {
      "en": "Professional at {}",
      "fr": "Professionnel chez {}",
      "ar": "محترف في {}"
    },
    "scan_qr_attendee": {
      "en": "Attendee",
      "fr": "Participant",
      "ar": "حاضر"
    },
    "scan_qr_error_profile_not_found": {
      "en": "Error: Eventzone Profile not found in database.",
      "fr": "Erreur : Profil Eventzone introuvable dans la base de données.",
      "ar": "خطأ: لم يتم العثور على ملف Eventzone في قاعدة البيانات."
    },
    "scan_qr_error_db": {
      "en": "Error communicating with database.",
      "fr": "Erreur de communication avec la base de données.",
      "ar": "خطأ في الاتصال بقاعدة البيانات."
    },
    "scan_qr_extracting_fields": {
      "en": "Extracting contact fields...",
      "fr": "Extraction des champs de contact...",
      "ar": "جاري استخراج حقول جهة الاتصال..."
    },
    "scan_qr_structuring_info": {
      "en": "Structuring connection info...",
      "fr": "Structuration des informations de connexion...",
      "ar": "جاري هيكلة معلومات الاتصال..."
    },
    "scan_qr_verification_success": {
      "en": "Verification successful!",
      "fr": "Vérification réussie !",
      "ar": "تم التحقق بنجاح!"
    },
    "scan_qr_added_contact": {
      "en": "Added {} ({}) to contacts!",
      "fr": "Ajouté {} ({}) aux contacts !",
      "ar": "تمت إضافة {} ({}) إلى جهات الاتصال!"
    },
    "scan_qr_initializing_ocr": {
      "en": "Initializing OCR Scanner...",
      "fr": "Initialisation du scanner OCR...",
      "ar": "جاري تهيئة ماسح OCR..."
    },
    "scan_qr_processing_image": {
      "en": "Processing image...",
      "fr": "Traitement de l'image...",
      "ar": "جاري معالجة الصورة..."
    },
    "scan_qr_finding_text": {
      "en": "Finding text blocks...",
      "fr": "Recherche de blocs de texte...",
      "ar": "جاري البحث عن كتل نصية..."
    },
    "scan_qr_identifying_names": {
      "en": "Identifying names & titles...",
      "fr": "Identification des noms et titres...",
      "ar": "جاري تحديد الأسماء والألقاب..."
    },
    "scan_qr_parsing_emails": {
      "en": "Parsing emails & numbers...",
      "fr": "Analyse des emails et numéros...",
      "ar": "جاري تحليل رسائل البريد الإلكتروني والأرقام..."
    },
    "scan_qr_extracting_metadata": {
      "en": "Extracting contact metadata...",
      "fr": "Extraction des métadonnées du contact...",
      "ar": "جاري استخراج البيانات الوصفية لجهة الاتصال..."
    },
    "scan_qr_scan_successful": {
      "en": "Scan successful!",
      "fr": "Scan réussi !",
      "ar": "تم المسح بنجاح!"
    },
    "scan_qr_processing": {
      "en": "Processing...",
      "fr": "Traitement...",
      "ar": "جاري المعالجة..."
    },
    "scan_qr_title": {
      "en": "Scan QR to Connect",
      "fr": "Scanner le QR pour se connecter",
      "ar": "امسح رمز الاستجابة السريعة للاتصال"
    },
    "scan_qr_instruction": {
      "en": "Position QR code within the frame",
      "fr": "Placez le code QR dans le cadre",
      "ar": "ضع رمز الاستجابة السريعة داخل الإطار"
    },
    "scan_qr_align_card": {
      "en": "Align business card within the frame",
      "fr": "Alignez la carte de visite dans le cadre",
      "ar": "قم بمحاذاة بطاقة العمل داخل الإطار"
    },
    "scan_qr_tab_qr": {
      "en": "QR Code",
      "fr": "Code QR",
      "ar": "رمز QR"
    },
    "scan_qr_tab_card": {
      "en": "Business Card",
      "fr": "Carte de visite",
      "ar": "بطاقة عمل"
    },
    "scan_qr_tab_badge": {
      "en": "Event Badge",
      "fr": "Badge d'événement",
      "ar": "شارة حدث"
    },
    "scan_qr_hold_steady": {
      "en": "Hold steady...",
      "fr": "Maintenez la position...",
      "ar": "ثبت جهازك..."
    },
    "scan_qr_tap_capture": {
      "en": "Tap to capture",
      "fr": "Appuyez pour capturer",
      "ar": "انقر للالتقاط"
    },
    "review_contact_title": {
      "en": "Review Contact",
      "fr": "Vérifier le contact",
      "ar": "مراجعة جهة الاتصال"
    },
    "review_contact_name": {
      "en": "Name",
      "fr": "Nom",
      "ar": "الاسم"
    },
    "review_contact_job_title": {
      "en": "Job Title",
      "fr": "Titre du poste",
      "ar": "المسمى الوظيفي"
    },
    "review_contact_company": {
      "en": "Company",
      "fr": "Entreprise",
      "ar": "الشركة"
    },
    "review_contact_email": {
      "en": "Email",
      "fr": "Email",
      "ar": "البريد الإلكتروني"
    },
    "review_contact_phone": {
      "en": "Phone",
      "fr": "Téléphone",
      "ar": "رقم الهاتف"
    },
    "review_contact_website": {
      "en": "Website",
      "fr": "Site Web",
      "ar": "الموقع الإلكتروني"
    },
    "review_contact_address": {
      "en": "Address",
      "fr": "Adresse",
      "ar": "العنوان"
    },
    "review_contact_save": {
      "en": "Save Contact",
      "fr": "Enregistrer le contact",
      "ar": "حفظ جهة الاتصال"
    },
    "review_contact_cancel": {
      "en": "Cancel",
      "fr": "Annuler",
      "ar": "إلغاء"
    },
    "review_contact_edit": {
      "en": "Edit Contact",
      "fr": "Modifier le contact",
      "ar": "تعديل جهة الاتصال"
    },
    "review_contact_no_image": {
      "en": "No image scanned",
      "fr": "Aucune image scannée",
      "ar": "لم يتم مسح أي صورة"
    },
    "review_contact_scan_result": {
      "en": "Scan Result",
      "fr": "Résultat du scan",
      "ar": "نتيجة المسح"
    }
  };

  final langs = ['en', 'fr', 'ar'];
  for (final lang in langs) {
    final file = File('assets/translations/$lang.json');
    if (file.existsSync()) {
      final content = file.readAsStringSync();
      final map = json.decode(content) as Map<String, dynamic>;
      
      for (final entry in keys.entries) {
        if (!map.containsKey(entry.key)) {
          map[entry.key] = entry.value[lang];
        }
      }
      
      file.writeAsStringSync(json.encode(map));
      print('Updated $lang.json');
    }
  }
}
