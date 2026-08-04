import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/status_pill.dart';
import '../models/event_model.dart';
import '../providers/session_providers.dart';
import 'schedule_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/shake_providers.dart';
import '../widgets/shake_search_overlay.dart';

class EventDashboard extends ConsumerStatefulWidget {
  final EventModel event;
  final Function(int) onNavigate;

  const EventDashboard({super.key, required this.event, required this.onNavigate});

  @override
  ConsumerState<EventDashboard> createState() => _EventDashboardState();
}

class _EventDashboardState extends ConsumerState<EventDashboard> with WidgetsBindingObserver {

  // Direct accelerometer subscription
  StreamSubscription<AccelerometerEvent>? _accelSub;
  final List<DateTime> _shakeTimestamps = [];
  bool _isDebouncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkTooltip();
    _startShakeListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final sessionState = ref.read(shakeSessionProvider).value;
      if (sessionState != null && sessionState.status == ShakeStatus.searching) {
        ref.read(shakeSessionProvider.notifier).forceReset();
      }
    }
  }

  void _startShakeListener() {
    debugPrint('[ShakeToConnect] Starting accelerometer listener...');
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen(
      (AccelerometerEvent event) {
        if (_isDebouncing) return;

        // accelerometerEventStream includes gravity (~9.8 m/s²).
        // Compute total magnitude and subtract gravity to get shake force.
        final double magnitude =
            sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        final double shakeMagnitude = (magnitude - 9.8).abs();

        // Threshold lowered to 5.5 for Samsung OneUI compatibility
        if (shakeMagnitude > 5.5) {
          final now = DateTime.now();
          _shakeTimestamps.add(now);
          _shakeTimestamps.removeWhere(
              (t) => now.difference(t).inMilliseconds > 1000);

          debugPrint(
              '[ShakeToConnect] Shake hit! magnitude=$shakeMagnitude, '
              'count=${_shakeTimestamps.length}/2');

          if (_shakeTimestamps.length >= 2) {
            _shakeTimestamps.clear();
            _isDebouncing = true;
            debugPrint('[ShakeToConnect] ✅ SHAKE DETECTED — triggering session');
            HapticFeedback.heavyImpact();
            _triggerShakeSession();
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) _isDebouncing = false;
            });
          }
        }
      },
      onError: (error) {
        debugPrint('[ShakeToConnect] ❌ Accelerometer error: $error');
      },
    );
    debugPrint('[ShakeToConnect] Accelerometer listener started.');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelSub?.cancel();
    super.dispose();
  }

  Future<void> _checkTooltip() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('shake_tooltip_shown') != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("💡 Shake your phone to connect with someone nearby"),
            duration: const Duration(seconds: 10),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
        await prefs.setBool('shake_tooltip_shown', true);
      }
    }
  }

  void _triggerShakeSession() {
    if (!mounted) return;
    
    final state = ref.read(shakeSessionProvider).value;
    
    if (state != null && (state.status == ShakeStatus.searching || state.status == ShakeStatus.matched)) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Searching for connection...".tr()),
        duration: const Duration(seconds: 2),
      ),
    );
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => const ShakeSearchOverlay(),
    );
    
    ref.read(shakeSessionProvider.notifier).startSession(context);
  }

  @override
  Widget build(BuildContext context) {

    // Watch networking / schedule stats
    final connectionsCount = ref.watch(connectionsCountProvider).value ?? 0;
    final sessionsCount = ref.watch(sessionFavoritesProvider).value?.length ?? 0;
    final nextMeetingAsync = ref.watch(nextMeetingProvider);

    return Scaffold(
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 64),
                _buildEventStatusPill(widget.event.startDate, widget.event.endDate),
                SizedBox(height: 20),
                Text(
                  widget.event.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                      ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(LucideIcons.calendar, color: Colors.white54, size: 14),
                    SizedBox(width: 8),
                    Text(
                      widget.event.date,
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(LucideIcons.mapPin, color: Colors.white54, size: 14),
                    SizedBox(width: 8),
                    Text(
                      widget.event.location,
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                SizedBox(height: 32),

                // Core Hub Grid
                Text("EVENT HUB".tr(), style: Theme.of(context).textTheme.labelLarge),
                SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _buildHubItem(context, LucideIcons.calendar, "Sessions".tr(), 7),
                    _buildHubItem(context, LucideIcons.users, "Attendees".tr(), 2),
                    _buildHubItem(context, LucideIcons.map, "Floor Plan".tr(), 3),
                    _buildHubItem(context, LucideIcons.mic2, "Speakers".tr(), 4),
                    _buildHubItem(context, LucideIcons.store, "Exhibitors".tr(), 5),
                    _buildHubItem(context, LucideIcons.award, "Sponsors".tr(), 6),
                  ],
                ),
                SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyMeetingsScreen()),
                    ).then((_) {
                      ref.invalidate(nextMeetingProvider);
                    });
                  },
                  child: GlassContainer(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendarClock, color: EventzoneTheme.primaryAction, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "My Meetings & Schedule".tr(),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                        ),
                        Icon(LucideIcons.chevronRight, color: Colors.white54, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Shake to Connect Secondary Button
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _triggerShakeSession,
                    icon: const Icon(LucideIcons.vibrate, size: 16, color: EventzoneTheme.primaryAction),
                    label: Text("Shake to Connect".tr(), style: const TextStyle(color: EventzoneTheme.primaryAction)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: EventzoneTheme.primaryAction),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                SizedBox(height: 32),
                
                // Personalized Networking Stats Section
                _buildSectionHeader(context, "My Event Stats".tr()),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        "$connectionsCount",
                        "Connections Made".tr(),
                        LucideIcons.users,
                        onTap: () => widget.onNavigate(2),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        "$sessionsCount",
                        "Agenda Sessions".tr(),
                        LucideIcons.calendarCheck2,
                        onTap: () => widget.onNavigate(1),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                
                // Next Planned Meeting
                Text(
                  "NEXT PLANNED MEETING".tr(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: EventzoneTheme.primaryAction,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                ),
                SizedBox(height: 12),
                nextMeetingAsync.when(
                  loading: () => Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(color: EventzoneTheme.primaryAction),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Text("Error fetching meetings: $err", style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
                  data: (meeting) {
                    if (meeting == null) {
                      return GlassContainer(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.calendarDays, color: Colors.white24, size: 36),
                            SizedBox(height: 12),
                            Text(
                              "No upcoming meetings scheduled".tr(),
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Connect and schedule meetings with other B2B attendees.".tr(),
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: ElevatedButton(
                                onPressed: () => widget.onNavigate(2),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: EventzoneTheme.primaryAction,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(
                                  "Connect with Attendees".tr(),
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
                      padding: EdgeInsets.all(20),
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
                                    ? Icon(LucideIcons.user, size: 16, color: Colors.white)
                                    : null,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      meeting.otherName ?? "Attendee",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Text(
                                      meeting.otherCompany != null && meeting.otherCompany!.isNotEmpty
                                          ? "${meeting.otherTitle ?? ''} @${meeting.otherCompany}"
                                          : meeting.otherTitle ?? '',
                                      style: TextStyle(color: Colors.white38, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              StatusPill(label: "SCHEDULED", isLive: false),
                            ],
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 14.0),
                            child: Divider(color: Colors.white10, height: 1),
                          ),
                          Text(
                            meeting.title,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(LucideIcons.calendarClock, size: 14, color: EventzoneTheme.primaryAction),
                              SizedBox(width: 8),
                              Text(
                                "$dateStr ($timeStr)",
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(LucideIcons.mapPin, size: 14, color: EventzoneTheme.primaryAction),
                              SizedBox(width: 8),
                              Text(
                                meeting.location ?? "TBA",
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHubItem(BuildContext context, IconData icon, String label, int targetIndex) {
    return GestureDetector(
      onTap: () => widget.onNavigate(targetIndex),
      child: GlassContainer(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: EventzoneTheme.primaryAction, size: 24),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
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
        Text("View All".tr(), style: TextStyle(color: EventzoneTheme.primaryAction, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String value, String label, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: EventzoneTheme.primaryAction, size: 20),
            SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.w900)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.white38)),
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
