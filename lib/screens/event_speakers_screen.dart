import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';

class EventSpeakersScreen extends StatelessWidget {
  const EventSpeakersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 72),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "SPEAKERS".tr(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: EventzoneTheme.primaryAction,
                            letterSpacing: 2,
                          ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Industry Leaders".tr(),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: 8,
                  separatorBuilder: (context, index) => SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final names = ["Dr. Elena Wright", "James Wilson", "Marcus Chen", "Sarah Rodriguez"];
                    final titles = ["CTO @TechFlow", "Head of AI @Google", "Founder @Innovate", "Design Director"];
                    final name = names[index % names.length];
                    final title = titles[index % titles.length];

                    return GlassContainer(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: EventzoneTheme.primaryAction.withOpacity(0.3), width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 32,
                              backgroundImage: NetworkImage("https://i.pravatar.cc/150?u=speaker$index"),
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  title,
                                  style: TextStyle(color: Colors.white60, fontSize: 13),
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildSocialIcon(LucideIcons.user),
                                    SizedBox(width: 12),
                                    _buildSocialIcon(LucideIcons.mail),
                                  ],
                                )
                              ],
                            ),
                          ),
                          Icon(LucideIcons.chevronRight, color: Colors.white24),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 14, color: Colors.white38),
    );
  }
}
