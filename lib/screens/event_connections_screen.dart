import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../services/supabase_service.dart';
import 'professional_profile_screen.dart';
import 'chat_detail_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class EventConnectionsScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventConnectionsScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventConnectionsScreen> createState() => _EventConnectionsScreenState();
}

class _EventConnectionsScreenState extends ConsumerState<EventConnectionsScreen> {
  final _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _connections = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    setState(() => _isLoading = true);
    final data = await _supabaseService.fetchAcceptedConnectionsForEvent(widget.eventId);
    if (mounted) {
      setState(() {
        _connections = data;
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
      _loadConnections();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredConnections = _connections.where((p) {
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
              
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "NETWORKING".tr(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: EventzoneTheme.primaryAction,
                            letterSpacing: 2,
                          ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "My Connections".tr(),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                          ),
                    ),
                    SizedBox(height: 16),
                    
                    // Search Bar
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
                          hintText: "Search connections...".tr(),
                          hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                          border: InputBorder.none,
                          icon: Icon(LucideIcons.search, color: Colors.white38, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Connections list
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction))
                    : filteredConnections.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            physics: BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                            itemCount: filteredConnections.length,
                            separatorBuilder: (context, index) => SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final profile = filteredConnections[index];
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
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              title,
                                              style: TextStyle(color: Colors.white38, fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Message Action Button
                                      IconButton(
                                        icon: Icon(LucideIcons.messageSquare, color: EventzoneTheme.primaryAction, size: 20),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ChatDetailScreen(
                                                contactName: name,
                                                avatarUrl: profile['avatar_url'] ?? '',
                                                recipientId: userId,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.users, color: Colors.white24, size: 48),
            SizedBox(height: 16),
            Text(
              "No Connections Yet".tr(),
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Start networking! Visit the Attendee Directory from the Event Hub to send connection requests.".tr(),
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
