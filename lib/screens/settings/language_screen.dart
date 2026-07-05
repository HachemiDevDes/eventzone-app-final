import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../providers/settings_providers.dart';
import '../../../theme/eventzone_theme.dart';
import '../../../widgets/glass_container.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(languageProvider);

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
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Language', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Language',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                GlassContainer(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: languages.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final lang = languages[index];
                      final isSelected = currentLocale.languageCode == lang['code'];
                      
                      return ListTile(
                        onTap: () {
                          ref.read(languageProvider.notifier).setLanguage(Locale(lang['code']!));
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        title: Text(
                          lang['native']!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        subtitle: Text(
                          lang['name']!,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        trailing: isSelected
                            ? const Icon(LucideIcons.check, color: EventzoneTheme.primaryAction)
                            : null,
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
