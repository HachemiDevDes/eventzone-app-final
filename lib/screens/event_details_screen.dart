import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/status_pill.dart';
import 'dart:convert';
import '../models/event_model.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventModel event;
  final VoidCallback onRegister;
  final VoidCallback onAccess;

  const EventDetailsScreen({
    super.key,
    required this.event,
    required this.onRegister,
    required this.onAccess,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late bool _isJoined;
  int _selectedDay = 1;

  @override
  void initState() {
    super.initState();
    _isJoined = widget.event.isJoined;
  }

  void _showRegistrationSuccessDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Color(0xFF141927),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(LucideIcons.partyPopper, color: EventzoneTheme.primaryAction, size: 28),
            SizedBox(width: 10),
            Text("Registered! 🎉".tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "You have successfully registered for ${widget.event.title}! Get ready to explore the event hub.",
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pop(context); // Close details screen
              widget.onAccess(); // Navigate to event hub
            },
            child: Text("Go to Hub".tr(), style: TextStyle(color: EventzoneTheme.primaryAction, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: EventzoneTheme.primaryAction.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: EventzoneTheme.primaryAction, size: 20),
        ),
        SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeakersList() {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (context, index) => SizedBox(width: 16),
        itemBuilder: (context, index) {
          return Column(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundImage: NetworkImage("https://i.pravatar.cc/150?u=speaker$index"),
              ),
              SizedBox(height: 8),
              Text("Dr. Jane Smith".tr(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text("CEO @Future".tr(), style: TextStyle(fontSize: 10, color: Colors.white38)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAgendaList() {
    // Agenda data grouped by day
    final Map<int, List<Map<String, String>>> agendaData = {
      1: [
        {"time": "09:00 AM", "title": "Opening Keynote", "location": "Main Hall"},
        {"time": "10:30 AM", "title": "Future of AI & Robotics", "location": "Room 402"},
        {"time": "02:00 PM", "title": "Tech Innovation Panel", "location": "Exhibition Stage"},
      ],
      2: [
        {"time": "09:30 AM", "title": "Building on Supabase", "location": "Tech Stage"},
        {"time": "11:00 AM", "title": "Web3 & Decentralization", "location": "Room 101"},
        {"time": "03:30 PM", "title": "Design Systems Workshop", "location": "Lab 3"},
      ],
      3: [
        {"time": "10:00 AM", "title": "AI Ethics & Safety", "location": "Main Hall"},
        {"time": "01:30 PM", "title": "Closing Panel: What's Next?", "location": "Main Hall"},
        {"time": "05:00 PM", "title": "Farewell & Drinks", "location": "Rooftop Lounge"},
      ]
    };

    final currentSessions = agendaData[_selectedDay] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day selector chips
        Row(
          children: [1, 2, 3].map((day) {
            final isSelected = _selectedDay == day;
            return Padding(
              padding: EdgeInsets.only(right: 12, bottom: 20),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDay = day;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? EventzoneTheme.primaryAction : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? EventzoneTheme.primaryAction : Colors.white12,
                    ),
                  ),
                  child: Text(
                    "Day $day",
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        
        // Sessions list for selected day
        ...currentSessions.map((session) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: GlassContainer(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: EventzoneTheme.primaryAction.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      session['time']!,
                      style: TextStyle(
                        color: EventzoneTheme.primaryAction,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session['title']!,
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(LucideIcons.mapPin, color: Colors.white38, size: 12),
                            SizedBox(width: 4),
                            Text(session['location']!, style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPartnersHorizontalList(String type) {
    final partners = type == "Sponsors" 
      ? [
          {"name": "Google", "logo": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png"},
          {"name": "Microsoft", "logo": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/Microsoft_logo.svg/120px-Microsoft_logo.svg.png"},
          {"name": "Nvidia", "logo": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/21/Nvidia_logo.svg/120px-Nvidia_logo.svg.png"},
          {"name": "Intel", "logo": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c9/Intel-logo.svg/120px-Intel-logo.svg.png"},
        ]
      : [
          {"name": "Tesla", "logo": "https://upload.wikimedia.org/wikipedia/commons/thumb/b/bd/Tesla_Motors_official_logo.svg/120px-Tesla_Motors_official_logo.svg.png"},
          {"name": "SpaceX", "logo": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2e/SpaceX_Logo_Black.svg/120px-SpaceX_Logo_Black.svg.png"},
          {"name": "Apple", "logo": "https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Apple_logo_black.svg/120px-Apple_logo_black.svg.png"},
          {"name": "Sony", "logo": "https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/Sony_logo.svg/120px-Sony_logo.svg.png"},
        ];

    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: partners.length,
        separatorBuilder: (context, index) => SizedBox(width: 16),
        itemBuilder: (context, index) {
          final partner = partners[index];
          return GlassContainer(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Image.network(
                  partner['logo']!,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(LucideIcons.globe, color: Colors.white24, size: 20),
                ),
                SizedBox(width: 10),
                Text(
                  partner['name']!,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: EventzoneTheme.backgroundStart,
        elevation: 0,
        scrolledUnderElevation: 0, // Prevent Material 3 color shifts on scroll
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.share2, color: Colors.white, size: 18),
            onPressed: () async {
              final shareText = "Join me at '${widget.event.title}' on Eventzone! 🚀\n\nDownload the app to register and access the event hub:\nhttps://eventzone.app/download?event_id=${widget.event.id}";
              
              // Copy to clipboard as a reliable fallback (great for emulators, web, and hot-reload state)
              await Clipboard.setData(ClipboardData(text: shareText));
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Share link copied to clipboard!".tr()),
                    backgroundColor: EventzoneTheme.primaryAction,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: Duration(seconds: 2),
                  ),
                );
              }

              // Open native share dialog
              try {
                await Share.share(
                  shareText,
                  subject: "Join ${widget.event.title} on Eventzone",
                );
              } catch (_) {
                // Suppress native channel errors during hot-reload/web tests
              }
            },
          ),
          SizedBox(width: 8),
        ],
      ),
      body: EventzoneTheme.buildPlayfulBackground(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Image Section
              Stack(
                children: [
                  Hero(
                    tag: 'event-image-${widget.event.id}',
                    child: _buildEventImage(widget.event.imageUrl, 300),
                  ),
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          EventzoneTheme.backgroundStart.withOpacity(0.8),
                          EventzoneTheme.backgroundStart,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusPill(label: widget.event.category),
                        SizedBox(height: 12),
                        Text(
                          widget.event.title,
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Column
                    GlassContainer(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildInfoItem(context, LucideIcons.calendar, "Date", _formatDate(widget.event.date)),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Divider(color: Colors.white10, height: 1),
                          ),
                          _buildInfoItem(context, LucideIcons.mapPin, "Location", widget.event.location),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),

                    Text("About Event".tr(), style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(height: 12),
                    Html(
                      data: widget.event.description,
                      style: {
                        "body": Style(
                          fontSize: FontSize(16.0),
                          color: Colors.white70,
                          margin: Margins.zero,
                        ),
                        "p": Style(margin: Margins.only(bottom: 8.0)),
                      },
                    ),
                    
                    SizedBox(height: 30), // Spacing before the bottom navbar pad
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventImage(String imageUrl, double height) {
    if (imageUrl.startsWith('data:image')) {
      // Extract the base64 part
      final base64String = imageUrl.split(',').last;
      try {
        return Image.memory(
          base64Decode(base64String),
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return Container(
          height: height,
          color: Colors.white10,
          child: const Icon(LucideIcons.imageOff, color: Colors.white24),
        );
      }
    }
    return Image.network(
      imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: height,
        color: Colors.white10,
        child: const Icon(LucideIcons.imageOff, color: Colors.white24),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(parsed);
    } catch (e) {
      return dateStr;
    }
  }
}
