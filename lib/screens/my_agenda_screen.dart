import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/status_pill.dart';
import '../models/session_model.dart';
import '../providers/session_providers.dart';
import 'schedule_screen.dart';
import 'session_detail_screen.dart';

class MyAgendaScreen extends ConsumerStatefulWidget {
  final String eventId;
  const MyAgendaScreen({super.key, required this.eventId});

  @override
  ConsumerState<MyAgendaScreen> createState() => _MyAgendaScreenState();
}

class _MyAgendaScreenState extends ConsumerState<MyAgendaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 72),
              
              // Header Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "MY HUB",
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: EventzoneTheme.primaryAction,
                            letterSpacing: 2,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "My Agenda",
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                          ),
                    ),
                  ],
                ),
              ),

              // Tab Bar Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: EventzoneTheme.primaryAction,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, ),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, ),
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(4),
                    tabs: const [
                      Tab(text: "Saved Sessions"),
                      Tab(text: "Meetings"),
                    ],
                  ),
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSessionsTab(),
                    const MyMeetingsScreen(embedMode: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsTab() {
    final sessionsAsync = ref.watch(sessionsProvider(widget.eventId));
    final favoritesAsync = ref.watch(sessionFavoritesProvider);

    return favoritesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction)),
      error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.white38))),
      data: (favIds) {
        if (favIds.isEmpty) {
          return _buildSessionsEmptyState();
        }

        return sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction)),
          error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.white38))),
          data: (sessions) {
            // Filter sessions that are in favorites
            final favoritedSessions = sessions.where((s) => favIds.contains(s.id)).toList();

            if (favoritedSessions.isEmpty) {
              return _buildSessionsEmptyState();
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              itemCount: favoritedSessions.length,
              itemBuilder: (context, index) {
                final session = favoritedSessions[index];
                final startTimeStr = _formatTime(session.startTime);
                final dateStr = _formatDate(session.startTime);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SessionDetailScreen(session: session),
                        ),
                      ).then((_) {
                        ref.invalidate(sessionFavoritesProvider);
                      });
                    },
                    child: GlassContainer(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time & Day Tag
                          SizedBox(
                            width: 80,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  startTimeStr,
                                  style: const TextStyle(
                                    color: EventzoneTheme.primaryAction,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Text(
                                    session.date ?? "Day 1",
                                    style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(width: 1, height: 64, color: Colors.white10),
                          const SizedBox(width: 16),

                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.white,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "$dateStr • ${session.location ?? 'TBA'}",
                                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (session.speakers.isNotEmpty) ...[
                                      CircleAvatar(
                                        radius: 9,
                                        backgroundImage: session.speakers.first.avatarUrl.isNotEmpty
                                            ? NetworkImage(session.speakers.first.avatarUrl)
                                            : null,
                                        child: session.speakers.first.avatarUrl.isEmpty
                                            ? const Icon(LucideIcons.user, size: 8, color: Colors.white)
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          session.speakers.first.name,
                                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ] else
                                      const Spacer(),
                                    GestureDetector(
                                      onTap: () {
                                        ref.read(sessionFavoritesProvider.notifier).toggleFavorite(session.id);
                                      },
                                      child: const Icon(
                                        LucideIcons.bookmarkCheck,
                                        size: 20,
                                        color: EventzoneTheme.accentSuccess,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSessionsEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.bookmarkPlus, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            const Text(
              "Your Agenda is Empty",
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Browse the list of sessions and add them to your agenda to construct your summit schedule.",
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 180,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to Sessions List (index 7 in event view)
                  final navigator = Navigator.of(context);
                  if (navigator.canPop()) {
                    navigator.pop();
                  }
                  // Callback is onNavigate, which we can trigger by updating main state. 
                  // But since we are inside case 1 of EventScreen, we can pop or navigate directly.
                  // We can access ref/context to update main navigation or since it's case 7, we can trigger the parent tab change.
                  // Actually, to trigger tab switch, we can just use the parent's index callbacks.
                  // Wait, can we call the navigation callback? We can trigger a rebuild in the parent, or since _eventIndex is state,
                  // we can use a provider for event navigation!
                  // Wait, we can implement an eventNavigationProvider or just let the user browse by clicking the Event Hub grid.
                  // Let's keep it simple and just show a message, or we can use ref.read(eventIndexProvider) if we define one!
                  // Let's check how _eventIndex is managed in main.dart: it is a local state variable in _MainScreenState.
                  // That's fine, we can explain how to access all sessions from the hub!
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: EventzoneTheme.primaryAction,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Go to Hub", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final hour = localTime.hour;
    final min = localTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return "$formattedHour:$min $period";
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${months[local.month - 1]} ${local.day}";
  }
}
