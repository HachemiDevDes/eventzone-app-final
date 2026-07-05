import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/eventzone_theme.dart';
import '../../../widgets/glass_container.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: EventzoneTheme.backgroundStart,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Terms & Privacy', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTabIndex = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTabIndex == 0 ? EventzoneTheme.primaryAction : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Terms of Service',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTabIndex = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTabIndex == 1 ? EventzoneTheme.primaryAction : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Privacy Policy',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GlassContainer(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _selectedTabIndex == 0 ? _getTermsContent() : _getPrivacyContent(),
                          style: const TextStyle(color: Colors.white70, height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Last updated: June 2025',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TODO: Replace with real legal text
  String _getTermsContent() {
    return '''1. Acceptance of Terms
By accessing or using the Eventzone app, you agree to be bound by these Terms of Service. If you do not agree, please do not use the service.

2. Description of Service
Eventzone is a B2B networking platform designed to help professionals connect at events.

3. User Responsibilities
You are responsible for maintaining the confidentiality of your account and for all activities that occur under your account. You agree not to use the service for any illegal or unauthorized purpose.

4. Subscriptions
An active subscription is required to continuously accept new connections and scan badges. Subscriptions can be purchased within the app and are subject to the pricing listed at the time of purchase.

5. Termination
We reserve the right to suspend or terminate your account at any time for violations of these Terms.

6. Changes to Terms
We may update these terms from time to time. Continued use of the app constitutes acceptance of any changes.''';
  }

  // TODO: Replace with real legal text
  String _getPrivacyContent() {
    return '''1. Information We Collect
We collect information you provide directly to us, such as your name, job title, company, email, and social links when you create a profile.

2. How We Use Information
We use the information we collect to provide, maintain, and improve our services, and to facilitate connections with other users.

3. Sharing of Information
Your public profile information is shared with other users when they scan your QR code. We do not sell your personal information to third parties.

4. Data Security
We implement appropriate security measures to protect your personal information against unauthorized access, alteration, or disclosure.

5. Your Rights
You have the right to access, update, or delete your personal information at any time by contacting our support team.

6. Contact Us
If you have any questions about this Privacy Policy, please contact us at contact@eventzone.pro.''';
  }
}
