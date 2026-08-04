import 'dart:convert';
import 'dart:io';

void main() async {
  final newEn = {
    "EVENT HUB": "EVENT HUB",
    "Sessions": "Sessions",
    "Attendees": "Attendees",
    "Floor Plan": "Floor Plan",
    "Speakers": "Speakers",
    "Exhibitors": "Exhibitors",
    "Sponsors": "Sponsors",
    "My Meetings & Schedule": "My Meetings & Schedule",
    "My Event Stats": "My Event Stats",
    "Connections Made": "Connections Made",
    "Agenda Sessions": "Agenda Sessions",
    "NEXT PLANNED MEETING": "NEXT PLANNED MEETING",
  };

  final newFr = {
    "EVENT HUB": "CENTRE DE L'ÉVÉNEMENT",
    "Sessions": "Sessions",
    "Attendees": "Participants",
    "Floor Plan": "Plan au Sol",
    "Speakers": "Intervenants",
    "Exhibitors": "Exposants",
    "Sponsors": "Sponsors",
    "My Meetings & Schedule": "Mes Réunions & Mon Emploi du Temps",
    "My Event Stats": "Mes Statistiques",
    "Connections Made": "Contacts Ajoutés",
    "Agenda Sessions": "Sessions à l'Ordre du Jour",
    "NEXT PLANNED MEETING": "PROCHAINE RÉUNION PRÉVUE",
  };

  final newAr = {
    "EVENT HUB": "مركز الفعالية",
    "Sessions": "الجلسات",
    "Attendees": "الحضور",
    "Floor Plan": "خريطة المكان",
    "Speakers": "المتحدثون",
    "Exhibitors": "العارضون",
    "Sponsors": "الرعاة",
    "My Meetings & Schedule": "اجتماعاتي والجدول الزمني",
    "My Event Stats": "إحصائيات الفعالية",
    "Connections Made": "جهات الاتصال المضافة",
    "Agenda Sessions": "جلسات الجدول الزمني",
    "NEXT PLANNED MEETING": "الاجتماع القادم المخطط له",
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
