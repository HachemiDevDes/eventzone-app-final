import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/status_pill.dart';
import '../providers/session_providers.dart';
import 'schedule_screen.dart';
import 'session_detail_screen.dart';

class EventSessionsScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventSessionsScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventSessionsScreen> createState() => _EventSessionsScreenState();
}

class _EventSessionsScreenState extends ConsumerState<EventSessionsScreen> {
  String? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider(widget.eventId));
    final favoritesAsync = ref.watch(sessionFavoritesProvider);

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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "SCHEDULE".tr(),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: EventzoneTheme.primaryAction,
                                letterSpacing: 2,
                              ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Sessions & Agenda".tr(),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 28,
                              ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(LucideIcons.calendarClock, color: Colors.white, size: 24),
                      tooltip: "My Meetings".tr(),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => MyMeetingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Async State Builder
              Expanded(
                child: sessionsAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(color: EventzoneTheme.primaryAction),
                  ),
                  error: (err, stack) => Center(
                    child: Text(
                      "Error loading sessions: $err",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  data: (sessions) {
                    if (sessions.isEmpty) {
                      return Center(
                        child: Text("No sessions scheduled for this event.".tr(), style: TextStyle(color: Colors.white38)),
                      );
                    }

                    // Extract unique day tags dynamically
                    final days = sessions.map((s) => s.date ?? "Day 1").toSet().toList();
                    days.sort((a, b) => a.compareTo(b));

                    // Default selection
                    _selectedDay ??= days.isNotEmpty ? days.first : 'Day 1';

                    // Filter sessions for selected day
                    final filteredSessions = sessions.where((s) => (s.date ?? "Day 1") == _selectedDay).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Day Selector Tabs
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Row(
                            children: days.map((day) {
                              final isSelected = _selectedDay == day;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDay = day;
                                  });
                                },
                                child: Container(
                                  margin: EdgeInsets.only(right: 12),
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? EventzoneTheme.primaryAction : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: isSelected ? Colors.transparent : Colors.white10),
                                  ),
                                  child: Text(
                                    day,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white60,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // Sessions List
                        Expanded(
                          child: filteredSessions.isEmpty
                              ? Center(
                                  child: Text("No sessions on this day.".tr(), style: TextStyle(color: Colors.white38)),
                                )
                              : ListView.builder(
                                  physics: BouncingScrollPhysics(),
                                  padding: EdgeInsets.symmetric(horizontal: 24),
                                  itemCount: filteredSessions.length,
                                  itemBuilder: (context, index) {
                                    final session = filteredSessions[index];
                                    final favList = favoritesAsync.value ?? [];
                                    final isFav = favList.contains(session.id);

                                    final startTimeStr = _formatTime(session.startTime);
                                    final isLive = _isSessionLive(session.startTime, session.endTime);

                                    return Padding(
                                      padding: EdgeInsets.only(bottom: 16),
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => SessionDetailScreen(session: session),
                                            ),
                                          ).then((_) {
                                            // Refresh favorites count / list in parent on pop
                                            ref.invalidate(sessionFavoritesProvider);
                                          });
                                        },
                                        child: GlassContainer(
                                          padding: EdgeInsets.all(20),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Time slot column
                                              SizedBox(
                                                width: 80,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      startTimeStr,
                                                      style: TextStyle(
                                                        color: isLive ? EventzoneTheme.primaryAction : Colors.white38,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    if (isLive) ...[
                                                      SizedBox(height: 8),
                                                      StatusPill(label: "LIVE", isLive: true),
                                                    ]
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Container(width: 1, height: 64, color: Colors.white10),
                                              SizedBox(width: 16),
                                              
                                              // Content column
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      session.title,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                        color: Colors.white,
                                                        height: 1.25,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        Icon(LucideIcons.mapPin, size: 12, color: Colors.white38),
                                                        SizedBox(width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            session.location ?? "TBA",
                                                            style: TextStyle(fontSize: 12, color: Colors.white38),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 12),
                                                    Row(
                                                      children: [
                                                        // Speakers avatar stack / indicator
                                                        if (session.speakers.isNotEmpty) ...[
                                                          CircleAvatar(
                                                            radius: 9,
                                                            backgroundImage: session.speakers.first.avatarUrl.isNotEmpty
                                                                ? NetworkImage(session.speakers.first.avatarUrl)
                                                                : null,
                                                            child: session.speakers.first.avatarUrl.isEmpty
                                                                ? Icon(LucideIcons.user, size: 8, color: Colors.white)
                                                                : null,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              session.speakers.first.name +
                                                                  (session.speakers.length > 1
                                                                      ? " +${session.speakers.length - 1}"
                                                                      : ""),
                                                              style: TextStyle(fontSize: 11, color: Colors.white70),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ] else
                                                          Spacer(),
                                                          
                                                        // Agenda quick-favorite toggle button
                                                        GestureDetector(
                                                          onTap: () {
                                                            ref.read(sessionFavoritesProvider.notifier).toggleFavorite(session.id);
                                                          },
                                                          child: Icon(
                                                            isFav ? LucideIcons.bookmarkCheck : LucideIcons.bookmarkPlus,
                                                            size: 20,
                                                            color: isFav ? EventzoneTheme.accentSuccess : EventzoneTheme.primaryAction,
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
                                ),
                        ),
                      ],
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

  // Format Start Time
  String _formatTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final hour = localTime.hour;
    final min = localTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return "$formattedHour:$min $period";
  }

  // Determine if the session is currently happening
  bool _isSessionLive(DateTime start, DateTime end) {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }
}
