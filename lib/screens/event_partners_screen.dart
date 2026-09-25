import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/exhibitor_model.dart';
import '../models/sponsor_model.dart';
import '../providers/session_providers.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';

class EventPartnersScreen extends ConsumerStatefulWidget {
  final String? eventId;
  final String type; // "Exhibitors" or "Sponsors"

  const EventPartnersScreen({
    super.key,
    this.eventId,
    required this.type,
  });

  @override
  ConsumerState<EventPartnersScreen> createState() => _EventPartnersScreenState();
}

class _EventPartnersScreenState extends ConsumerState<EventPartnersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTier = 'All';

  bool get isSponsors => widget.type.toLowerCase().contains("sponsor");

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchWeb(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final uriStr = trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(uriStr);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchMail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: trimmed);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventId = widget.eventId ?? '';
    final canPop = Navigator.canPop(context);

    return Scaffold(
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Spacing & Header
              SizedBox(height: canPop ? 12 : 72),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (canPop)
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Back".tr(),
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isSponsors ? "SPONSORS".tr() : "EXHIBITORS".tr(),
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: EventzoneTheme.primaryAction,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isSponsors ? "Official Sponsors".tr() : "Exhibitor Directory".tr(),
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 26,
                                    color: Colors.white,
                                  ),
                            ),
                          ],
                        ),
                        // Count pill
                        _buildCountPill(eventId),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim().toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: isSponsors
                              ? "Search sponsors, tier, industry...".tr()
                              : "Search exhibitors, booth, industry...".tr(),
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 13.5,
                          ),
                          prefixIcon: const Icon(LucideIcons.search, color: Colors.white38, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(LucideIcons.x, color: Colors.white38, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content: Sponsors or Exhibitors
              Expanded(
                child: isSponsors ? _buildSponsorsBody(eventId) : _buildExhibitorsBody(eventId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountPill(String eventId) {
    if (eventId.isEmpty) return const SizedBox.shrink();

    if (isSponsors) {
      final sponsorsAsync = ref.watch(eventSponsorsProvider(eventId));
      return sponsorsAsync.maybeWhen(
        data: (sponsors) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: EventzoneTheme.primaryAction.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: EventzoneTheme.primaryAction.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            "${sponsors.length}",
            style: const TextStyle(
              color: EventzoneTheme.primaryAction,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      );
    } else {
      final exhibitorsAsync = ref.watch(eventExhibitorsProvider(eventId));
      return exhibitorsAsync.maybeWhen(
        data: (exhibitors) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: EventzoneTheme.primaryAction.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: EventzoneTheme.primaryAction.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            "${exhibitors.length}",
            style: const TextStyle(
              color: EventzoneTheme.primaryAction,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      );
    }
  }

  // ─────────────────────────────────────────────
  //  SPONSORS VIEW
  // ─────────────────────────────────────────────
  Widget _buildSponsorsBody(String eventId) {
    if (eventId.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.award,
        title: "No Sponsors Yet".tr(),
        subtitle: "Official sponsors have not been listed for this event yet.".tr(),
      );
    }

    final sponsorsAsync = ref.watch(eventSponsorsProvider(eventId));

    return sponsorsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: EventzoneTheme.primaryAction),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            "Failed to load sponsors: $err",
            style: const TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (sponsors) {
        if (sponsors.isEmpty) {
          return _buildEmptyState(
            icon: LucideIcons.award,
            title: "No Sponsors Yet".tr(),
            subtitle: "Official sponsors have not been listed for this event yet.".tr(),
          );
        }

        // Distinct tiers for filter chips
        final distinctTiers = <String>{'All'};
        for (final sp in sponsors) {
          if (sp.tier != null && sp.tier!.trim().isNotEmpty) {
            distinctTiers.add(sp.tier!.trim());
          }
        }

        final filtered = sponsors.where((s) {
          final matchesQuery = _searchQuery.isEmpty ||
              s.name.toLowerCase().contains(_searchQuery) ||
              (s.tier != null && s.tier!.toLowerCase().contains(_searchQuery)) ||
              (s.industry != null && s.industry!.toLowerCase().contains(_searchQuery)) ||
              (s.description != null && s.description!.toLowerCase().contains(_searchQuery));

          final matchesTier = _selectedTier == 'All' ||
              (s.tier != null && s.tier!.trim().toLowerCase() == _selectedTier.toLowerCase());

          return matchesQuery && matchesTier;
        }).toList();

        final Map<String, List<SponsorModel>> groupedSponsors = {};
        for (final sp in filtered) {
          final rawTier = sp.tier?.trim();
          final tierKey = (rawTier != null && rawTier.isNotEmpty) ? rawTier : 'Sponsors'.tr();
          groupedSponsors.putIfAbsent(tierKey, () => []).add(sp);
        }

        final sortedTiers = groupedSponsors.keys.toList()
          ..sort((a, b) {
            final rankA = _tierRank(a);
            final rankB = _tierRank(b);
            if (rankA != rankB) return rankA.compareTo(rankB);
            return a.toLowerCase().compareTo(b.toLowerCase());
          });

        return Column(
          children: [
            // Tier filter chips (if multiple tiers exist)
            if (distinctTiers.length > 2)
              _buildTierFilterChips(distinctTiers),

            // Tier-separated sponsors scroll view
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(
                      icon: LucideIcons.searchX,
                      title: "No Matching Sponsors".tr(),
                      subtitle: "Try searching with a different keyword or tier.".tr(),
                    )
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        for (final tier in sortedTiers) ...[
                          SliverToBoxAdapter(
                            child: _buildTierHeader(tier, groupedSponsors[tier]!.length),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.95,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final sponsor = groupedSponsors[tier]![index];
                                  return _buildSponsorCard(context, sponsor);
                                },
                                childCount: groupedSponsors[tier]!.length,
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 12),
                          ),
                        ],
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 24),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTierFilterChips(Set<String> distinctTiers) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: distinctTiers.map((tier) {
            final isSelected = _selectedTier.toLowerCase() == tier.toLowerCase();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(tier.toUpperCase()),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedTier = tier;
                  });
                },
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                selectedColor: EventzoneTheme.primaryAction.withValues(alpha: 0.2),
                checkmarkColor: EventzoneTheme.primaryAction,
                side: BorderSide(
                  color: isSelected
                      ? EventzoneTheme.primaryAction
                      : Colors.white.withValues(alpha: 0.1),
                ),
                labelStyle: TextStyle(
                  color: isSelected ? EventzoneTheme.primaryAction : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTierHeader(String tier, int count) {
    final tierColor = _getTierColor(tier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Vertical accent bar
          Container(
            width: 3.5,
            height: 16,
            decoration: BoxDecoration(
              color: tierColor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: tierColor.withValues(alpha: 0.5),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Tier Name
          Text(
            tier.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),

          const SizedBox(width: 8),

          // Count pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tierColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              "$count",
              style: TextStyle(
                color: tierColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Subtle horizontal separator line
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSponsorCard(BuildContext context, SponsorModel sponsor) {
    final hasWebsite = sponsor.website != null && sponsor.website!.isNotEmpty;

    return GestureDetector(
      onTap: () => _showSponsorDetailsSheet(context, sponsor),
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top: External icon (if website available), no tier chip
            Align(
              alignment: Alignment.topRight,
              child: hasWebsite
                  ? const Icon(LucideIcons.externalLink, color: Colors.white30, size: 14)
                  : const SizedBox(height: 14),
            ),

            // Centered Logo
            _buildPartnerLogo(sponsor.logo, sponsor.name, isSponsor: true, size: 56),

            // Bottom Name and Industry
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sponsor.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (sponsor.industry != null && sponsor.industry!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sponsor.industry!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  EXHIBITORS VIEW
  // ─────────────────────────────────────────────
  Widget _buildExhibitorsBody(String eventId) {
    if (eventId.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.store,
        title: "No Exhibitors Yet".tr(),
        subtitle: "Exhibitors have not been announced for this event yet.".tr(),
      );
    }

    final exhibitorsAsync = ref.watch(eventExhibitorsProvider(eventId));

    return exhibitorsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: EventzoneTheme.primaryAction),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            "Failed to load exhibitors: $err",
            style: const TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (exhibitors) {
        if (exhibitors.isEmpty) {
          return _buildEmptyState(
            icon: LucideIcons.store,
            title: "No Exhibitors Yet".tr(),
            subtitle: "Exhibitors have not been announced for this event yet.".tr(),
          );
        }

        final filtered = exhibitors.where((ex) {
          if (_searchQuery.isEmpty) return true;
          return ex.name.toLowerCase().contains(_searchQuery) ||
              (ex.booth != null && ex.booth!.toLowerCase().contains(_searchQuery)) ||
              (ex.industry != null && ex.industry!.toLowerCase().contains(_searchQuery)) ||
              (ex.description != null && ex.description!.toLowerCase().contains(_searchQuery));
        }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(
            icon: LucideIcons.searchX,
            title: "No Matching Exhibitors".tr(),
            subtitle: "Try searching with a different company or booth name.".tr(),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.95,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final exhibitor = filtered[index];
            return _buildExhibitorCard(context, exhibitor);
          },
        );
      },
    );
  }

  Widget _buildExhibitorCard(BuildContext context, ExhibitorModel exhibitor) {
    final hasBooth = exhibitor.booth != null && exhibitor.booth!.trim().isNotEmpty;

    return GestureDetector(
      onTap: () => _showExhibitorDetailsSheet(context, exhibitor),
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top: Booth chip & External Link
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (hasBooth)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: EventzoneTheme.primaryAction.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: EventzoneTheme.primaryAction.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      "${'Booth'.tr()} #${exhibitor.booth}",
                      style: const TextStyle(
                        color: EventzoneTheme.primaryAction,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (exhibitor.website != null && exhibitor.website!.isNotEmpty)
                  const Icon(LucideIcons.externalLink, color: Colors.white30, size: 14)
                else
                  const SizedBox(width: 14, height: 14),
              ],
            ),

            // Centered Logo
            _buildPartnerLogo(exhibitor.logo, exhibitor.name, isSponsor: false, size: 52),

            // Bottom Name and Industry
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  exhibitor.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (exhibitor.industry != null && exhibitor.industry!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    exhibitor.industry!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  MODAL DETAILS SHEETS
  // ─────────────────────────────────────────────
  void _showSponsorDetailsSheet(BuildContext context, SponsorModel sponsor) {
    final tierColor = _getTierColor(sponsor.tier);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0F1523),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white12, width: 0.8)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Logo & Basic Info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildPartnerLogo(sponsor.logo, sponsor.name, isSponsor: true, size: 68),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sponsor.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (sponsor.tier != null && sponsor.tier!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: tierColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: tierColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    "${sponsor.tier!.toUpperCase()} SPONSOR",
                                    style: TextStyle(
                                      color: tierColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                              if (sponsor.industry != null && sponsor.industry!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  sponsor.industry!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Description
                    if (sponsor.description != null && sponsor.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        "ABOUT THIS PARTNER".tr(),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sponsor.description!.trim(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    ],

                    // Visit Website button
                    if (sponsor.website != null && sponsor.website!.trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchWeb(sponsor.website!),
                          icon: const Icon(LucideIcons.globe, size: 16),
                          label: Text("Visit Website".tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EventzoneTheme.primaryAction,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(
                          "Close".tr(),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showExhibitorDetailsSheet(BuildContext context, ExhibitorModel exhibitor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0F1523),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white12, width: 0.8)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Logo & Basic Info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildPartnerLogo(exhibitor.logo, exhibitor.name, isSponsor: false, size: 68),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exhibitor.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (exhibitor.booth != null && exhibitor.booth!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: EventzoneTheme.primaryAction.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: EventzoneTheme.primaryAction.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    "${'Booth'.tr()} #${exhibitor.booth}",
                                    style: const TextStyle(
                                      color: EventzoneTheme.primaryAction,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                              if (exhibitor.industry != null && exhibitor.industry!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  exhibitor.industry!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Description / Products
                    if (exhibitor.description != null && exhibitor.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        "ABOUT THIS EXHIBITOR".tr(),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        exhibitor.description!.trim(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    ],

                    // Contact Email Action
                    if (exhibitor.contactEmail != null && exhibitor.contactEmail!.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => _launchMail(exhibitor.contactEmail!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.mail, color: EventzoneTheme.primaryAction, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  exhibitor.contactEmail!.trim(),
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(LucideIcons.externalLink, color: Colors.white30, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Action buttons
                    if (exhibitor.website != null && exhibitor.website!.trim().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchWeb(exhibitor.website!),
                          icon: const Icon(LucideIcons.globe, size: 16),
                          label: Text("Visit Website".tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EventzoneTheme.primaryAction,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(
                          "Close".tr(),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────
  Widget _buildPartnerLogo(String? logoUrl, String name, {required bool isSponsor, double size = 48}) {
    final validUrl = logoUrl != null &&
        logoUrl.trim().isNotEmpty &&
        (logoUrl.startsWith('http://') || logoUrl.startsWith('https://') || logoUrl.startsWith('data:image'));

    if (validUrl) {
      Widget imageWidget;
      if (logoUrl.startsWith('data:image')) {
        final base64String = logoUrl.split(',').last;
        try {
          imageWidget = Image.memory(
            base64Decode(base64String),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(name, isSponsor: isSponsor, size: size),
          );
        } catch (_) {
          imageWidget = _buildFallbackLogo(name, isSponsor: isSponsor, size: size);
        }
      } else {
        imageWidget = Image.network(
          logoUrl.trim(),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(name, isSponsor: isSponsor, size: size),
        );
      }

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: imageWidget,
        ),
      );
    }
    return _buildFallbackLogo(name, isSponsor: isSponsor, size: size);
  }

  Widget _buildFallbackLogo(String name, {required bool isSponsor, double size = 48}) {
    final trimmed = name.trim();
    final initial = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : (isSponsor ? 'S' : 'E');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: isSponsor ? const Color(0xFFF59E0B) : EventzoneTheme.primaryAction,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  int _tierRank(String tier) {
    final lower = tier.toLowerCase();
    if (lower.contains('headline') || lower.contains('title') || lower.contains('presenting')) return 0;
    if (lower.contains('diamond')) return 1;
    if (lower.contains('platinum')) return 2;
    if (lower.contains('gold')) return 3;
    if (lower.contains('silver')) return 4;
    if (lower.contains('bronze')) return 5;
    if (lower.contains('partner') || lower.contains('official')) return 6;
    if (lower.contains('supporter') || lower.contains('supporting') || lower.contains('media') || lower.contains('community')) return 7;
    return 8;
  }

  Color _getTierColor(String? tier) {
    if (tier == null) return const Color(0xFF94A3B8);
    final lower = tier.toLowerCase();
    if (lower.contains('headline') || lower.contains('title') || lower.contains('presenting')) return const Color(0xFFEC4899);
    if (lower.contains('diamond')) return const Color(0xFF38BDF8);
    if (lower.contains('platinum')) return const Color(0xFFA855F7);
    if (lower.contains('gold')) return const Color(0xFFF59E0B);
    if (lower.contains('silver')) return const Color(0xFF94A3B8);
    if (lower.contains('bronze')) return const Color(0xFFD97706);
    return EventzoneTheme.primaryAction;
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: Icon(icon, color: Colors.white30, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
