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
import 'edit_profile_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'desktop_crm_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

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
              if (profile == null) return Center(child: Text("Not logged in".tr(), style: TextStyle(color: Colors.white)));
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(profile),
                    SizedBox(height: 32),
                    _buildSection("Preferences".tr(), [
                      _buildNavigationTile(
                        LucideIcons.languages, 
                        "Language".tr(), 
                        trailingText: locale.languageCode == 'ar' ? 'العربية' : locale.languageCode == 'fr' ? 'Français' : 'English',
                        onTap: () => context.push('/settings/language'),
                      ),
                      _buildNavigationTile(
                        LucideIcons.crown, 
                        "Subscription".tr(), 
                        trailingText: subStatusAsync.valueOrNull?.isActive == true 
                            ? (subStatusAsync.valueOrNull!.isTrial ? "{} Days (Trial)".tr(args: [subStatusAsync.valueOrNull!.daysRemaining.toString()]) : "Active".tr())
                            : "Expired".tr(),
                        onTap: () => context.push('/settings/subscription'),
                      ),
                    ]),

                    SizedBox(height: 24),
                    _buildSection("Information".tr(), [
                      _buildNavigationTile(LucideIcons.info, "About us".tr(), onTap: () => context.push('/settings/about')),
                      _buildNavigationTile(LucideIcons.mail, "Contact us".tr(), onTap: () => context.push('/settings/contact')),
                    ]),
                    // Temporarily hiding CRM Integrations for a future update
                    // SizedBox(height: 24),
                    // _buildSection("Integrations".tr(), [
                    //   _buildNavigationTile(
                    //     LucideIcons.plug, 
                    //     "CRM Integrations".tr(), 
                    //     trailingText: "${ref.watch(crmConnectionsProvider).values.where((v) => v).length} connected",
                    //     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CrmIntegrationsScreen())),
                    //   ),
                    // ]),
                    SizedBox(height: 24),
                    _buildSection("Tools", [
                      _buildNavigationTile(
                        LucideIcons.monitor,
                        "Desktop CRM",
                        trailingText: "Login code",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DesktopCrmScreen()),
                        ),
                      ),
                    ]),
                    SizedBox(height: 24),
                    _buildSection("Account".tr(), [
                      _buildNavigationTile(LucideIcons.helpCircle, "Support".tr(), onTap: () => context.push('/settings/support')),
                      _buildNavigationTile(LucideIcons.shield, "Terms and Privacy Policy".tr(), onTap: () => context.push('/settings/terms')),
                      _buildNavigationTile(
                        LucideIcons.trash2, 
                        "Delete Account".tr(), 
                        textColor: Colors.redAccent, 
                        iconColor: Colors.redAccent,
                        onTap: _showDeleteAccountDialog,
                      ),
                      _buildNavigationTile(
                        LucideIcons.logOut, 
                        "Logout".tr(), 
                        textColor: Colors.redAccent, 
                        iconColor: Colors.redAccent,
                        onTap: _showSignOutDialog,
                      ),
                    ]),
                    SizedBox(height: 60),
                  ],
                ),
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction)),
            error: (_, _) => Center(child: Text("Error loading profile".tr(), style: TextStyle(color: Colors.redAccent))),
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
          MaterialPageRoute(builder: (context) => EditProfileScreen()),
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
                color: EventzoneTheme.primaryAction.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: avatarUrl.isEmpty
                  ? CircleAvatar(
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
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? "No Name" : fullName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: EventzoneTheme.primaryAction,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Edit profile".tr(),
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
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: TextStyle(
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
                    Divider(color: Colors.white10, height: 1, indent: 16, endIndent: 16),
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
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
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
              padding: EdgeInsets.only(right: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 100),
                child: Text(
                  trailingText,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            ),
          if (title != "Logout")
            Icon(LucideIcons.chevronRight, color: Colors.white24, size: 18),
        ],
      ),
    );
  }

  Future<void> _showSignOutDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: 24,
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Sign Out".tr(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              "Are you sure you want to sign out? Your session will be ended.".tr(),
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel".tr(), style: TextStyle(color: Colors.white70)),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context); // Close dialog
                      await Supabase.instance.client.auth.signOut();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text("Sign Out".tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: 24,
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Delete Account".tr(),
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              "Are you sure you want to permanently delete your account? This action cannot be undone and all your data will be lost.".tr(),
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel".tr(), style: TextStyle(color: Colors.white70)),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context); // Close dialog
                      try {
                        final user = Supabase.instance.client.auth.currentUser;
                        if (user != null) {
                          await Supabase.instance.client.rpc('delete_user_account');
                          await Supabase.instance.client.auth.signOut();
                        }
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to delete account. Please contact support.'.tr())),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text("Delete".tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
