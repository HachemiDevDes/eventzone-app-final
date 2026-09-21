import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/eventzone_theme.dart';
import '../models/event_model.dart';
import 'edit_profile_screen.dart';
import '../services/supabase_service.dart';
import '../widgets/glass_container.dart';
import '../providers/auth_providers.dart';
import '../widgets/animated_gradient_avatar.dart';
import '../theme/profile_material_finish.dart';

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

  int _calculateProfileCompletion(Map<String, dynamic>? data) {
    if (data == null) return 0;
    int score = 0;

    final String fullName = data['full_name'] ?? "";
    final String jobTitle = data['job_title'] ?? "";
    final String companyName = data['company_name'] ?? "";
    
    // Personal details
    if (fullName.isNotEmpty && jobTitle.isNotEmpty && companyName.isNotEmpty) {
      score += 33;
    } else if (fullName.isNotEmpty || jobTitle.isNotEmpty || companyName.isNotEmpty) {
      score += 15;
    }

    // About Me
    final String bio = data['bio'] ?? "";
    final String lookingFor = data['what_im_looking_for'] ?? "";
    if (bio.isNotEmpty || lookingFor.isNotEmpty) {
      score += 33;
    }

    // Social Links
    final metadata = data['metadata'] as Map<String, dynamic>?;
    if (metadata != null && metadata['socials'] != null) {
      final socials = metadata['socials'] as List;
      if (socials.length >= 2) {
        score += 34;
      } else if (socials.isNotEmpty) {
        score += 17;
      }
    }

    return score > 100 ? 100 : score;
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(currentUserProvider);
    final data = profileState.valueOrNull;
    final isLoading = profileState.isLoading && data == null;

    final String fullName = data?['full_name'] ?? "Attendee";
    final String avatarUrl = data?['avatar_url'] ?? "";
    final String jobTitle = data?['job_title'] ?? "";
    final String companyName = data?['company_name'] ?? "";
    final finish = ProfileMaterialFinish.fromProfile(data);

    final String userData = "https://profile.eventzone.pro/?id=$_userId";
    final subtitle = companyName.isNotEmpty 
        ? "$jobTitle @$companyName"
        : jobTitle;

    return Scaffold(
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Header
              Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome back,".tr(),
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
                                  fontSize: 24,
                                ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EditProfileScreen()),
                        );
                      },
                      child: Builder(
                        builder: (context) {
                          final completion = _calculateProfileCompletion(data);
                          final indicatorColor = completion == 100 ? EventzoneTheme.accentSuccess : finish.primaryColor;
                          
                          return Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 60,
                                height: 60,
                                child: CircularProgressIndicator(
                                  value: completion / 100.0,
                                  strokeWidth: 3,
                                  backgroundColor: Colors.white10,
                                  valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
                                ),
                              ),
                              AnimatedGradientAvatar(
                                radius: 26,
                                strokeWidth: 2.5,
                                color: indicatorColor,
                                backgroundImage: avatarUrl.isNotEmpty ? _getAvatarProvider(avatarUrl) : null,
                                child: avatarUrl.isEmpty
                                    ? const Icon(Icons.person, size: 26, color: Colors.white54)
                                    : null,
                              ),
                              Positioned(
                                bottom: -6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: indicatorColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: EventzoneTheme.backgroundStart, width: 2),
                                  ),
                                  child: Text(
                                    '$completion%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
              
              // QR Code Body
              Expanded(
                child: isLoading 
                  ? Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction))
                  : Align(
                      alignment: Alignment(0, -0.15),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: finish.glowColor,
                                    blurRadius: 30,
                                    spreadRadius: -10,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: GlassContainer(
                                padding: const EdgeInsets.all(32),
                                borderRadius: 32,
                                borderColor: finish.cardBorderColor,
                                borderWidth: 1.5,
                                child: Column(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: finish.primaryColor.withOpacity(0.5),
                                          width: 2,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 35,
                                        backgroundColor: Colors.white10,
                                        backgroundImage: avatarUrl.isNotEmpty ? _getAvatarProvider(avatarUrl) : null,
                                        child: avatarUrl.isEmpty
                                            ? const Icon(Icons.person, size: 35, color: Colors.white54)
                                            : null,
                                      ),
                                    ),
                                  SizedBox(height: 16),
                                  Text(
                                    fullName,
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (subtitle.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        subtitle,
                                        style: TextStyle(fontSize: 14, color: Colors.white38),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  SizedBox(height: 32),
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: QrImageView(
                                      data: userData,
                                      version: QrVersions.auto,
                                      size: 180.0,
                                      eyeStyle: QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xFF0B0F19),
                                      ),
                                      dataModuleStyle: QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: Color(0xFF0B0F19),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ),
                            // Actions Row
                            Padding(
                              padding: EdgeInsets.only(top: 24),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  // Corporate Streak Badge
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(LucideIcons.flame, size: 16, color: Colors.white70),
                                        SizedBox(width: 8),
                                        Text(
                                          "day_streak".tr(args: [_dailyStreak.toString()]),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Share Card Button
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: userData));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("Profile link copied to clipboard!".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                          backgroundColor: finish.primaryColor,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: finish.primaryColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: finish.primaryColor.withOpacity(0.35)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.share2, size: 16, color: finish.primaryColor),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Share Card".tr(),
                                            style: TextStyle(
                                              color: finish.primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
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
