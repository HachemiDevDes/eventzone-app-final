import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_providers.dart';
import '../providers/settings_providers.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../services/supabase_service.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _supabaseService = SupabaseService();

  ImageProvider _getAvatarProvider(String url) {
    if (url.startsWith("data:image")) {
      try {
        final base64Content = url.split(",")[1];
        return MemoryImage(base64Decode(base64Content));
      } catch (_) {}
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProvider);
    final locale = ref.watch(languageProvider);
    final subStatusAsync = ref.watch(subscriptionStatusProvider);

    return Scaffold(
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: profileAsync.when(
            data: (profile) {
              if (profile == null) return const Center(child: Text("Not logged in", style: TextStyle(color: Colors.white)));
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(profile),
                    const SizedBox(height: 32),
                    _buildSection("Preferences", [
                      _buildNavigationTile(
                        LucideIcons.languages, 
                        "Language", 
                        trailingText: locale.languageCode == 'ar' ? 'العربية' : locale.languageCode == 'fr' ? 'Français' : 'English',
                        onTap: () => context.push('/settings/language'),
                      ),
                      _buildNavigationTile(
                        LucideIcons.crown, 
                        "Subscription", 
                        trailingText: subStatusAsync.valueOrNull?.isActive == true 
                            ? (subStatusAsync.valueOrNull!.isTrial ? "${subStatusAsync.valueOrNull!.daysRemaining} Days (Trial)" : "Active")
                            : "Expired",
                        onTap: () => context.push('/settings/subscription'),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection("Information", [
                      _buildNavigationTile(LucideIcons.info, "About us", onTap: () => context.push('/settings/about')),
                      _buildNavigationTile(LucideIcons.mail, "Contact us", onTap: () => context.push('/settings/contact')),
                    ]),
                    const SizedBox(height: 24),
                    _buildSection("Account", [
                      _buildNavigationTile(LucideIcons.helpCircle, "Support", onTap: () => context.push('/settings/support')),
                      _buildNavigationTile(LucideIcons.shield, "Terms and Privacy Policy", onTap: () => context.push('/settings/terms')),
                      _buildNavigationTile(
                        LucideIcons.logOut, 
                        "Logout", 
                        textColor: Colors.redAccent, 
                        iconColor: Colors.redAccent,
                        onTap: _showSignOutDialog,
                      ),
                    ]),
                    const SizedBox(height: 60),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction)),
            error: (_, __) => const Center(child: Text("Error loading profile", style: TextStyle(color: Colors.redAccent))),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> profile) {
    final avatarUrl = profile['avatar_url'] ?? "";
    final fullName = profile['full_name'] ?? "";
    final email = Supabase.instance.client.auth.currentUser?.email ?? "";

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
        );
      },
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: EventzoneTheme.primaryAction.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: avatarUrl.isEmpty
                  ? const CircleAvatar(
                      backgroundColor: Colors.white10,
                      child: Icon(Icons.person, size: 35, color: Colors.white54),
                    )
                  : Image(
                      image: _getAvatarProvider(avatarUrl),
                      fit: BoxFit.cover,
                      width: 70,
                      height: 70,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? "No Name" : fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: EventzoneTheme.primaryAction,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Edit profile",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GlassContainer(
          borderRadius: 20,
          padding: EdgeInsets.zero,
          child: Column(
            children: children.map((child) {
              final isLast = children.last == child;
              return Column(
                children: [
                  child,
                  if (!isLast)
                    const Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationTile(IconData icon, String title, {String? trailingText, Color? textColor, Color? iconColor, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap ?? () {},
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? Colors.white70, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                trailingText,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          if (title != "Logout")
            const Icon(LucideIcons.chevronRight, color: Colors.white24, size: 18),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: EventzoneTheme.primaryAction,
        inactiveThumbColor: Colors.white54,
        inactiveTrackColor: Colors.white10,
      ),
    );
  }

  Future<void> _showSignOutDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Sign Out",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Are you sure you want to sign out? Your session will be ended.",
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context); // Close dialog
                      await Supabase.instance.client.auth.signOut();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
