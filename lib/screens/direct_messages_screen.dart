import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import 'chat_detail_screen.dart';
import '../utils/avatar_helper.dart';

class DirectMessagesScreen extends StatefulWidget {
  const DirectMessagesScreen({super.key});

  @override
  State<DirectMessagesScreen> createState() => _DirectMessagesScreenState();
}

class _DirectMessagesScreenState extends State<DirectMessagesScreen> {
  String _searchQuery = "";
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _subscribeRealtime();
  }

  Future<void> _loadConversations() async {
    final currentUser = _supabase.auth.currentUser;
    final currentUserId = currentUser?.id;
    if (currentUserId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch all messages involving the current user
      final messagesResponse = await _supabase
          .from('messages')
          .select()
          .or('sender_id.eq.$currentUserId,recipient_id.eq.$currentUserId')
          .order('created_at', ascending: true);

      final List<Map<String, dynamic>> messagesList = List<Map<String, dynamic>>.from(messagesResponse);

      // 2. Identify the unique conversation partner user IDs and build chat map.
      // Messages are ordered ascending, so we iterate all of them:
      // - Always overwrite lastMsg/time/timestamp with the current message (gives us the LATEST message)
      // - Accumulate unread count only for incoming (not-me) unread messages
      final Map<String, Map<String, dynamic>> chatMap = {};
      final List<String> partnerIds = [];

      for (var msg in messagesList) {
        final String senderId = msg['sender_id'] ?? '';
        final String recipientId = msg['recipient_id'] ?? '';
        
        final String partnerId = senderId == currentUserId ? recipientId : senderId;
        if (partnerId.isEmpty || partnerId == currentUserId) continue;

        if (!partnerIds.contains(partnerId)) {
          partnerIds.add(partnerId);
        }

        final bool isMe = senderId == currentUserId;
        // A message is unread only if it was sent TO us and is not yet read
        final bool isUnread = !isMe && (msg['is_read'] == false || msg['is_read'] == null);
        
        if (!chatMap.containsKey(partnerId)) {
          chatMap[partnerId] = {
            "id": partnerId,
            "lastMsg": msg['content'] ?? '',
            "time": _formatMessageTime(msg['created_at']),
            "unread": isUnread ? 1 : 0,
            "timestamp": DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now(),
          };
        } else {
          // Always update to the latest message details
          chatMap[partnerId]!["lastMsg"] = msg['content'] ?? '';
          chatMap[partnerId]!["time"] = _formatMessageTime(msg['created_at']);
          chatMap[partnerId]!["timestamp"] = DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now();
          // Accumulate unread count
          final int currentUnread = chatMap[partnerId]!["unread"] as int;
          chatMap[partnerId]!["unread"] = currentUnread + (isUnread ? 1 : 0);
        }
      }

      // 3. Fetch profile details for all active conversation partners
      if (partnerIds.isNotEmpty) {
        final profilesResponse = await _supabase
            .from('profiles')
            .select()
            .inFilter('id', partnerIds);

        final List<Map<String, dynamic>> profilesList = List<Map<String, dynamic>>.from(profilesResponse);

        for (var profile in profilesList) {
          final String id = profile['id'] ?? '';
          if (chatMap.containsKey(id)) {
            chatMap[id]!["name"] = profile['full_name'] ?? 'Eventzone User';
            chatMap[id]!["title"] = profile['job_title'] ?? 'Attendee';
            chatMap[id]!["avatar"] = profile['avatar_url'] ?? '';
            chatMap[id]!["email"] = profile['email'] ?? '';
          }
        }

        // 3b. Fallback: Lookup details in connections table for scanned/offline contacts
        final List<String> missingProfileIds = partnerIds
            .where((id) => !chatMap[id]!.containsKey("name"))
            .toList();

        if (missingProfileIds.isNotEmpty) {
          try {
            final connectionsResponse = await _supabase
                .from('connections')
                .select()
                .inFilter('id', missingProfileIds);
            
            final List<Map<String, dynamic>> connectionsList = List<Map<String, dynamic>>.from(connectionsResponse);

            for (var conn in connectionsList) {
              final String id = conn['id'] ?? '';
              if (chatMap.containsKey(id)) {
                chatMap[id]!["name"] = conn['name'] ?? 'Scanned Contact';
                chatMap[id]!["title"] = conn['title'] ?? 'Attendee';
                chatMap[id]!["avatar"] = conn['avatar_url'] ?? '';
                chatMap[id]!["email"] = conn['email'] ?? '';
              }
            }
          } catch (e) {
            debugPrint("Error looking up connections for chat: $e");
          }
        }

        // 3c. Safe Default Fallback (handles hash-based UUIDs)
        for (var id in partnerIds) {
          if (!chatMap[id]!.containsKey("name")) {
            chatMap[id]!["name"] = "Attendee";
            chatMap[id]!["title"] = "Scanned Lead";
            chatMap[id]!["avatar"] = "";
            chatMap[id]!["email"] = "";
          }
        }
      }

      // 4. Construct final list and sort by most recent timestamp descending
      final List<Map<String, dynamic>> sortedConversations = chatMap.values
          .toList()
        ..sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

      if (mounted) {
        setState(() {
          _conversations = sortedConversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading conversations: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeRealtime() {
    _channel = _supabase
        .channel('public_messages_hud')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            _loadConversations();
          },
        );
    _channel!.subscribe();
  }

  String _formatMessageTime(String? timestampStr) {
    if (timestampStr == null) return '';
    try {
      final dateTime = DateTime.parse(timestampStr).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays == 0) {
        final hour = dateTime.hour.toString().padLeft(2, '0');
        final minute = dateTime.minute.toString().padLeft(2, '0');
        return "$hour:$minute";
      } else if (difference.inDays == 1) {
        return "Yesterday";
      } else {
        return "${dateTime.day}/${dateTime.month}";
      }
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredChats = _conversations.where((chat) {
      final name = chat['name'].toString().toLowerCase();
      final title = chat['title'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || title.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: EventzoneTheme.backgroundStart,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text("Direct Messages", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: EventzoneTheme.buildPlayfulBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: GlassContainer(
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
                    hintText: "Search conversations...",
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    icon: Icon(LucideIcons.search, color: Colors.white38, size: 20),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction))
                  : filteredChats.isEmpty
                      ? const Center(child: Text("No conversations found.", style: TextStyle(color: Colors.white24)))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: filteredChats.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final chat = filteredChats[index];
                            final String avatar = chat['avatar'] ?? '';
                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatDetailScreen(
                                      contactName: chat['name'],
                                      avatarUrl: avatar,
                                      recipientId: chat['id'],
                                      recipientEmail: chat['email'],
                                    ),
                                  ),
                                ).then((_) => _loadConversations());
                              },
                              child: GlassContainer(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundImage: getAvatarProvider(avatar),
                                      child: getAvatarProvider(avatar) == null
                                          ? const Icon(LucideIcons.user, size: 18, color: Colors.white70)
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                chat['name'],
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                              ),
                                              Text(
                                                chat['time'],
                                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            chat['lastMsg'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white60, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (chat['unread'] > 0) ...[
                                      const SizedBox(width: 12),
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundColor: EventzoneTheme.primaryAction,
                                        child: Text(
                                          chat['unread'].toString(),
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showStartNewChatDialog(context);
        },
        backgroundColor: EventzoneTheme.primaryAction,
        child: const Icon(LucideIcons.messageSquarePlus, color: Colors.white),
      ),
    );
  }

  Future<void> _showStartNewChatDialog(BuildContext context) async {
    final currentUser = _supabase.auth.currentUser;
    final currentUserId = currentUser?.id;
    if (currentUserId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _supabase
              .from('connections')
              .select()
              .eq('user_id', currentUserId)
              .not('connected_user_id', 'is', null),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 250,
                decoration: const BoxDecoration(
                  color: Color(0xFF111827),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction)),
              );
            }

            final List<Map<String, dynamic>> connections = snapshot.data ?? [];
            final existingChatNames = _conversations.map((c) => c['name'].toString().toLowerCase()).toSet();
            final untextedConnections = connections.where((c) {
              final name = (c['name'] ?? '').toString().toLowerCase();
              return name.isNotEmpty && !existingChatNames.contains(name);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: GlassContainer(
                borderRadius: 32,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      "Start Conversation",
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                    ),
                    const SizedBox(height: 16),
                  Expanded(
                    child: untextedConnections.isEmpty
                        ? const Center(
                            child: Text(
                              "You have active conversations with all contacts!",
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: untextedConnections.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final connection = untextedConnections[index];
                              final String name = connection['name'] ?? 'Eventzone User';
                              final String title = connection['title'] ?? 'Attendee';
                              final String avatar = connection['avatar_url'] ?? '';
                              final String email = connection['email'] ?? '';

                              return InkWell(
                                onTap: () {
                                  Navigator.pop(modalContext); // Close bottom sheet
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatDetailScreen(
                                        contactName: name,
                                        avatarUrl: avatar,
                                        recipientEmail: email,
                                        recipientId: connection['target_user_id'] ?? connection['linked_profile_id'],
                                      ),
                                    ),
                                  ).then((_) => _loadConversations());
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.02),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage: getAvatarProvider(avatar),
                                        child: getAvatarProvider(avatar) == null
                                            ? const Icon(LucideIcons.user, size: 14, color: Colors.white)
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                            Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      const Icon(LucideIcons.messageSquare, color: EventzoneTheme.primaryAction, size: 18),
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
          );
          },
        );
      },
    );
  }
}
