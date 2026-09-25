import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../providers/settings_providers.dart';
import '../../../theme/eventzone_theme.dart';
import '../../../widgets/glass_container.dart';

import 'package:easy_localization/easy_localization.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = context.locale;

    final List<Map<String, String>> languages = [
      {'code': 'en', 'name': 'English', 'native': 'English'},
      {'code': 'fr', 'name': 'French', 'native': 'Français'},
      {'code': 'ar', 'name': 'Arabic', 'native': 'العربية'},
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: EventzoneTheme.backgroundStart,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Language'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Language'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                GlassContainer(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: languages.length,
                    separatorBuilder: (context, index) => Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final lang = languages[index];
                      final isSelected = currentLocale.languageCode == lang['code'];
                      
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: () {
                            context.setLocale(Locale(lang['code']!));
                            ref.read(languageProvider.notifier).setLanguage(Locale(lang['code']!)); // Keep this for now if anything else depends on it
                          },
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          title: Text(
                            lang['native']!.tr(),
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          subtitle: Text(
                            lang['name']!.tr(),
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          trailing: isSelected
                              ? Icon(LucideIcons.check, color: EventzoneTheme.primaryAction)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
