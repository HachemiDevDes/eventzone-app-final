import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import '../theme/eventzone_theme.dart';
import '../utils/avatar_helper.dart';
import '../widgets/glass_container.dart';
import 'direct_messages_screen.dart';
import 'professional_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyNetworkScreen extends StatefulWidget {
  const MyNetworkScreen({super.key});



  @override
  State<MyNetworkScreen> createState() => _MyNetworkScreenState();
}

class _MyNetworkScreenState extends State<MyNetworkScreen> {
  String _searchQuery = "";
  List<Map<String, dynamic>> _supabaseConnections = [];
  bool _isLoading = true;
  RealtimeChannel? _connectionsChannel;
  int _unreadCount = 0;
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _loadConnections();
    _subscribeToConnections();
    _subscribeToMessages();
  }

  void _subscribeToMessages() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;
    
    // Initial fetch
    _fetchUnreadCount(currentUserId);
    
    // Subscribe to new messages
    _messagesChannel = Supabase.instance.client
        .channel('public:messages:unread')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) {
             _fetchUnreadCount(currentUserId);
          },
        )
        .subscribe();
  }
  
  void _fetchUnreadCount(String currentUserId) async {
    try {
      final data = await Supabase.instance.client
          .from('messages')
          .select('id')
          .eq('recipient_id', currentUserId)
          .eq('is_read', false);
      if (mounted) {
        setState(() {
          _unreadCount = data.length;
        });
      }
    } catch (e) {
      debugPrint("Error fetching unread count: $e");
    }
  }

  @override
  void dispose() {
    _connectionsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToConnections() {
    _connectionsChannel = Supabase.instance.client
        .channel('network_connections_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'connections',
          callback: (_) {
            if (mounted) _loadConnections();
          },
        )
        .subscribe();
  }

  Future<void> _loadConnections() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final currentUserId = currentUser?.id ?? "0d3e48f0-b7c5-47db-a5c4-f3a08fc3d040";

      // Fetch from Supabase connections table
      final response = await Supabase.instance.client
          .from('connections')
          .select()
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> loaded = List<Map<String, dynamic>>.from(response);



      if (mounted) {
        setState(() {
          _supabaseConnections = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _supabaseConnections = [];
          _isLoading = false;
          _searchQuery = "ERROR: $e";
        });
      }
    }
  }

  void _confirmDeleteConnection(Map<String, dynamic> connection) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B0F19),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white10),
          ),
          title: const Text("Delete Contact", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            "Are you sure you want to delete ${connection['name']} from your contacts?",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                
                try {
                  // Delete from Supabase
                  if (connection['id'] != null) {
                    await Supabase.instance.client
                        .from('connections')
                        .delete()
                        .eq('id', connection['id']);
                  }
                  
                  // (Removed static customConnections)
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Deleted ${connection['name']}!"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                } catch (e) {
                  print("Error deleting connection: $e");
                }
                
                _loadConnections();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                _buildSection(context, "Connected Professionals", _buildContactsGrid()),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Contacts",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                    ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DirectMessagesScreen()),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(LucideIcons.messageCircle, color: Colors.white, size: 28),
                    if (_unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            "$_unreadCount",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text("Manage your profile and connections", style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            borderRadius: 30,
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: const InputDecoration(
                hintText: "Search connections...",
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                icon: Icon(LucideIcons.search, color: Colors.white38, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24),
            ],
          ),
        ),
        content,
      ],
    );
  }



  Widget _buildContactsGrid() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40.0),
        child: Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction)),
      );
    }

    final filteredConnections = _supabaseConnections.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final title = (c['title'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || title.contains(query);
    }).toList();

    if (filteredConnections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
        child: Text("No connections found matching search.", style: TextStyle(color: Colors.white24, fontSize: 13)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredConnections.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final connection = filteredConnections[index];
          final String name = connection['name'] ?? '';
          final String title = connection['title'] ?? '';
          final String avatarUrl = connection['avatar_url'] ?? '';
          final String? source = connection['source'];
          final bool isNew = connection['is_new'] == true;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfessionalProfileScreen(
                    name: name,
                    title: title,
                    avatarUrl: avatarUrl,
                    source: source,
                    isNew: isNew ? 'true' : 'false',
                    email: connection['email'],
                    phone: connection['phone'],
                    website: connection['website'],
                    company: connection['company'],
                    department: connection['department'],
                    notes: connection['notes'],
                    tags: connection['tags'] != null ? List<String>.from(connection['tags']) : null,
                    address: connection['address'],
                    connectionId: connection['id'],
                    createdAt: connection['created_at'],
                    targetUserId: connection['linked_profile_id'] ?? connection['target_user_id'],
                  ),
                ),
              ).then((_) => _loadConnections());
            },
            child: GlassContainer(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white10,
                    backgroundImage: getAvatarProvider(avatarUrl),
                    child: getAvatarProvider(avatarUrl) == null
                        ? const Icon(LucideIcons.user, size: 20, color: Colors.white54)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                            ),
                            if (isNew) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: EventzoneTheme.primaryAction.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: EventzoneTheme.primaryAction.withOpacity(0.4), width: 1),
                                ),
                                child: const Text(
                                  "NEW",
                                  style: TextStyle(
                                    color: EventzoneTheme.primaryAction,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        if (connection['tags'] != null && (connection['tags'] as List).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: (connection['tags'] as List).take(3).map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12, width: 0.5),
                              ),
                              child: Text(
                                tag.toString(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate(delay: (index * 20).ms).fade(duration: 150.ms).slideY(begin: 0.1, end: 0, duration: 150.ms, curve: Curves.easeOutQuad);
        },
      ),
    );
  }
}
