import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/event_model.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/event_card.dart';
import 'event_details_screen.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

class EventsScreen extends StatefulWidget {
  final List<EventModel> events;
  final bool isLoading;
  final Function(EventModel) onEventJoined;
  final Function(EventModel) onAccessEvent;
  final Future<void> Function()? onRefresh;

  const EventsScreen({
    super.key,
    required this.events,
    this.isLoading = false,
    required this.onEventJoined,
    required this.onAccessEvent,
    this.onRefresh,
  });

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = widget.events.where((e) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return e.title.toLowerCase().contains(q) ||
          e.location.toLowerCase().contains(q) ||
          e.category.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 16),
                child: Text(
                  "Upcoming Events".tr(),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search events by name or keyword...".tr(),
                    hintStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(LucideIcons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: EventzoneTheme.primaryAction),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: widget.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: EventzoneTheme.primaryAction),
                      )
                    : RefreshIndicator(
                        onRefresh: widget.onRefresh ?? () async {},
                        color: EventzoneTheme.primaryAction,
                        backgroundColor: const Color(0xFF0F121E),
                        child: filteredEvents.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                                  Center(
                                    child: Text(
                                      _searchQuery.isEmpty 
                                        ? "No events available right now.".tr()
                                        : "No events match your search.".tr(),
                                      style: const TextStyle(color: Colors.white60, fontSize: 16),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                itemCount: filteredEvents.length,
                                itemBuilder: (context, index) {
                                  final event = filteredEvents[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: EventCard(
                                      title: event.title,
                                      date: event.date,
                                      location: event.location,
                                      category: event.category,
                                      imageUrl: event.imageUrl,
                                      isLive: event.isLive,
                                      registrationStatus: event.registrationStatus,
                                      onViewDetails: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EventDetailsScreen(
                                              event: event,
                                              onRegister: () => widget.onEventJoined(event),
                                              onAccess: () => widget.onAccessEvent(event),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
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
