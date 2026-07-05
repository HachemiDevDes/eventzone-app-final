import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/status_pill.dart';
import '../models/session_model.dart';
import '../providers/session_providers.dart';

class SessionDetailScreen extends ConsumerWidget {
  final SessionModel session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(sessionFavoritesProvider);
    final isFavorite = favoritesAsync.value?.contains(session.id) ?? false;

    // Format Start and End times
    final startTimeStr = _formatTime(session.startTime);
    final endTimeStr = _formatTime(session.endTime);
    final dateStr = _formatDate(session.startTime);

    return Scaffold(
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        isFavorite ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                        color: isFavorite ? EventzoneTheme.primaryAction : Colors.white70,
                        size: 24,
                      ),
                      onPressed: () => ref.read(sessionFavoritesProvider.notifier).toggleFavorite(session.id),
                    ),
                  ],
                ),
              ),

              // Scrollable Details
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Track Pill
                      if (session.track != null && session.track!.isNotEmpty) ...[
                        StatusPill(
                          label: session.track!.toUpperCase(),
                          isLive: false,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Session Title
                      Text(
                        session.title,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              color: Colors.white,
                              height: 1.25,
                            ),
                      ),
                      const SizedBox(height: 24),

                      // Time & Location Card
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.calendar, color: EventzoneTheme.primaryAction, size: 18),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("DATE & TIME", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                      const SizedBox(height: 2),
                                      Text(
                                        "$dateStr, $startTimeStr - $endTimeStr",
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Divider(color: Colors.white10, height: 1),
                            ),
                            Row(
                              children: [
                                const Icon(LucideIcons.mapPin, color: EventzoneTheme.primaryAction, size: 18),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("LOCATION", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                      const SizedBox(height: 2),
                                      Text(
                                        session.location ?? "TBA",
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Description
                      if (session.description != null && session.description!.isNotEmpty) ...[
                        Text(
                          "ABOUT THIS SESSION",
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: EventzoneTheme.primaryAction,
                                letterSpacing: 1.5,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          session.description!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Speakers
                      if (session.speakers.isNotEmpty) ...[
                        Text(
                          "SPEAKERS",
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: EventzoneTheme.primaryAction,
                                letterSpacing: 1.5,
                              ),
                        ),
                        const SizedBox(height: 16),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: session.speakers.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final speaker = session.speakers[index];
                            return GlassContainer(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: speaker.avatarUrl.isNotEmpty
                                        ? NetworkImage(speaker.avatarUrl)
                                        : null,
                                    child: speaker.avatarUrl.isEmpty
                                        ? const Icon(LucideIcons.user, color: Colors.white38)
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          speaker.name,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          speaker.company.isNotEmpty
                                              ? "${speaker.title} @ ${speaker.company}"
                                              : speaker.title,
                                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Sponsors / Logos
                      if (session.logos.isNotEmpty) ...[
                        Text(
                          "SUPPORTED BY",
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: EventzoneTheme.primaryAction,
                                letterSpacing: 1.5,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: session.logos.map((logo) {
                            return Chip(
                              backgroundColor: Colors.white.withOpacity(0.04),
                              side: const BorderSide(color: Colors.white10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              label: Text(
                                logo,
                                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Button Row
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: const BoxDecoration(
                  color: Color(0xFF070B14),
                  border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final success = await ref
                          .read(sessionFavoritesProvider.notifier)
                          .toggleFavorite(session.id);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isFavorite
                                  ? "Removed from your agenda!"
                                  : "Added to your agenda!",
                            ),
                            backgroundColor: isFavorite
                                ? Colors.white24
                                : EventzoneTheme.accentSuccess,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      isFavorite ? LucideIcons.check : LucideIcons.bookmark,
                      size: 20,
                      color: Colors.white,
                    ),
                    label: Text(
                      isFavorite ? "ADDED TO AGENDA" : "ADD TO AGENDA",
                      style: const TextStyle(
                        
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFavorite
                          ? const Color(0xFF1E2638)
                          : EventzoneTheme.primaryAction,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Time parsing helpers
  String _formatTime(DateTime dateTime) {
    // Return HH:MM AM/PM in UTC
    final localTime = dateTime.toLocal();
    final hour = localTime.hour;
    final min = localTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return "$formattedHour:$min $period";
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${months[local.month - 1]} ${local.day}, ${local.year}";
  }
}
