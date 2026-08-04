import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/eventzone_theme.dart';
import '../../../widgets/glass_container.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': 'How do I connect with someone?'.tr(),
        'a': 'Simply tap the "Scan" button on the home screen to scan their QR code, or share your own QR code for them to scan. Once scanned, you can review their profile and accept the connection.'.tr()
      },
      {
        'q': 'How does the subscription work?'.tr(),
        'a': 'A subscription allows you to continuously accept new connections and scan badges. You get a 15-day free trial, after which you can purchase a plan in the Settings.'.tr()
      },
      {
        'q': 'How do I export my contacts?'.tr(),
        'a': 'Go to the "My Network" tab and tap the export icon at the top right. You can export your connections as a CSV file to your device.'.tr()
      },
      {
        'q': 'Can I delete my account?'.tr(),
        'a': 'Yes. Please contact our support team to request full account deletion and data removal according to our privacy policy.'.tr()
      },
      {
        'q': 'How do I report a user?'.tr(),
        'a': 'If you experience inappropriate behavior, tap the three dots on the user\'s profile and select "Report". Our team will review the report within 24 hours.'.tr()
      },
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
        title: Text('Support'.tr(), style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            children: [
              Text(
                'Frequently Asked Questions'.tr(),
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ...faqs.map((faq) => Padding(
                padding: EdgeInsets.only(bottom: 12.0),
                child: GlassContainer(
                  padding: EdgeInsets.zero,
                  child: ExpansionTile(
                    title: Text(
                      faq['q']!,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    iconColor: EventzoneTheme.primaryAction,
                    collapsedIconColor: Colors.white54,
                    shape: Border(),
                    childrenPadding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    children: [
                      Text(
                        faq['a']!,
                        style: TextStyle(color: Colors.white70, height: 1.5),
                      ),
                    ],
                  ),
                ),
              )),
              
              SizedBox(height: 40),
              Center(
                child: Text(
                  'Still need help?'.tr(),
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/settings/contact'),
                icon: Icon(LucideIcons.headphones, color: Colors.white),
                label: Text('Contact Support'.tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EventzoneTheme.primaryAction,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
