import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../services/supabase_service.dart';
import '../providers/connection_providers.dart';
import 'professional_profile_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class NetworkingScreen extends ConsumerStatefulWidget {
  final String? eventId;
  const NetworkingScreen({super.key, this.eventId});

  @override
  ConsumerState<NetworkingScreen> createState() => _NetworkingScreenState();
}

class _NetworkingScreenState extends ConsumerState<NetworkingScreen> {
  final _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    final data = widget.eventId != null
        ? await _supabaseService.fetchProfilesForEvent(widget.eventId!)
        : await _supabaseService.fetchProfiles();
    if (mounted) {
      setState(() {
        _profiles = data;
        _isLoading = false;
      });
    }
  }

  void _navigateToProfile(String userId, Map<String, dynamic> profile) {
    final meta = profile['metadata'] as Map<String, dynamic>? ?? {};
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfessionalProfileScreen(
          name: profile['full_name'] ?? 'Attendee',
          title: profile['job_title'] ?? '',
          avatarUrl: profile['avatar_url'] ?? '',
          company: profile['company_name'] ?? '',
          email: profile['email'] ?? meta['email'] ?? '',
          phone: profile['phone'] ?? meta['phone'] ?? '',
          website: profile['website'] ?? meta['website'] ?? '',
          address: profile['address'] ?? meta['address'] ?? '',
          notes: profile['bio'] ?? '',
          tags: profile['interests'] != null ? List<String>.from(profile['interests']) : [],
          targetUserId: userId,
        ),
      ),
    ).then((_) {
      // Refresh status when coming back
      ref.invalidate(connectionStatusProvider(userId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredProfiles = _profiles.where((p) {
      final name = (p['full_name'] ?? '').toString().toLowerCase();
      final company = (p['company_name'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || company.contains(query);
    }).toList();

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
                    Text("COMMUNITY".tr(), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: EventzoneTheme.primaryAction)),
                    SizedBox(height: 8),
                    Text("Attendee Directory".tr(), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28, fontWeight: FontWeight.w900)),
                    SizedBox(height: 16),
                    GlassContainer(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      borderRadius: 30,
                      child: TextField(
                        style: TextStyle(color: Colors.white),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Search by name or company...".tr(),
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          icon: Icon(LucideIcons.search, color: Colors.white38, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction))
                    : filteredProfiles.isEmpty
                        ? Center(child: Text("No profiles found".tr(), style: TextStyle(color: Colors.white38)))
                        : ListView.separated(
                            physics: BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                            itemCount: filteredProfiles.length,
                            separatorBuilder: (context, index) => SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final profile = filteredProfiles[index];
                              final String userId = profile['id'];
                              final name = profile['full_name'] ?? 'Attendee';
                              final jobTitle = profile['job_title'] ?? '';
                              final companyName = profile['company_name'] ?? '';
                              final title = companyName.isNotEmpty ? "$jobTitle @$companyName" : jobTitle;

                              return GestureDetector(
                                onTap: () => _navigateToProfile(userId, profile),
                                child: GlassContainer(
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      _buildAvatar(name, profile['avatar_url']),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                            Text(title, style: Theme.of(context).textTheme.bodyMedium),
                                          ],
                                        ),
                                      ),
                                      _buildConnectButton(userId, name, profile),
                                    ],
                                  ),
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

  Widget _buildAvatar(String name, String? avatarUrl) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            EventzoneTheme.primaryAction.withOpacity(0.5),
            EventzoneTheme.accentSuccess.withOpacity(0.3),
          ],
        ),
        image: avatarUrl != null && avatarUrl.isNotEmpty
            ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
            : null,
      ),
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Center(
              child: Text(
                name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join(),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildConnectButton(String userId, String name, Map<String, dynamic> profile) {
    return Consumer(
      builder: (context, ref, child) {
        final statusAsync = ref.watch(connectionStatusProvider(userId));
        final status = statusAsync.value ?? 'none';
        
        if (status == 'accepted') {
          return const Icon(
            LucideIcons.checkCircle2,
            color: EventzoneTheme.accentSuccess,
            size: 22,
          );
        } else if (status == 'pending_sent') {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.clock, size: 12, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  "Pending".tr(),
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        } else if (status == 'pending_received') {
          return ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final success = await _supabaseService.sendConnectionRequest(userId);
              if (success) {
                ref.invalidate(connectionStatusProvider(userId));
                ref.invalidate(incomingRequestsCountProvider);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text("Connected with $name! Added to contacts."),
                    backgroundColor: EventzoneTheme.accentSuccess,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EventzoneTheme.accentSuccess,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: Size.zero,
            ),
            child: Text(
              "Accept".tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          );
        } else {
          return ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final success = await _supabaseService.sendConnectionRequest(
                userId,
                eventId: widget.eventId,
              );
              if (success) {
                ref.invalidate(connectionStatusProvider(userId));
                messenger.showSnackBar(
                  SnackBar(
                    content: Text("Connection request sent to $name!"),
                    backgroundColor: EventzoneTheme.primaryAction,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EventzoneTheme.primaryAction,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: Size.zero,
            ),
            child: Text(
              "Connect".tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          );
        }
      },
    );
  }
}
