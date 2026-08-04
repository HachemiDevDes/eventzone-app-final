import 'dart:io';

void main() {
  final file = File('lib/services/export_service.dart');
  var content = file.readAsStringSync();

  // 1. Add import for csv
  if (!content.contains("import 'package:csv/csv.dart';")) {
    content = content.replaceFirst("import 'package:share_plus/share_plus.dart';", "import 'package:share_plus/share_plus.dart';\nimport 'package:csv/csv.dart';");
  }

  // 2. Change file naming in exportContactsToExcel
  content = content.replaceAll(
    "final String fileName = '\$path/Contacts_Export_\$timeSuffix.xlsx';",
    "final String fileName = '\$path/eventzone_contacts_\$timeSuffix.xlsx';"
  );

  // 3. Add exportContactsToCsv method
  String csvMethod = """
  static Future<void> exportContactsToCsv(
    List<Map<String, dynamic>> connections,
    String timeRange,
  ) async {
    // Fetch socials from profiles table
    final List<String> profileIds = connections
        .map((c) => (c['linked_profile_id'] ?? c['target_user_id'])?.toString())
        .where((id) => id != null)
        .cast<String>()
        .toList();

    Map<String, dynamic> profilesMap = {};
    if (profileIds.isNotEmpty) {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('id, metadata')
            .inFilter('id', profileIds);

        for (var p in response) {
          profilesMap[p['id'].toString()] = p;
        }
      } catch (e) {
        // Silently fail if we can't fetch profiles
      }
    }

    // Determine all unique social platforms present in the data
    Set<String> uniquePlatforms = {};
    for (var c in connections) {
      final targetId = (c['linked_profile_id'] ?? c['target_user_id'])?.toString();
      if (targetId != null && profilesMap.containsKey(targetId)) {
        final profile = profilesMap[targetId];
        final meta = profile['metadata'] as Map<String, dynamic>? ?? {};
        final socialsList = meta['socials'] as List? ?? [];
        for (var s in socialsList) {
          if (s is Map) {
            final platform = s['platform']?.toString() ?? '';
            if (platform.isNotEmpty) {
              final formattedPlatform = platform[0].toUpperCase() + platform.substring(1);
              uniquePlatforms.add(formattedPlatform);
            }
          }
        }
      }
    }
    
    List<String> socialColumns = uniquePlatforms.toList()..sort();

    final headers = [
      "Name",
      "Job Title",
      "Company",
      "Department",
      "Email",
      "Phone",
      "Website",
      "Address",
      "Connection Date",
      "Tags",
      ...socialColumns,
      "Notes",
    ];

    List<List<dynamic>> rows = [];
    rows.add(headers);

    for (var c in connections) {
      List<dynamic> row = [];
      row.add(c['full_name']?.toString() ?? '');
      row.add(c['job_title']?.toString() ?? '');
      row.add(c['company']?.toString() ?? '');
      row.add(c['department']?.toString() ?? '');
      row.add(c['email']?.toString() ?? '');
      row.add(c['phone']?.toString() ?? '');
      row.add(c['website']?.toString() ?? '');
      row.add(c['address']?.toString() ?? '');

      String dateStr = c['created_at']?.toString() ?? '';
      if (dateStr.isNotEmpty) {
        try {
          final DateTime dt = DateTime.parse(dateStr);
          dateStr = '\${dt.year}-\${dt.month.toString().padLeft(2, '0')}-\${dt.day.toString().padLeft(2, '0')} \${dt.hour.toString().padLeft(2, '0')}:\${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {}
      }
      row.add(dateStr);

      final tags = c['tags'];
      if (tags != null && tags is List) {
        row.add(tags.join(', '));
      } else {
        row.add('');
      }

      Map<String, String> userSocials = {};
      final targetId = (c['linked_profile_id'] ?? c['target_user_id'])?.toString();
      if (targetId != null && profilesMap.containsKey(targetId)) {
        final profile = profilesMap[targetId];
        final meta = profile['metadata'] as Map<String, dynamic>? ?? {};
        final socialsList = meta['socials'] as List? ?? [];
        for (var s in socialsList) {
          if (s is Map) {
            final platform = s['platform']?.toString() ?? '';
            final url = s['url']?.toString() ?? '';
            if (platform.isNotEmpty) {
              final formattedPlatform = platform[0].toUpperCase() + platform.substring(1);
              userSocials[formattedPlatform] = url;
            }
          }
        }
      }

      for (var col in socialColumns) {
        row.add(userSocials[col] ?? '');
      }

      String parsedNotesText = '';
      final notesRaw = c['notes']?.toString() ?? '';
      if (notesRaw.startsWith('[')) {
        try {
          final List<dynamic> decoded = jsonDecode(notesRaw);
          List<String> formattedNotes = [];
          for (var item in decoded) {
            if (item is Map) {
              final text = item['text']?.toString() ?? '';
              final dateRawStr = item['date']?.toString() ?? '';
              String formattedDate = '';
              if (dateRawStr.isNotEmpty) {
                try {
                  final dt = DateTime.parse(dateRawStr);
                  formattedDate = '[\${dt.year}-\${dt.month.toString().padLeft(2, '0')}-\${dt.day.toString().padLeft(2, '0')}] ';
                } catch (_) {}
              }
              formattedNotes.add('\$formattedDate\$text');
            }
          }
          if (formattedNotes.isNotEmpty) {
            parsedNotesText = formattedNotes.join('\\n\\n');
          }
        } catch (_) {
          parsedNotesText = notesRaw;
        }
      } else {
        parsedNotesText = notesRaw;
      }
      row.add(parsedNotesText);

      rows.add(row);
    }

    String csv = const ListToCsvConverter().convert(rows);

    final Directory directory = await getTemporaryDirectory();
    final String path = directory.path;
    final String timeSuffix = timeRange.replaceAll(' ', '_').toLowerCase();
    final String fileName = '\$path/eventzone_contacts_\$timeSuffix.csv';
    final File file = File(fileName);
    await file.writeAsString(csv, flush: true);

    await Share.shareXFiles([XFile(fileName)], text: 'My Contacts Export');
  }
}
""";

  if (!content.contains('exportContactsToCsv')) {
    content = content.replaceFirst(RegExp(r'\}\s*$'), csvMethod);
  }

  file.writeAsStringSync(content);
}
