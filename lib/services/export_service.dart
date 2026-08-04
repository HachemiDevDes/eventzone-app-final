import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';

class ExportService {
  static Future<void> exportContactsToExcel(
    List<Map<String, dynamic>> connections,
    String timeRange,
  ) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = "Contacts";

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
              // Capitalize first letter for the header
              final formattedPlatform = platform[0].toUpperCase() + platform.substring(1);
              uniquePlatforms.add(formattedPlatform);
            }
          }
        }
      }
    }
    
    List<String> socialColumns = uniquePlatforms.toList()..sort();

    // Add headers
    final headers = [
      "Name",
      "Job Title".tr(),
      "Company".tr(),
      "Department",
      "Email".tr(),
      "Phone",
      "Website",
      "Address".tr(),
      "Connection Date",
      "Tags",
      ...socialColumns,
      "Notes",
    ];

    // Define Header Style
    final Style headerStyle = workbook.styles.add('HeaderStyle');
    headerStyle.bold = true;
    headerStyle.fontColor = '#FFFFFF';
    headerStyle.backColor = '#1976D2'; // A clean blue color
    headerStyle.hAlign = HAlignType.center;
    headerStyle.vAlign = VAlignType.center;
    headerStyle.borders.all.lineStyle = LineStyle.thin;
    headerStyle.borders.all.color = '#DDDDDD';
    headerStyle.wrapText = true;

    // Define Data Style
    final Style dataStyle = workbook.styles.add('DataStyle');
    dataStyle.vAlign = VAlignType.center;
    dataStyle.borders.all.lineStyle = LineStyle.thin;
    dataStyle.borders.all.color = '#DDDDDD';
    dataStyle.wrapText = true;

    for (int i = 0; i < headers.length; i++) {
      final Range headerCell = sheet.getRangeByIndex(1, i + 1);
      headerCell.setText(headers[i]);
      headerCell.cellStyle = headerStyle;
    }

    // Set a default row height for the header
    sheet.getRangeByIndex(1, 1).rowHeight = 30;

    // Add data
    for (int r = 0; r < connections.length; r++) {
      final c = connections[r];
      final rowIndex = r + 2;

      sheet.getRangeByIndex(rowIndex, 1).setText(c['name']?.toString() ?? '');
      sheet.getRangeByIndex(rowIndex, 2).setText(c['title']?.toString() ?? '');
      sheet
          .getRangeByIndex(rowIndex, 3)
          .setText(c['company']?.toString() ?? '');
      sheet
          .getRangeByIndex(rowIndex, 4)
          .setText(c['department']?.toString() ?? '');
      sheet.getRangeByIndex(rowIndex, 5).setText(c['email']?.toString() ?? '');
      sheet.getRangeByIndex(rowIndex, 6).setText(c['phone']?.toString() ?? '');
      sheet
          .getRangeByIndex(rowIndex, 7)
          .setText(c['website']?.toString() ?? '');
      sheet
          .getRangeByIndex(rowIndex, 8)
          .setText(c['address']?.toString() ?? '');

      // Format the date nicely
      String dateStr = c['created_at']?.toString() ?? '';
      if (dateStr.isNotEmpty) {
        try {
          final DateTime dt = DateTime.parse(dateStr);
          // Format as YYYY-MM-DD HH:mm
          dateStr =
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {}
      }
      sheet.getRangeByIndex(rowIndex, 9).setText(dateStr);

      final tags = c['tags'];
      if (tags != null && tags is List) {
        sheet.getRangeByIndex(rowIndex, 10).setText(tags.join(', '));
      } else {
        sheet.getRangeByIndex(rowIndex, 10).setText('');
      }

      // Extract socials
      Map<String, String> userSocials = {};
      final targetId = (c['linked_profile_id'] ?? c['target_user_id'])?.toString();
      if (targetId != null && profilesMap.containsKey(targetId)) {
        final profile = profilesMap[targetId];
        final meta = profile['metadata'] as Map<String, dynamic>? ?? {};
        final socialsList = meta['socials'] as List? ?? [];

        for (var s in socialsList) {
          if (s is Map) {
            final platform = s['platform']?.toString() ?? '';
            final value = s['value']?.toString() ?? '';
            if (platform.isNotEmpty && value.isNotEmpty) {
               final formattedPlatform = platform[0].toUpperCase() + platform.substring(1);
               userSocials[formattedPlatform] = value;
            }
          }
        }
      }
      
      int currentColumnIndex = 11;
      for (String platform in socialColumns) {
         sheet.getRangeByIndex(rowIndex, currentColumnIndex).setText(userSocials[platform] ?? '');
         currentColumnIndex++;
      }

      String notesRaw = c['notes']?.toString() ?? '';
      String parsedNotesText = notesRaw;
      if (notesRaw.startsWith('[')) {
        try {
          final List<dynamic> decoded = jsonDecode(notesRaw);
          List<String> formattedNotes = [];
          for (var item in decoded) {
            if (item is Map) {
              final text = item['text']?.toString() ?? '';
              final dateStr = item['date']?.toString() ?? '';
              String formattedDate = '';
              if (dateStr.isNotEmpty) {
                try {
                  final dt = DateTime.parse(dateStr);
                  formattedDate =
                      '[${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}] ';
                } catch (_) {}
              }
              formattedNotes.add('$formattedDate$text');
            }
          }
          if (formattedNotes.isNotEmpty) {
            parsedNotesText = formattedNotes.join('\n\n');
          }
        } catch (_) {
          // Fallback to raw if not valid json
        }
      }
      sheet.getRangeByIndex(rowIndex, currentColumnIndex).setText(parsedNotesText);

      // Apply styles to all cells in the row
      for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(rowIndex, i + 1).cellStyle = dataStyle;
      }
    }

    // Auto fit columns to make content visible without expanding too much
    for (int i = 1; i <= headers.length; i++) {
      sheet.autoFitColumn(i);

      // Prevent columns from getting overly wide (e.g. for long notes)
      final column = sheet.getRangeByIndex(1, i);
      if (column.columnWidth > 40) {
        column.columnWidth = 40;
      }
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final Directory directory = await getTemporaryDirectory();
    final String path = directory.path;
    final String timeSuffix = timeRange.replaceAll(' ', '_').toLowerCase();
    final String fileName = '$path/eventzone_contacts_$timeSuffix.xlsx';
    final File file = File(fileName);
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles([XFile(fileName)], text: 'My Contacts Export');
  }
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
      "Job Title".tr(),
      "Company".tr(),
      "Department",
      "Email".tr(),
      "Phone",
      "Website",
      "Address".tr(),
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
          dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
                  formattedDate = '[${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}] ';
                } catch (_) {}
              }
              formattedNotes.add('$formattedDate$text');
            }
          }
          if (formattedNotes.isNotEmpty) {
            parsedNotesText = formattedNotes.join('\n\n');
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

    String csv = const CsvEncoder().convert(rows);

    final Directory directory = await getTemporaryDirectory();
    final String path = directory.path;
    final String timeSuffix = timeRange.replaceAll(' ', '_').toLowerCase();
    final String fileName = '$path/eventzone_contacts_$timeSuffix.csv';
    final File file = File(fileName);
    await file.writeAsString(csv, flush: true);

    await Share.shareXFiles([XFile(fileName)], text: 'My Contacts Export');
  }
}
