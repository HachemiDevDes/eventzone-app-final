import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/eventzone_theme.dart';
import '../models/event_model.dart';
import '../widgets/qr_action_sheet.dart';
import 'edit_profile_screen.dart';
import 'scan_qr_screen.dart';
import 'my_qr_code_screen.dart';
import '../services/supabase_service.dart';
import '../widgets/glass_container.dart';
import '../providers/auth_providers.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  final List<EventModel> events;
  final Function(EventModel) onEventJoined;
  final Function(EventModel) onAccessEvent;

  const DiscoveryScreen({
    super.key, 
    required this.events,
    required this.onEventJoined,
    required this.onAccessEvent,
  });

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _supabaseService = SupabaseService();
  String _userId = "";
  int _dailyStreak = 0;

  @override
  void initState() {
    super.initState();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null) {
      _userId = currentUserId;
      _loadStreak(currentUserId);
    }
  }

  Future<void> _loadStreak(String userId) async {
    final streak = await _supabaseService.calculateDailyStreak(userId);
    if (mounted) {
      setState(() {
        _dailyStreak = streak;
      });
    }
  }

  ImageProvider _getAvatarProvider(String url) {
    if (url.startsWith("data:image")) {
      try {
        final base64Content = url.split(",")[1];
        return MemoryImage(base64Decode(base64Content));
      } catch (_) {
        // Fallback
      }
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(currentUserProvider);
    final data = profileState.value;
    final isLoading = profileState.isLoading && data == null;

    final String fullName = data?['full_name'] ?? "Attendee";
    final String avatarUrl = data?['avatar_url'] ?? "";
    final String jobTitle = data?['job_title'] ?? "";
    final String companyName = data?['company_name'] ?? "";

    final String userData = "https://profile.eventzone.pro/?id=$_userId";
    final subtitle = companyName.isNotEmpty 
        ? "$jobTitle @ $companyName"
        : jobTitle;

    return Scaffold(
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome back,",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white60,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          Text(
                            fullName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: EventzoneTheme.primaryAction, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white10,
                          backgroundImage: avatarUrl.isNotEmpty ? _getAvatarProvider(avatarUrl) : null,
                          child: avatarUrl.isEmpty
                              ? const Icon(Icons.person, size: 24, color: Colors.white54)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // QR Code Body
              Expanded(
                child: isLoading 
                  ? const Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction))
                  : Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            GlassContainer(
                              padding: const EdgeInsets.all(32),
                              borderRadius: 32,
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 35,
                                    backgroundColor: Colors.white10,
                                    backgroundImage: avatarUrl.isNotEmpty ? _getAvatarProvider(avatarUrl) : null,
                                    child: avatarUrl.isEmpty
                                        ? const Icon(Icons.person, size: 35, color: Colors.white54)
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    fullName,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (subtitle.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        subtitle,
                                        style: const TextStyle(fontSize: 14, color: Colors.white38),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  const SizedBox(height: 32),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: QrImageView(
                                      data: userData,
                                      version: QrVersions.auto,
                                      size: 180.0,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xFF0B0F19),
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: Color(0xFF0B0F19),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Streak Badge
                            Container(
                              margin: const EdgeInsets.only(top: 24),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text("🔥", style: TextStyle(fontSize: 22)),
                                  const SizedBox(width: 8),
                                  Text(
                                    "$_dailyStreak Day Streak",
                                    style: const TextStyle(
                                      color: Colors.orangeAccent, 
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
