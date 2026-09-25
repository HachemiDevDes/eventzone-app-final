import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../theme/eventzone_theme.dart';
import 'glass_container.dart';
import 'status_pill.dart';

class EventCard extends StatelessWidget {
  final String title;
  final String date;
  final String location;
  final String category;
  final String imageUrl;
  final bool isLive;
  final String? registrationStatus;
  final VoidCallback? onViewDetails;

  const EventCard({
    super.key,
    required this.title,
    required this.date,
    required this.location,
    required this.category,
    required this.imageUrl,
    this.isLive = false,
    this.registrationStatus,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 24),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onViewDetails,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: _buildEventImage(imageUrl, 160),
                      ),
                      if (isLive)
                        const Positioned(
                          top: 12,
                          left: 12,
                          child: StatusPill(label: "LIVE NOW", isLive: true),
                        ),
                      if (registrationStatus == 'registered')
                        const Positioned(
                          top: 12,
                          right: 12,
                          child: StatusPill(
                            label: "REGISTERED",
                            customColor: Color(0xFF059669),
                            customBorderColor: Color(0xFF6EE7B7),
                          ),
                        )
                      else if (registrationStatus == 'pending')
                        const Positioned(
                          top: 12,
                          right: 12,
                          child: StatusPill(
                            label: "PENDING",
                            customColor: Color(0xFFD97706),
                            customBorderColor: Color(0xFFFCD34D),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title, 
                          style: Theme.of(context).textTheme.headlineMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(LucideIcons.calendar, color: Colors.white38, size: 14),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _formatDate(date), 
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(LucideIcons.mapPin, color: EventzoneTheme.primaryAction, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location, 
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onViewDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EventzoneTheme.primaryAction,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "View Details",
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventImage(String imageUrl, double height) {
    if (imageUrl.startsWith('data:image')) {
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
