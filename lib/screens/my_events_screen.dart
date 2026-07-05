import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/eventzone_theme.dart';
import '../models/event_model.dart';
import '../widgets/qr_action_sheet.dart';

class MyEventsScreen extends StatelessWidget {
  final List<EventModel> registeredEvents;
  final Function(EventModel) onAccessEvent;

  const MyEventsScreen({
    super.key, 
    required this.registeredEvents,
    required this.onAccessEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 72),
              
              // Header & Empty State Handling
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                child: Text(
                  "MY EVENTS",
                  style: GoogleFonts.spaceGrotesk(
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: EventzoneTheme.primaryAction,
                          letterSpacing: 2,
                        ),
                  ),
                ),
              ),
              
              if (registeredEvents.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.calendarX, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text("No upcoming events", style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 16)),

                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
