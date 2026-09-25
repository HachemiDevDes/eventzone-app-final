import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/ticket_model.dart';
import '../theme/eventzone_theme.dart';

class TicketSelectionSheet extends StatelessWidget {
  final String eventTitle;
  final List<TicketModel> tickets;
  final ValueChanged<TicketModel> onSelectTicket;

  const TicketSelectionSheet({
    super.key,
    required this.eventTitle,
    required this.tickets,
    required this.onSelectTicket,
  });

  @override
  Widget build(BuildContext context) {
    // If no tickets configured on remote DB, offer a standard free admission ticket
    final displayTickets = tickets.isNotEmpty
        ? tickets
        : [
            TicketModel(
              id: 'standard-default',
              name: 'Standard Admission'.tr(),
              price: 0,
              description: 'Full summit access, keynote presentations, and exhibition floor access.'.tr(),
              features: [
                'General Keynote Access'.tr(),
                'Exhibition Floor Access'.tr(),
                'Digital Attendee Badge'.tr(),
              ],
              requiresApproval: false,
            ),
          ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1420),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select Your Ticket".tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      eventTitle,
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, color: Colors.white54, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tickets List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: displayTickets.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final ticket = displayTickets[index];
                return _buildTicketCard(context, ticket);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(BuildContext context, TicketModel ticket) {
    final isFree = ticket.isFree;
    final priceStr = isFree
        ? "Free".tr()
        : "${NumberFormat('#,###').format(ticket.price)} ${ticket.currency}";

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161C2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ticket.isPopular
              ? const Color(0xFFF59E0B)
              : EventzoneTheme.primaryAction.withValues(alpha: 0.25),
          width: ticket.isPopular ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Badges & Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ticket.isPopular) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Color(0xFFF59E0B), size: 12),
                              const SizedBox(width: 4),
                              Text(
                                "Most Popular".tr(),
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Text(
                        ticket.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceStr,
                      style: TextStyle(
                        color: isFree ? const Color(0xFF10B981) : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!isFree)
                      Text(
                        "/ attendee".tr(),
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),

            if (ticket.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                ticket.description,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
              ),
            ],

            // Approval notice pill
            if (ticket.requiresApproval) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.clock, color: Color(0xFFF59E0B), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "Requires Organizer Approval".tr(),
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Included Features
            if (ticket.features.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 10),
              ...ticket.features.map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.check, color: Color(0xFF10B981), size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ticket.isPopular
                      ? const Color(0xFFF59E0B)
                      : EventzoneTheme.primaryAction,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onSelectTicket(ticket);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ticket.requiresApproval
                          ? "Apply for Ticket".tr()
                          : "Select & Register".tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.arrowRight, size: 16, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
