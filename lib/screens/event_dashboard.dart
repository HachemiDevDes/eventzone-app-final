import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/status_pill.dart';
import '../models/event_model.dart';
import '../models/meeting_model.dart';
import '../providers/session_providers.dart';
import 'schedule_screen.dart';

class EventDashboard extends ConsumerWidget {
  final EventModel event;
  final Function(int) onNavigate;

  const EventDashboard({super.key, required this.event, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch networking / schedule stats
    final connectionsCount = ref.watch(connectionsCountProvider).value ?? 0;
    final sessionsCount = ref.watch(sessionFavoritesProvider).value?.length ?? 0;
    final nextMeetingAsync = ref.watch(nextMeetingProvider);

    return Scaffold(
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 64),
                _buildEventStatusPill(event.startDate, event.endDate),
                const SizedBox(height: 20),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, color: Colors.white54, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      event.date,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(LucideIcons.mapPin, color: Colors.white54, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      event.location,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Core Hub Grid
                Text("EVENT HUB", style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _buildHubItem(context, LucideIcons.calendar, "Sessions", 7),
                    _buildHubItem(context, LucideIcons.users, "Attendees", 2),
                    _buildHubItem(context, LucideIcons.map, "Floor Plan", 3),
                    _buildHubItem(context, LucideIcons.mic2, "Speakers", 4),
                    _buildHubItem(context, LucideIcons.store, "Exhibitors", 5),
                    _buildHubItem(context, LucideIcons.award, "Sponsors", 6),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MyMeetingsScreen()),
                    ).then((_) {
                      ref.invalidate(nextMeetingProvider);
                    });
                  },
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.calendarClock, color: EventzoneTheme.primaryAction, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "My Meetings & Schedule",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                        ),
                        const Icon(LucideIcons.chevronRight, color: Colors.white54, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Personalized Networking Stats Section
                _buildSectionHeader(context, "My Event Stats"),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        "$connectionsCount",
                        "Connections Made",
                        LucideIcons.users,
                        onTap: () => onNavigate(2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        "$sessionsCount",
                        "Agenda Sessions",
                        LucideIcons.calendarCheck2,
                        onTap: () => onNavigate(1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Next Planned Meeting
                Text(
                  "NEXT PLANNED MEETING",
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: EventzoneTheme.primaryAction,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                ),
                const SizedBox(height: 12),
                nextMeetingAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(color: EventzoneTheme.primaryAction),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Text("Error fetching meetings: $err", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
                  data: (meeting) {
                    if (meeting == null) {
                      return GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.calendarDays, color: Colors.white24, size: 36),
                            const SizedBox(height: 12),
                            const Text(
                              "No upcoming meetings scheduled",
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Connect and schedule meetings with other B2B attendees.",
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: ElevatedButton(
                                onPressed: () => onNavigate(2),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: EventzoneTheme.primaryAction,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text(
                                  "Connect with Attendees",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Format Time and Date
                    final timeStr = "${_format12HourTime(meeting.startTime)} - ${_format12HourTime(meeting.endTime)}";
                    final dateStr = _formatMeetingDate(meeting.date);

                    return GlassContainer(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: meeting.otherAvatarUrl != null && meeting.otherAvatarUrl!.isNotEmpty
                                    ? NetworkImage(meeting.otherAvatarUrl!)
                                    : null,
                                child: meeting.otherAvatarUrl == null || meeting.otherAvatarUrl!.isEmpty
                                    ? const Icon(LucideIcons.user, size: 16, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      meeting.otherName ?? "Attendee",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Text(
                                      meeting.otherCompany != null && meeting.otherCompany!.isNotEmpty
                                          ? "${meeting.otherTitle ?? ''} @ ${meeting.otherCompany}"
                                          : meeting.otherTitle ?? '',
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const StatusPill(label: "SCHEDULED", isLive: false),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14.0),
                            child: Divider(color: Colors.white10, height: 1),
                          ),
                          Text(
                            meeting.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(LucideIcons.calendarClock, size: 14, color: EventzoneTheme.primaryAction),
                              const SizedBox(width: 8),
                              Text(
                                "$dateStr ($timeStr)",
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(LucideIcons.mapPin, size: 14, color: EventzoneTheme.primaryAction),
                              const SizedBox(width: 8),
                              Text(
                                meeting.location ?? "TBA",
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHubItem(BuildContext context, IconData icon, String label, int targetIndex) {
    return GestureDetector(
      onTap: () => onNavigate(targetIndex),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: EventzoneTheme.primaryAction, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 150.ms).scaleXY(begin: 0.95, end: 1.0, duration: 150.ms, curve: Curves.easeOutQuad);
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Text("View All", style: TextStyle(color: EventzoneTheme.primaryAction, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String value, String label, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: EventzoneTheme.primaryAction, size: 20),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white38)),
          ],
        ),
      ),
    ).animate().fade(duration: 150.ms).slideY(begin: 0.1, end: 0, duration: 150.ms, curve: Curves.easeOutQuad);
  }

  Widget _buildEventStatusPill(String start, String end) {
    // Simple helper to check if event is live
    return const StatusPill(label: "LIVE NOW", isLive: true);
  }

  String _format12HourTime(String rawTime) {
    // rawTime is e.g. "09:30" or "09:30:00"
    try {
      final parts = rawTime.split(':');
      final hour = int.parse(parts[0]);
      final min = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return "$formattedHour:$min $period";
    } catch (_) {
      return rawTime;
    }
  }

  String _formatMeetingDate(String dateString) {
    // dateString is YYYY-MM-DD
    try {
      final parts = dateString.split('-');
      final year = parts[0];
      final monthInt = int.parse(parts[1]);
      final day = parts[2];
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${months[monthInt - 1]} $day, $year";
    } catch (_) {
      return dateString;
    }
  }
}
