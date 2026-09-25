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
import '../widgets/status_pill.dart';
import '../providers/auth_providers.dart';
import '../widgets/animated_gradient_avatar.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  final List<EventModel> events;
  final Function(EventModel) onEventJoined;
  final Function(EventModel) onAccessEvent;
  final VoidCallback? onBrowseEvents;
  final Future<void> Function()? onRefresh;

  const DiscoveryScreen({
    super.key, 
    required this.events,
    required this.onEventJoined,
    required this.onAccessEvent,
    this.onBrowseEvents,
    this.onRefresh,
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

    final String userData = "https://profile.eventzone.pro/?id=$_userId";
    final subtitle = companyName.isNotEmpty 
        ? "$jobTitle @$companyName"
        : jobTitle;

    final registeredEvents = widget.events
        .where((e) => e.isJoined || e.registrationStatus == 'registered' || e.isPendingApproval)
        .toList();

    return Scaffold(
      backgroundColor: EventzoneTheme.backgroundStart,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              EventzoneTheme.backgroundStart,
              EventzoneTheme.backgroundEnd,
            ],
          ),
        ),
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
                          final indicatorColor = completion == 100 ? EventzoneTheme.accentSuccess : EventzoneTheme.primaryAction;
                          
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
              
              // QR Code & My Tickets Body
              Expanded(
                child: isLoading 
                  ? Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction))
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _loadStreak(_userId);
                        if (widget.onRefresh != null) {
                          await widget.onRefresh!();
                        }
                      },
                      color: EventzoneTheme.primaryAction,
                      backgroundColor: const Color(0xFF141A28),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 16.0, bottom: 48.0),
                        child: Column(
                          children: [
                            // Digital Business Card
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 340),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.45),
                                          blurRadius: 30,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: GlassContainer(
                                      padding: const EdgeInsets.all(32),
                                      borderRadius: 32,
                                      borderColor: EventzoneTheme.glassBorder,
                                      borderWidth: 1.5,
                                      child: Column(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: EventzoneTheme.primaryAction.withValues(alpha: 0.5),
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
                                  ),
                                ),
                              ),
                            ),

                            // Actions Row
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  // Corporate Streak Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(LucideIcons.flame, size: 16, color: Colors.white70),
                                        const SizedBox(width: 8),
                                        Text(
                                          "day_streak".tr(args: [_dailyStreak.toString()]),
                                          style: const TextStyle(
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
                                          backgroundColor: EventzoneTheme.primaryAction,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: EventzoneTheme.primaryAction.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: EventzoneTheme.primaryAction.withValues(alpha: 0.35)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(LucideIcons.share2, size: 16, color: EventzoneTheme.primaryAction),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Share Card".tr(),
                                            style: const TextStyle(
                                              color: EventzoneTheme.primaryAction,
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

                            // Under streaks & share card chips: "My tickets" section
                            const SizedBox(height: 36),
                            _buildMyTicketsSection(context, registeredEvents, fullName),
                          ],
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

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(parsed);
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildThumbnail(String imageUrl, double size) {
    if (imageUrl.startsWith('data:image')) {
      final base64String = imageUrl.split(',').last;
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            base64Decode(base64String),
            height: size,
            width: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        return _buildThumbnailFallback(size);
      }
    } else if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          imageUrl,
          height: size,
          width: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildThumbnailFallback(size),
        ),
      );
    }
    return _buildThumbnailFallback(size);
  }

  Widget _buildThumbnailFallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: const Icon(LucideIcons.calendar, color: Colors.white38, size: 24),
    );
  }

  Widget _buildMyTicketsSection(
    BuildContext context, 
    List<EventModel> registeredEvents, 
    String fullName,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: EventzoneTheme.primaryAction.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.ticket,
                      size: 16,
                      color: EventzoneTheme.primaryAction,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "My tickets".tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (registeredEvents.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        '${registeredEvents.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.onBrowseEvents != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onBrowseEvents,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Browse events".tr(),
                          style: const TextStyle(
                            color: EventzoneTheme.primaryAction,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          LucideIcons.chevronRight,
                          size: 14,
                          color: EventzoneTheme.primaryAction,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (registeredEvents.isEmpty)
            _buildEmptyTicketsCard(context)
          else
            ...registeredEvents.map((event) => Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: _buildTicketCard(context, event, fullName),
            )),
        ],
      ),
    );
  }

  Widget _buildEmptyTicketsCard(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      borderRadius: 20,
      borderColor: Colors.white.withValues(alpha: 0.08),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(
              LucideIcons.ticket,
              size: 24,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "No tickets yet".tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "When you register for conferences or summits, your entrance tickets and portals will appear here.".tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (widget.onBrowseEvents != null) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: widget.onBrowseEvents,
              icon: const Icon(LucideIcons.compass, size: 16),
              label: Text("Explore Events".tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: EventzoneTheme.primaryAction,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTicketCard(BuildContext context, EventModel event, String fullName) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111726),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showTicketPassBottomSheet(context, event, fullName),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Thumbnail + Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThumbnail(event.imageUrl, 76),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                event.category.toUpperCase(),
                                style: const TextStyle(
                                  color: EventzoneTheme.primaryAction,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              StatusPill(
                                label: event.isPendingApproval ? "PENDING" : "REGISTERED",
                                customColor: event.isPendingApproval ? const Color(0xFFD97706) : const Color(0xFF059669),
                                customBorderColor: event.isPendingApproval ? const Color(0xFFFCD34D) : const Color(0xFF6EE7B7),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            event.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(LucideIcons.calendar, color: Colors.white38, size: 12),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _formatDate(event.date),
                                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(LucideIcons.mapPin, color: EventzoneTheme.primaryAction, size: 12),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  event.location,
                                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Subtle Divider
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(top: 14, bottom: 12),
                  color: Colors.white.withValues(alpha: 0.08),
                ),

                // Action Buttons Row
                Row(
                  children: [
                    // View Pass Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showTicketPassBottomSheet(context, event, fullName),
                        icon: const Icon(LucideIcons.qrCode, size: 14),
                        label: Text(
                          "View Pass".tr(),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                          backgroundColor: Colors.white.withValues(alpha: 0.04),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Access Portal Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: event.isPendingApproval
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Your registration is pending organizer approval.".tr()),
                                    backgroundColor: Colors.orangeAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            : () => widget.onAccessEvent(event),
                        icon: Icon(
                          event.isPendingApproval ? LucideIcons.clock : LucideIcons.arrowRight,
                          size: 14,
                        ),
                        label: Text(
                          event.isPendingApproval ? "Pending".tr() : "Access Portal".tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: event.isPendingApproval
                              ? Colors.white10
                              : EventzoneTheme.primaryAction,
                          foregroundColor: event.isPendingApproval ? Colors.white54 : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTicketPassBottomSheet(BuildContext context, EventModel event, String fullName) {
    final ticketCode = "EVZ-${event.id.replaceAll('-', '').padRight(8, '0').substring(0, 8).toUpperCase()}";
    final ticketQrPayload = jsonEncode({
      'type': 'eventzone_ticket',
      'eventId': event.id,
      'userId': _userId,
      'name': fullName,
      'eventTitle': event.title,
      'code': ticketCode,
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(sheetCtx).padding.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0F1420),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white12, width: 1),
              left: BorderSide(color: Colors.white12, width: 1),
              right: BorderSide(color: Colors.white12, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: EventzoneTheme.primaryAction.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.ticket, size: 16, color: EventzoneTheme.primaryAction),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Attendee Pass".tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(sheetCtx),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Digital Ticket Badge Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF182032), Color(0xFF101524)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status and Category
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          event.category.toUpperCase(),
                          style: const TextStyle(
                            color: EventzoneTheme.primaryAction,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        StatusPill(
                          label: event.isPendingApproval ? "PENDING" : "CONFIRMED PASS",
                          customColor: event.isPendingApproval ? const Color(0xFFD97706) : const Color(0xFF059669),
                          customBorderColor: event.isPendingApproval ? const Color(0xFFFCD34D) : const Color(0xFF6EE7B7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Event Title
                    Text(
                      event.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Date & Location
                    Row(
                      children: [
                        const Icon(LucideIcons.calendar, color: Colors.white38, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          _formatDate(event.date),
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(LucideIcons.mapPin, color: EventzoneTheme.primaryAction, size: 13),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            event.location,
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Perforated Dashed Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        children: List.generate(
                          24,
                          (index) => Expanded(
                            child: Container(
                              height: 1.5,
                              color: index.isEven ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Attendee Info Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "ATTENDEE".tr(),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: ticketCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Ticket code copied to clipboard!".tr()),
                                backgroundColor: EventzoneTheme.primaryAction,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ticketCode,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(LucideIcons.copy, size: 11, color: Colors.white54),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Ticket QR Code
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: ticketQrPayload,
                          version: QrVersions.auto,
                          size: 160.0,
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
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        "Scan at check-in counter for admission".tr(),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bottom Action Button
              if (!event.isPendingApproval)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      widget.onAccessEvent(event);
                    },
                    icon: const Icon(LucideIcons.arrowRight, size: 18),
                    label: Text(
                      "Access Attendee Portal".tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EventzoneTheme.primaryAction,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.clock, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "Portal access unlocks upon organizer approval".tr(),
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
