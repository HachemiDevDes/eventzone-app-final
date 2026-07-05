import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../models/meeting_model.dart';
import '../services/supabase_service.dart';
import '../providers/meeting_providers.dart';

class MeetingSchedulerSheet extends ConsumerStatefulWidget {
  final String otherUserId;
  final String otherName;
  final String otherAvatarUrl;

  const MeetingSchedulerSheet({
    super.key,
    required this.otherUserId,
    required this.otherName,
    required this.otherAvatarUrl,
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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: "Meeting with ${widget.otherName}");
    
    // Generate 14 days starting from today
    final now = DateTime.now();
    _dates = List.generate(14, (index) => now.add(Duration(days: index)));
    _selectedDate = _dates.first;
    
    // Generate 30-minute time slots from 08:00 to 20:00
    for (int hour = 8; hour <= 20; hour++) {
      final hourStr = hour.toString().padLeft(2, '0');
      _timeSlots.add("$hourStr:00");
      if (hour < 20) {
        _timeSlots.add("$hourStr:30");
      }
    }
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
        // Invalidate booked slots to refresh UI
        ref.invalidate(bookedSlotsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Meeting request sent to ${widget.otherName}!"),
            backgroundColor: EventzoneTheme.accentSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
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
      backgroundColor: const Color(0xFF070A13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Schedule a Meeting",
          style: TextStyle( color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: widget.otherAvatarUrl.isNotEmpty
                        ? NetworkImage(widget.otherAvatarUrl)
                        : null,
                    backgroundColor: EventzoneTheme.primaryAction.withOpacity(0.2),
                    child: widget.otherAvatarUrl.isEmpty
                        ? Text(widget.otherName[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.otherName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Accepted Connection",
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mini Calendar Header
            const Text(
              "Select Date",
              style: TextStyle( color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Horizontal Mini Calendar List
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _dates.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
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
                      duration: const Duration(milliseconds: 200),
                      width: 55,
                      decoration: BoxDecoration(
                        color: isSelected ? EventzoneTheme.primaryAction : const Color(0xFF141927),
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
                          const SizedBox(height: 6),
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
            const SizedBox(height: 24),

            // Duration Selector Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Duration",
                  style: TextStyle( color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141927),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            const SizedBox(height: 24),

            // Time Slots Header
            const Text(
              "Select Time",
              style: TextStyle( color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Grid of Time Slots
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isBooked
                          ? const Color(0xFF2A2F3E)
                          : isSelected
                              ? EventzoneTheme.primaryAction
                              : const Color(0xFF141927),
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
                          const Icon(LucideIcons.lock, size: 10, color: Colors.white24),
                          const SizedBox(width: 4),
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
            const SizedBox(height: 24),

            // Conflict Warning Banner
            if (_conflictError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _conflictError!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Title Input
            const Text(
              "Meeting Title",
              style: TextStyle( color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: "e.g. Quick Intro, Partnership Discussion",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Location Input
            const Text(
              "Location",
              style: TextStyle( color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: TextField(
                controller: _locationController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: "Booth, hall, or virtual link...",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Note Input
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Note (Optional)",
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
            const SizedBox(height: 8),
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
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: "Add a message to accompany the request...",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 32),

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
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        "Send Meeting Request",
                        style: TextStyle(
                          
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
