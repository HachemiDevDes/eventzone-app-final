import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'auth_providers.dart';

class NoConnectionsException implements Exception {
  NoConnectionsException();
}

class ExportContactsNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Return void to represent idle state
  }

  Future<void> export({List<Map<String, dynamic>>? customConnections}) async {
    state = AsyncValue.loading();
    try {
      // Writing to getTemporaryDirectory() is app-private and requires no
      // storage permission on any Android or iOS version.
      List<Map<String, dynamic>> profilesToExport = [];

      if (customConnections != null) {
        profilesToExport = customConnections;
      } else {
        // 2. Fetch accepted connections from Supabase
        final supabase = ref.read(supabaseProvider);
        final currentUserId = supabase.auth.currentUser?.id;
        if (currentUserId == null) {
          throw Exception("User not authenticated");
        }

        final response = await supabase
            .from('connections')
            .select()
            .eq('user_id', currentUserId)
            .order('created_at', ascending: false);

        final data = response as List<dynamic>;
        for (var conn in data) {
          final Map<String, dynamic> profileMap = Map<String, dynamic>.from(conn);
          profileMap['connected_on'] = conn['created_at'];
          profilesToExport.add(profileMap);
        }
      }

      // Check if there are indeed connections to export
      if (profilesToExport.isEmpty) {
        throw NoConnectionsException();
      }

      // 3. Build CSV in-memory
      final List<List<dynamic>> csvRows = [
        [
          'Full Name'.tr(),
          'Job Title'.tr(),
          'Company'.tr(),
          'Email'.tr(),
          'Phone',
          'LinkedIn'.tr(),
          'WhatsApp'.tr(),
          'GitHub'.tr(),
          'Website',
          'Industries',
          'Interests',
          'What They\'re Looking For',
          'Connected On'
        ]
      ];

      for (var profile in profilesToExport) {
        final fullName = profile['full_name'] ?? profile['name'] ?? '';
        final jobTitle = profile['job_title'] ?? profile['title'] ?? '';
        final company = profile['company_name'] ?? profile['company'] ?? '';
        
        final meta = profile['metadata'] as Map<String, dynamic>? ?? {};
        final email = profile['email'] ?? meta['email'] ?? '';
        final phone = profile['phone'] ?? meta['phone'] ?? '';
        
        // Extract socials from metadata list
        final socialsList = meta['socials'] as List? ?? [];
        final Map<String, dynamic> socialLinks = {};
        for (var s in socialsList) {
          if (s is Map) {
            final platform = (s['platform'] as String?)?.toLowerCase();
            if (platform != null) socialLinks[platform] = s['value'];
          }
        }

        final linkedin = socialLinks['linkedin'] ?? '';
        final whatsapp = socialLinks['whatsapp'] ?? '';
        final github = socialLinks['github'] ?? '';
        final website = socialLinks['website'] ?? meta['website'] ?? '';
        
        String industriesStr = '';
        final industriesData = profile['industries'] ?? profile['industry'];
        if (industriesData is List) {
          industriesStr = industriesData.join(', ');
        } else if (industriesData is String) {
          industriesStr = industriesData;
        }
        
        String interestsStr = '';
        final interestsData = profile['interests'];
        if (interestsData is List) {
          interestsStr = interestsData.join(', ');
        }
        
        final whatTheyAreLookingFor = profile['what_im_looking_for'] ?? '';
        
        String connectedOnStr = '';
        final connectedOnRaw = profile['connected_on'];
        if (connectedOnRaw != null) {
          try {
            final dateTime = DateTime.parse(connectedOnRaw.toString());
            connectedOnStr = dateTime.toIso8601String().substring(0, 10);
          } catch (_) {
            connectedOnStr = connectedOnRaw.toString().substring(0, 10);
          }
        }
        
        csvRows.add([
          fullName,
          jobTitle,
          company,
          email,
          phone,
          linkedin,
          whatsapp,
          github,
          website,
          industriesStr,
          interestsStr,
          whatTheyAreLookingFor,
          connectedOnStr,
        ]);
      }

      final csvString = const CsvEncoder().convert(csvRows);

      // 4. Save to temporary directory
      final directory = await getTemporaryDirectory();
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final fileName = "eventzone_contacts_$dateStr.csv";
      final file = File("${directory.path}/$fileName");
      await file.writeAsString(csvString);

      // 5. Trigger share sheet
      await Share.shareXFiles([XFile(file.path)], subject: 'Exported Contacts');

      state = AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final exportContactsProvider = AutoDisposeAsyncNotifierProvider<ExportContactsNotifier, void>(() {
  return ExportContactsNotifier();
});
