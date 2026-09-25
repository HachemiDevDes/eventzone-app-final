import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../models/meeting_model.dart';
import '../services/supabase_service.dart';
import '../providers/meeting_providers.dart';
import 'chat_detail_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class MyMeetingsScreen extends ConsumerStatefulWidget {
  final bool embedMode;
  const MyMeetingsScreen({super.key, this.embedMode = false});

  @override
  ConsumerState<MyMeetingsScreen> createState() => _MyMeetingsScreenState();
}

class _MyMeetingsScreenState extends ConsumerState<MyMeetingsScreen> with SingleTickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  String get _userId => Supabase.instance.client.auth.currentUser?.id ?? "";
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isMeetingUpcoming(MeetingModel meeting) {
    if (meeting.status != 'accepted') return false;
    
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      
      if (meeting.date.compareTo(todayStr) > 0) {
        return true;
      } else if (meeting.date == todayStr) {
        final currentHourMinute = DateFormat('HH:mm').format(now);
        return meeting.startTime.compareTo(currentHourMinute) >= 0;
      }
    } catch (_) {}
    return false;
  }

  bool _isMeetingPast(MeetingModel meeting) {
    if (meeting.status == 'cancelled' || meeting.status == 'declined') return true;
    if (meeting.status == 'pending') return false;
    
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      
      if (meeting.date.compareTo(todayStr) < 0) {
        return true;
      } else if (meeting.date == todayStr) {
        final currentHourMinute = DateFormat('HH:mm').format(now);
        return meeting.endTime.compareTo(currentHourMinute) < 0;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _updateStatus(String meetingId, String status) async {
    final success = await _supabaseService.updateMeetingStatus(meetingId, status);
    if (success && mounted) {
      ref.invalidate(meetingsProvider(_userId));
      ref.invalidate(bookedSlotsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Meeting ${status == 'accepted' ? 'accepted' : status == 'declined' ? 'declined' : 'cancelled'} successfully!"),
          backgroundColor: status == 'accepted' ? EventzoneTheme.accentSuccess : Colors.white24,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showMeetingDetails(MeetingModel meeting) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isOrganizer = meeting.organizerId == _userId;
        
        return GlassContainer(
          borderRadius: 24,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                meeting.title,
                style: TextStyle( color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              
              // Date & Time Row
              Row(
                children: [
                  Icon(LucideIcons.calendar, color: EventzoneTheme.primaryAction, size: 16),
                  SizedBox(width: 8),
                  Text(
                    "${meeting.date}  •  ${meeting.startTime} - ${meeting.endTime}",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              SizedBox(height: 12),
              
              // Location Row
              Row(
                children: [
                  Icon(LucideIcons.mapPin, color: EventzoneTheme.primaryAction, size: 16),
                  SizedBox(width: 8),
                  Text(
                    meeting.location ?? "Virtual / To be agreed",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              // Status Row
              Row(
                children: [
                  Text("Status: ".tr(), style: TextStyle(color: Colors.white38, fontSize: 13)),
                  _buildStatusBadge(meeting.status),
                ],
              ),
              SizedBox(height: 24),

              if (meeting.note != null && meeting.note!.isNotEmpty) ...[
                Text("Note / Message:".tr(), style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    meeting.note!,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                SizedBox(height: 24),
              ],

              // Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Close details sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatDetailScreen(
                              contactName: meeting.otherName ?? "Attendee",
                              avatarUrl: meeting.otherAvatarUrl ?? "",
                              recipientId: isOrganizer ? meeting.attendeeId : meeting.organizerId,
                            ),
                          ),
                        );
                      },
                      icon: Icon(LucideIcons.messageSquare, size: 16, color: Colors.white),
                      label: Text("Message".tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EventzoneTheme.primaryAction,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (meeting.status == 'accepted') ...[
                    SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(meeting.id, 'cancelled');
                        },
                        icon: Icon(LucideIcons.calendarX, size: 16, color: Colors.redAccent),
                        label: Text("Cancel Meeting".tr(), style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.redAccent),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    if (status == 'accepted') {
      color = EventzoneTheme.accentSuccess;
      label = "Accepted";
    } else if (status == 'pending') {
      color = EventzoneTheme.accentWarning;
      label = "Pending";
    } else if (status == 'declined') {
      color = Colors.redAccent;
      label = "Declined";
    } else {
      color = Colors.white30;
      label = "Cancelled";
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMeetingCard(MeetingModel meeting) {
    final isOrganizer = meeting.organizerId == _userId;
    
    Color leftBorderColor;
    if (meeting.status == 'accepted') {
      leftBorderColor = EventzoneTheme.accentSuccess;
    } else if (meeting.status == 'pending') {
      leftBorderColor = EventzoneTheme.accentWarning;
    } else {
      leftBorderColor = Colors.white24;
    }

    return GestureDetector(
      onTap: () => _showMeetingDetails(meeting),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF141927),
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: leftBorderColor, width: 4),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: meeting.otherAvatarUrl != null && meeting.otherAvatarUrl!.isNotEmpty
                        ? NetworkImage(meeting.otherAvatarUrl!)
                        : null,
                    backgroundColor: EventzoneTheme.primaryAction.withOpacity(0.1),
                    child: meeting.otherAvatarUrl == null || meeting.otherAvatarUrl!.isEmpty
                        ? Text(meeting.otherName?[0] ?? 'A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meeting.otherName ?? "Attendee",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                        if (meeting.otherTitle != null || meeting.otherCompany != null) ...[
                          SizedBox(height: 2),
                          Text(
                            meeting.otherCompany != null 
                                ? "${meeting.otherTitle ?? 'Attendee'} @${meeting.otherCompany}"
                                : meeting.otherTitle!,
                            style: TextStyle(color: Colors.white38, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildStatusBadge(meeting.status),
                ],
              ),
              Divider(color: Colors.white10, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.calendar, color: Colors.white54, size: 13),
                      SizedBox(width: 6),
                      Text(
                        meeting.date,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(LucideIcons.clock, color: Colors.white54, size: 13),
                      SizedBox(width: 6),
                      Text(
                        "${meeting.startTime} - ${meeting.endTime}",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          decoration: (meeting.status == 'cancelled' || meeting.status == 'declined')
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(LucideIcons.mapPin, color: Colors.white38, size: 13),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      meeting.location ?? "Virtual / To be agreed",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              // Handle Pending Actions for recipient
              if (meeting.status == 'pending' && !isOrganizer) ...[
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _updateStatus(meeting.id, 'declined'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.redAccent),
                          padding: EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text("Decline".tr(), style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateStatus(meeting.id, 'accepted'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EventzoneTheme.accentSuccess,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text("Accept".tr(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
              
              // Handle Pending status display for organizer
              if (meeting.status == 'pending' && isOrganizer) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(LucideIcons.clock, color: EventzoneTheme.accentWarning, size: 12),
                    SizedBox(width: 6),
                    Text(
                      "Awaiting confirmation".tr(),
                      style: TextStyle(color: EventzoneTheme.accentWarning, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingsList(List<MeetingModel> meetings) {
    if (meetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.calendarX, size: 48, color: Colors.white.withOpacity(0.1)),
            SizedBox(height: 16),
            Text(
              "No meetings scheduled".tr(),
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: 24),
      itemCount: meetings.length,
      separatorBuilder: (context, index) => SizedBox(height: 12),
      itemBuilder: (context, index) => _buildMeetingCard(meetings[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meetingsAsync = ref.watch(meetingsProvider(_userId));

    final Widget tabContent = meetingsAsync.when(
      data: (meetings) {
        final upcoming = meetings.where(_isMeetingUpcoming).toList();
        final pending = meetings.where((m) => m.status == 'pending').toList();
        final past = meetings.where(_isMeetingPast).toList();

        return TabBarView(
          controller: _tabController,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: _buildMeetingsList(upcoming),
            ),
            Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: _buildMeetingsList(pending),
            ),
            Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: _buildMeetingsList(past),
            ),
          ],
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction)),
      error: (e, _) => Center(child: Text("Error: $e", style: TextStyle(color: Colors.redAccent))),
    );

    if (widget.embedMode) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          children: [
            // Inner mini tab selector for meetings
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: EventzoneTheme.primaryAction,
                labelColor: EventzoneTheme.primaryAction,
                unselectedLabelColor: Colors.white24,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, ),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: "Upcoming"),
                  Tab(text: "Pending"),
                  Tab(text: "Past"),
                ],
              ),
            ),
            Expanded(
              child: tabContent,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFF060913),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "My Meetings".tr(),
          style: TextStyle( color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: EventzoneTheme.primaryAction,
          labelColor: EventzoneTheme.primaryAction,
          unselectedLabelColor: Colors.white38,
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "Upcoming"),
            Tab(text: "Pending"),
            Tab(text: "Past / Closed"),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: tabContent,
        ),
      ),
    );
  }
}
