import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/settings_providers.dart';
import '../../../theme/eventzone_theme.dart';
import '../../../widgets/glass_container.dart';

class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final _messageController = TextEditingController();
  String _selectedSubject = 'General Inquiry';
  
  final List<String> _subjects = [
    'General Inquiry',
    'Bug Report',
    'Partnership',
    'Other'
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_messageController.text.trim().isEmpty) return;

    final success = await ref.read(supportMessagesProvider.notifier)
        .submitMessage(_selectedSubject, _messageController.text);

    if (success && mounted) {
      _messageController.clear();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: EventzoneTheme.cardColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.checkCircle2, color: EventzoneTheme.accentSuccess, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Message sent!',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "We'll get back to you within 24 hours.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EventzoneTheme.primaryAction,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message. Please try again.')),
      );
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(supportMessagesProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: EventzoneTheme.backgroundStart,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Contact Us', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Send us a message',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      const Text('Subject', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSubject,
                            isExpanded: true,
                            dropdownColor: EventzoneTheme.cardColor,
                            icon: const Icon(LucideIcons.chevronDown, color: Colors.white54),
                            items: _subjects.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s, style: const TextStyle(color: Colors.white)),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedSubject = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Message', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _messageController,
                          maxLines: 5,
                          minLines: 3,
                          maxLength: 1000,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'How can we help you?',
                            hintStyle: TextStyle(color: Colors.white24),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (_messageController.text.trim().isEmpty || isSubmitting) ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EventzoneTheme.primaryAction,
                            disabledBackgroundColor: Colors.white10,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Send Message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Direct Contact',
                  style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.mail, color: EventzoneTheme.primaryAction),
                  ),
                  title: const Text('Email', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  subtitle: const Text('contact@eventzone.pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  onTap: () => _launchUrl('mailto:contact@eventzone.pro'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.messageCircle, color: EventzoneTheme.accentSuccess),
                  ),
                  title: const Text('WhatsApp', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  subtitle: const Text('+1234567890', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  onTap: () => _launchUrl('https://wa.me/1234567890'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
