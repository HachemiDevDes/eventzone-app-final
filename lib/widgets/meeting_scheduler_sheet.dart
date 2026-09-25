import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../models/meeting_model.dart';
import '../services/supabase_service.dart';
import '../providers/meeting_providers.dart';
import 'package:easy_localization/easy_localization.dart';

class MeetingSchedulerSheet extends ConsumerStatefulWidget {
  final String otherUserId;
  final String otherName;
  final String otherAvatarUrl;
  final String? eventId;
  final String? eventTitle;
  final String? startDate;
  final String? endDate;
  final String? scheduleTime;
  final List<DateTime>? eventDays;

  const MeetingSchedulerSheet({
    super.key,
    required this.otherUserId,
    required this.otherName,
    required this.otherAvatarUrl,
    this.eventId,
    this.eventTitle,
    this.startDate,
    this.endDate,
    this.scheduleTime,
    this.eventDays,
  });

  @override
  ConsumerState<MeetingSchedulerSheet> createState() => _MeetingSchedulerSheetState();
}

class _MeetingSchedulerSheetState extends ConsumerState<MeetingSchedulerSheet> {
  final _supabaseService = SupabaseService();
  
  // Dates
  late List<DateTime> _dates;
  late DateTime _selectedDate;
  
  // Time Slots
  final List<String> _timeSlots = [];
  String? _selectedStartTime;
  int _selectedDuration = 30; // 15, 30, 60
  
  // Form fields
  late TextEditingController _titleController;
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();
  
  bool _isSubmitting = false;
  String? _conflictError;

  final List<String> _locationPresets = [
    "Networking Lounge",
    "Exhibition Area",
    "Main Conference Hall",
    "Café / Breakout Area",
    "Virtual / Online",
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: "Meeting with ${widget.otherName}");
    
    _initDates();
    _initTimeSlots();
    _loadEventDetailsIfMissing();
  }

  void _initDates() {
    if (widget.eventDays != null && widget.eventDays!.isNotEmpty) {
      _dates = List.from(widget.eventDays!);
    } else {
      _dates = _parseDatesFromStrings(widget.startDate, widget.endDate);
    }
    if (_dates.isEmpty) {
      final now = DateTime.now();
      _dates = List.generate(7, (index) => now.add(Duration(days: index)));
    }
    _selectedDate = _dates.first;
  }

  List<DateTime> _parseDatesFromStrings(String? startStr, String? endStr) {
    if (startStr == null || startStr.isEmpty) return [];
    try {
      DateTime? sDate;
      DateTime? eDate;

      // Try ISO format YYYY-MM-DD
      try {
        sDate = DateTime.parse(startStr.split('T')[0]);
      } catch (_) {
        // Try DateFormat for human readable formats
        try {
          sDate = DateFormat('MMM d, yyyy').parse(startStr);
        } catch (_) {}
      }

      if (endStr != null && endStr.isNotEmpty) {
        try {
          eDate = DateTime.parse(endStr.split('T')[0]);
        } catch (_) {
          try {
            eDate = DateFormat('MMM d, yyyy').parse(endStr);
          } catch (_) {}
        }
      }

      if (sDate != null) {
        if (eDate != null && eDate.isAfter(sDate)) {
          final daysCount = eDate.difference(sDate).inDays + 1;
          final maxDays = daysCount > 14 ? 14 : daysCount;
          return List.generate(maxDays, (i) => sDate!.add(Duration(days: i)));
        } else {
          return [sDate];
        }
      }
    } catch (_) {}
    return [];
  }

  void _loadEventDetailsIfMissing() async {
    if (widget.eventId == null || widget.eventId!.isEmpty) return;
    if (_dates.length > 1 && widget.startDate != null) return;

    try {
      final sessions = await _supabaseService.fetchEventSessions(widget.eventId!);
      if (sessions.isNotEmpty) {
        final sessionDates = <DateTime>{};
        for (var s in sessions) {
          try {
            final dateVal = s.date;
            if (dateVal != null && dateVal.isNotEmpty) {
              final parsed = DateTime.parse(dateVal.split('T')[0]);
              sessionDates.add(DateTime(parsed.year, parsed.month, parsed.day));
            }
          } catch (_) {}
        }

        if (sessionDates.isNotEmpty && mounted) {
          final sorted = sessionDates.toList()..sort();
          setState(() {
            _dates = sorted;
            if (!_dates.any((d) => DateFormat('yyyy-MM-dd').format(d) == DateFormat('yyyy-MM-dd').format(_selectedDate))) {
              _selectedDate = _dates.first;
            }
          });
        }
      }
    } catch (_) {}
  }

  void _initTimeSlots() {
    int startHour = 9;
    int endHour = 18;

    if (widget.scheduleTime != null && widget.scheduleTime!.isNotEmpty) {
      try {
        final regex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false);
        final matches = regex.allMatches(widget.scheduleTime!).toList();
        if (matches.isNotEmpty) {
          final match1 = matches[0];
          int h1 = int.parse(match1.group(1)!);
          final p1 = match1.group(3)?.toUpperCase();
          if (p1 == 'PM' && h1 < 12) h1 += 12;
          if (p1 == 'AM' && h1 == 12) h1 = 0;
          startHour = h1;

          if (matches.length > 1) {
            final match2 = matches[1];
            int h2 = int.parse(match2.group(1)!);
            final p2 = match2.group(3)?.toUpperCase();
            if (p2 == 'PM' && h2 < 12) h2 += 12;
            if (p2 == 'AM' && h2 == 12) h2 = 0;
            endHour = h2;
          }
        }
      } catch (_) {}
    }

    if (endHour <= startHour) endHour = startHour + 8;
    if (endHour > 23) endHour = 23;
    if (startHour < 0) startHour = 0;

    _timeSlots.clear();
    for (int hour = startHour; hour < endHour; hour++) {
      final hourStr = hour.toString().padLeft(2, '0');
      _timeSlots.add("$hourStr:00");
      _timeSlots.add("$hourStr:30");
    }
    _timeSlots.add("${endHour.toString().padLeft(2, '0')}:00");
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _getEndTime(String startTimeStr, int durationMinutes) {
    final parts = startTimeStr.split(':');
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);
    
    minute += durationMinutes;
    while (minute >= 60) {
      minute -= 60;
      hour += 1;
    }
    
    return "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
  }

  Future<void> _submitRequest() async {
    if (_selectedStartTime == null) {
      setState(() => _conflictError = "Please select a time slot");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _conflictError = null;
    });

    final currentUserIdStr = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserIdStr == null) {
      setState(() {
        _conflictError = "You must be logged in to schedule a meeting.";
        _isSubmitting = false;
      });
      return;
    }

    // 0. Connection Prerequisite Check
    final connectionStatus = await _supabaseService.fetchConnectionStatus(widget.otherUserId);
    if (connectionStatus != 'accepted') {
      setState(() {
        _conflictError = "You must be connected with this attendee before scheduling a meeting.";
        _isSubmitting = false;
      });
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final startTimeStr = _selectedStartTime!;
    final endTimeStr = _getEndTime(startTimeStr, _selectedDuration);

    // 1. Conflict Prevention check
    final hasConflict = await _supabaseService.hasMeetingConflict(
      currentUserIdStr,
      widget.otherUserId,
      dateStr,
      startTimeStr,
      endTimeStr,
    );

    if (hasConflict) {
      setState(() {
        _conflictError = "This slot is unavailable — pick another time";
        _isSubmitting = false;
      });
      return;
    }

    // 2. Insert Meeting
    final newMeeting = MeetingModel(
      id: "", // Gen random on Supabase
      eventId: widget.eventId,
      organizerId: currentUserIdStr,
      attendeeId: widget.otherUserId,
      title: _titleController.text.trim().isEmpty 
          ? "Meeting with ${widget.otherName}" 
          : _titleController.text.trim(),
      date: dateStr,
      startTime: startTimeStr,
      endTime: endTimeStr,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      status: "pending",
      createdAt: DateTime.now(),
    );

    final success = await _supabaseService.createMeeting(newMeeting);
    
    if (success) {
      if (mounted) {
        // Invalidate booked slots and meetings to refresh UI
        ref.invalidate(bookedSlotsProvider);
        ref.invalidate(meetingsProvider(currentUserIdStr));
        ref.invalidate(meetingsProvider(widget.otherUserId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Meeting request sent to ${widget.otherName}!"),
            backgroundColor: EventzoneTheme.accentSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      setState(() {
        _conflictError = "Failed to schedule meeting. Please try again.";
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserIdStr = Supabase.instance.client.auth.currentUser?.id ?? "";
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    // Fetch booked slots for BOTH organizer and attendee to prevent conflicts in real-time
    final organizerBookedSlotsAsync = ref.watch(bookedSlotsProvider(BookedSlotsParam(userId: currentUserIdStr, date: dateStr)));
    final attendeeBookedSlotsAsync = ref.watch(bookedSlotsProvider(BookedSlotsParam(userId: widget.otherUserId, date: dateStr)));

    final List<Map<String, String>> combinedBookedSlots = [];
    
    organizerBookedSlotsAsync.whenData((slots) => combinedBookedSlots.addAll(slots));
    attendeeBookedSlotsAsync.whenData((slots) => combinedBookedSlots.addAll(slots));

    return Scaffold(
      backgroundColor: Color(0xFF070A13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Schedule a Meeting".tr(),
          style: TextStyle( color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            GlassContainer(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: widget.otherAvatarUrl.isNotEmpty
                        ? NetworkImage(widget.otherAvatarUrl)
                        : null,
                    backgroundColor: EventzoneTheme.primaryAction.withOpacity(0.2),
                    child: widget.otherAvatarUrl.isEmpty
                        ? Text(widget.otherName[0], style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.otherName,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Accepted Connection".tr(),
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Mini Calendar Header
            Text(
              "Select Date".tr(),
              style: TextStyle( color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            // Horizontal Mini Calendar List
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: BouncingScrollPhysics(),
                itemCount: _dates.length,
                separatorBuilder: (context, index) => SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final date = _dates[index];
                  final isSelected = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(_selectedDate);
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                        _selectedStartTime = null; // Reset start time when date changes
                        _conflictError = null;
                      });
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      width: 55,
                      decoration: BoxDecoration(
                        color: isSelected ? EventzoneTheme.primaryAction : Color(0xFF141927),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? EventzoneTheme.primaryAction : Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('EEE').format(date).toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            DateFormat('d').format(date),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 24),

            // Duration Selector Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Duration".tr(),
                  style: TextStyle( color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF141927),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [15, 30, 60].map((duration) {
                      final isSel = _selectedDuration == duration;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDuration = duration;
                            _selectedStartTime = null; // Recalculate conflicts
                            _conflictError = null;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel ? EventzoneTheme.primaryAction : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "$duration min",
                            style: TextStyle(
                              color: isSel ? Colors.white : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Time Slots Header
            Text(
              "Select Time".tr(),
              style: TextStyle( color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            // Grid of Time Slots
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: _timeSlots.length,
              itemBuilder: (context, index) {
                final time = _timeSlots[index];
                final endTime = _getEndTime(time, _selectedDuration);
                
                // Check if this proposed range conflicts with accepted meetings
                final isBooked = _supabaseService.isSlotOverlapping(time, endTime, combinedBookedSlots);
                final isSelected = time == _selectedStartTime;

                return GestureDetector(
                  onTap: isBooked
                      ? null
                      : () {
                          setState(() {
                            _selectedStartTime = time;
                            _conflictError = null;
                          });
                        },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isBooked
                          ? Color(0xFF2A2F3E)
                          : isSelected
                              ? EventzoneTheme.primaryAction
                              : Color(0xFF141927),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? EventzoneTheme.primaryAction : Colors.white.withOpacity(0.03),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isBooked) ...[
                          Icon(LucideIcons.lock, size: 10, color: Colors.white24),
                          SizedBox(width: 4),
                        ],
                        Text(
                          time,
                          style: TextStyle(
                            color: isBooked
                                ? Colors.white24
                                : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: isBooked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 24),

            // Conflict Warning Banner
            if (_conflictError != null) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 16),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _conflictError!,
                        style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
            ],

            // Title Input
            Text(
              "Meeting Title".tr(),
              style: TextStyle( color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: TextField(
                controller: _titleController,
                style: TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "e.g. Quick Intro, Partnership Discussion".tr(),
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Location Input
            Text(
              "Location".tr(),
              style: TextStyle( color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: TextField(
                controller: _locationController,
                style: TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Booth, hall, or virtual link...".tr(),
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              child: Row(
                children: _locationPresets.map((loc) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(loc, style: TextStyle(color: Colors.white70, fontSize: 11)),
                      backgroundColor: Color(0xFF141927),
                      side: BorderSide(color: Colors.white12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onPressed: () {
                        setState(() {
                          _locationController.text = loc;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 20),

            // Note Input
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Note (Optional)".tr(),
                  style: TextStyle( color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _noteController,
                  builder: (context, value, child) {
                    final count = value.text.length;
                    return Text(
                      "$count/300",
                      style: TextStyle(
                        color: count > 300 ? Colors.redAccent : Colors.white38,
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: TextField(
                controller: _noteController,
                maxLines: 3,
                maxLength: 300,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => SizedBox.shrink(),
                style: TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Add a message to accompany the request...".tr(),
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            SizedBox(height: 32),

            // CTA Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EventzoneTheme.primaryAction,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        "Send Meeting Request".tr(),
                        style: TextStyle(
                          
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
