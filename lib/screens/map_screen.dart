import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../models/floor_plan_model.dart';
import '../models/exhibitor_model.dart';
import '../providers/session_providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  final String? eventId;

  const MapScreen({super.key, this.eventId});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _matrixAnimation;

  int _selectedPlanIndex = 0;
  int _selectedSubFloorIndex = 0;
  FloorElementModel? _selectedElement;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isSearchOpen = false;

  Size? _lastViewportSize;
  bool _hasAutoFitted = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() {
        if (_matrixAnimation != null) {
          _transformationController.value = _matrixAnimation!.value;
        }
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _animateToMatrix(Matrix4 target) {
    _matrixAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: target,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward(from: 0);
  }

  Rect _calculateContentBounds({
    required BlueprintModel? blueprint,
    required List<FloorElementModel> elements,
    required double canvasWidth,
    required double canvasHeight,
  }) {
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    if (blueprint != null && blueprint.url.isNotEmpty && blueprint.width > 0 && blueprint.height > 0) {
      minX = math.min(minX, blueprint.x);
      maxX = math.max(maxX, blueprint.x + blueprint.width);
      minY = math.min(minY, blueprint.y);
      maxY = math.max(maxY, blueprint.y + blueprint.height);
    }

    for (final el in elements) {
      if (el.width <= 0 || el.height <= 0) continue;
      minX = math.min(minX, el.x);
      maxX = math.max(maxX, el.x + el.width);
      minY = math.min(minY, el.y);
      maxY = math.max(maxY, el.y + el.height);
    }

    if (minX.isInfinite || maxX.isInfinite || minY.isInfinite || maxY.isInfinite) {
      return Rect.fromLTWH(0, 0, canvasWidth > 0 ? canvasWidth : 2400, canvasHeight > 0 ? canvasHeight : 1500);
    }

    // Add generous padding around content
    const double pad = 80.0;
    double bLeft = minX - pad;
    double bTop = minY - pad;
    double bRight = maxX + pad;
    double bBottom = maxY + pad;

    // Minimum span so single-element or small plans don't over-zoom to extreme magnifications
    double bWidth = bRight - bLeft;
    double bHeight = bBottom - bTop;
    const double minSpanW = 750.0;
    const double minSpanH = 500.0;
    if (bWidth < minSpanW) {
      final diff = (minSpanW - bWidth) / 2;
      bLeft -= diff;
      bRight += diff;
    }
    if (bHeight < minSpanH) {
      final diff = (minSpanH - bHeight) / 2;
      bTop -= diff;
      bBottom += diff;
    }

    return Rect.fromLTRB(bLeft, bTop, bRight, bBottom);
  }

  void _zoomToFit(Rect contentBounds, Size viewportSize, {bool animate = true}) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0 || contentBounds.width <= 0 || contentBounds.height <= 0) return;

    const double padding = 24.0;
    final double availW = math.max(viewportSize.width - (padding * 2), 50.0);
    final double availH = math.max(viewportSize.height - (padding * 2), 50.0);

    final double scaleX = availW / contentBounds.width;
    final double scaleY = availH / contentBounds.height;
    final double fitScale = math.min(scaleX, scaleY);
    final double clampedScale = fitScale.clamp(0.08, 1.8);

    final double centerX = contentBounds.left + (contentBounds.width / 2);
    final double centerY = contentBounds.top + (contentBounds.height / 2);

    final double tx = (viewportSize.width / 2) - (centerX * clampedScale);
    final double ty = (viewportSize.height / 2) - (centerY * clampedScale);

    final targetMatrix = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(clampedScale);

    if (animate) {
      _animateToMatrix(targetMatrix);
    } else {
      _transformationController.value = targetMatrix;
    }
  }

  void _zoomToElement(FloorElementModel element, Size viewportSize) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return;

    const double targetScale = 0.9;
    final double centerX = element.x + (element.width / 2);
    final double centerY = element.y + (element.height / 2);

    final double tx = (viewportSize.width / 2) - (centerX * targetScale);
    final double ty = (viewportSize.height * 0.38) - (centerY * targetScale);

    final targetMatrix = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(targetScale);

    _animateToMatrix(targetMatrix);
  }

  ExhibitorModel? _findExhibitorForElement(FloorElementModel element, List<ExhibitorModel> exhibitors) {
    if (element.exhibitorId != null && element.exhibitorId!.isNotEmpty) {
      final match = exhibitors.firstWhere(
        (ex) => ex.id.toLowerCase() == element.exhibitorId!.toLowerCase(),
        orElse: () => ExhibitorModel(id: '', name: ''),
      );
      if (match.id.isNotEmpty) return match;
    }

    final cleanLabel = element.label.trim().toLowerCase();
    if (cleanLabel.isNotEmpty) {
      final match = exhibitors.firstWhere(
        (ex) {
          final b = (ex.booth ?? '').trim().toLowerCase();
          return b == cleanLabel || b.replaceAll(RegExp(r'[^a-z0-9]'), '') == cleanLabel.replaceAll(RegExp(r'[^a-z0-9]'), '');
        },
        orElse: () => ExhibitorModel(id: '', name: ''),
      );
      if (match.id.isNotEmpty) return match;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final eventId = widget.eventId ?? '';
    final plansAsync = eventId.isNotEmpty
        ? ref.watch(eventFloorPlansProvider(eventId))
        : const AsyncValue.data(<FloorPlanModel>[]);
    final exhibitorsAsync = eventId.isNotEmpty
        ? ref.watch(eventExhibitorsProvider(eventId))
        : const AsyncValue.data(<ExhibitorModel>[]);

    return Scaffold(
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              _buildHeader(),
              Expanded(
                child: plansAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: EventzoneTheme.primaryAction),
                  ),
                  error: (err, _) => _buildEmptyOrErrorState(
                    title: "Could not load floor plan".tr(),
                    subtitle: err.toString(),
                    icon: LucideIcons.alertCircle,
                  ),
                  data: (plans) {
                    if (plans.isEmpty) {
                      return _buildEmptyOrErrorState(
                        title: "No Floor Plan Available".tr(),
                        subtitle: "The organizers have not published a floor plan for this event yet.".tr(),
                        icon: LucideIcons.map,
                      );
                    }

                    final safePlanIndex = _selectedPlanIndex < plans.length ? _selectedPlanIndex : 0;
                    final activePlan = plans[safePlanIndex];

                    // Resolve active sub-floor if available
                    final floors = activePlan.floors;
                    final bool hasSubFloors = floors.length > 1;
                    final safeFloorIndex = _selectedSubFloorIndex < floors.length ? _selectedSubFloorIndex : 0;
                    
                    final List<FloorElementModel> currentElements = (hasSubFloors && floors.isNotEmpty)
                        ? (floors[safeFloorIndex].elements.isNotEmpty ? floors[safeFloorIndex].elements : activePlan.elements)
                        : activePlan.elements;

                    final BlueprintModel? currentBlueprint = (hasSubFloors && floors.isNotEmpty && floors[safeFloorIndex].blueprint != null)
                        ? floors[safeFloorIndex].blueprint
                        : activePlan.blueprint;

                    final double canvasW = currentBlueprint?.canvasWidth ?? activePlan.canvasWidth;
                    final double canvasH = currentBlueprint?.canvasHeight ?? activePlan.canvasHeight;

                    final exhibitors = exhibitorsAsync.valueOrNull ?? [];

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

                        final bounds = _calculateContentBounds(
                          blueprint: currentBlueprint,
                          elements: currentElements,
                          canvasWidth: canvasW,
                          canvasHeight: canvasH,
                        );

                        // Auto-fit once on initial build or viewport size change
                        if (!_hasAutoFitted || _lastViewportSize != viewportSize) {
                          _lastViewportSize = viewportSize;
                          _hasAutoFitted = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _zoomToFit(bounds, viewportSize, animate: false);
                          });
                        }

                        // Filter elements by search query
                        final filteredElements = _searchQuery.trim().isEmpty
                            ? currentElements
                            : currentElements.where((el) {
                                final q = _searchQuery.toLowerCase();
                                final matchLabel = el.label.toLowerCase().contains(q);
                                final ex = _findExhibitorForElement(el, exhibitors);
                                final matchEx = ex != null && (ex.name.toLowerCase().contains(q) || (ex.industry ?? '').toLowerCase().contains(q));
                                return matchLabel || matchEx;
                              }).toList();

                        return Stack(
                          children: [
                            // Main Interactive Canvas
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 16.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1.0,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    color: const Color(0xFF0F172A),
                                    child: InteractiveViewer(
                                      transformationController: _transformationController,
                                      constrained: false,
                                      boundaryMargin: const EdgeInsets.all(1200),
                                      minScale: 0.06,
                                      maxScale: 4.0,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onTap: () {
                                          if (_selectedElement != null) {
                                            setState(() => _selectedElement = null);
                                          }
                                        },
                                        child: Container(
                                          width: canvasW,
                                          height: canvasH,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.35),
                                                blurRadius: 30,
                                                spreadRadius: 4,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              // Subtle architectural grid background on white canvas
                                              ..._buildGridLines(canvasW, canvasH),

                                              // Background Blueprint Image (if available)
                                              if (currentBlueprint != null && currentBlueprint.url.isNotEmpty)
                                                Positioned(
                                                  left: currentBlueprint.x,
                                                  top: currentBlueprint.y,
                                                  width: currentBlueprint.width,
                                                  height: currentBlueprint.height,
                                                  child: Transform.rotate(
                                                    angle: currentBlueprint.rotation * (math.pi / 180),
                                                    child: Opacity(
                                                      opacity: currentBlueprint.opacity.clamp(0.1, 1.0),
                                                      child: Image.network(
                                                        currentBlueprint.url,
                                                        fit: BoxFit.fill,
                                                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                              // Render all Booths, Stages, and Structures
                                              for (final element in currentElements)
                                                _buildElementWidget(
                                                  element: element,
                                                  exhibitor: _findExhibitorForElement(element, exhibitors),
                                                  isSelected: _selectedElement?.id == element.id,
                                                  isDimmed: _searchQuery.isNotEmpty && !filteredElements.contains(element),
                                                  onTap: () {
                                                    setState(() => _selectedElement = element);
                                                    _zoomToElement(element, viewportSize);
                                                  },
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Top overlay: Sub-floor switcher (if multiple floors exist)
                            if (hasSubFloors)
                              Positioned(
                                top: 18,
                                left: 28,
                                right: 28,
                                child: _buildFloorSwitcher(floors, safeFloorIndex, (newIdx) {
                                  setState(() {
                                    _selectedSubFloorIndex = newIdx;
                                    _selectedElement = null;
                                  });
                                  final nextElements = (newIdx < floors.length && floors[newIdx].elements.isNotEmpty)
                                      ? floors[newIdx].elements
                                      : activePlan.elements;
                                  final nextBlueprint = (newIdx < floors.length && floors[newIdx].blueprint != null)
                                      ? floors[newIdx].blueprint
                                      : activePlan.blueprint;
                                  final nextBounds = _calculateContentBounds(
                                    blueprint: nextBlueprint,
                                    elements: nextElements,
                                    canvasWidth: nextBlueprint?.canvasWidth ?? activePlan.canvasWidth,
                                    canvasHeight: nextBlueprint?.canvasHeight ?? activePlan.canvasHeight,
                                  );
                                  _zoomToFit(nextBounds, viewportSize, animate: true);
                                }),
                              ),

                            // Search bar overlay
                            if (_isSearchOpen)
                              Positioned(
                                top: hasSubFloors ? 68 : 18,
                                left: 28,
                                right: 28,
                                child: _buildSearchBar(filteredElements, exhibitors, viewportSize),
                              ),

                            // Bottom overlay: Selected Booth Details Card
                            if (_selectedElement != null)
                              Positioned(
                                bottom: 20,
                                left: 24,
                                right: 24,
                                child: _buildSelectedBoothCard(
                                  _selectedElement!,
                                  _findExhibitorForElement(_selectedElement!, exhibitors),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "VENUE".tr(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                "Live Floor Plan".tr(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                    ),
              ),
            ],
          ),
          Row(
            children: [
              // Search toggle button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _isSearchOpen = !_isSearchOpen;
                    if (!_isSearchOpen) {
                      _searchQuery = "";
                      _searchController.clear();
                    }
                  });
                },
                child: GlassContainer(
                  padding: const EdgeInsets.all(10),
                  borderRadius: 14,
                  child: Icon(
                    _isSearchOpen ? LucideIcons.x : LucideIcons.search,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Re-center / Zoom to fit button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_lastViewportSize != null) {
                    final plans = widget.eventId != null
                        ? ref.read(eventFloorPlansProvider(widget.eventId!)).valueOrNull ?? []
                        : <FloorPlanModel>[];
                    if (plans.isNotEmpty) {
                      final plan = plans[_selectedPlanIndex < plans.length ? _selectedPlanIndex : 0];
                      final floors = plan.floors;
                      final bool hasSubFloors = floors.length > 1;
                      final safeFloorIndex = _selectedSubFloorIndex < floors.length ? _selectedSubFloorIndex : 0;
                      final elements = (hasSubFloors && floors.isNotEmpty)
                          ? (floors[safeFloorIndex].elements.isNotEmpty ? floors[safeFloorIndex].elements : plan.elements)
                          : plan.elements;
                      final blueprint = (hasSubFloors && floors.isNotEmpty && floors[safeFloorIndex].blueprint != null)
                          ? floors[safeFloorIndex].blueprint
                          : plan.blueprint;
                      final bounds = _calculateContentBounds(
                        blueprint: blueprint,
                        elements: elements,
                        canvasWidth: blueprint?.canvasWidth ?? plan.canvasWidth,
                        canvasHeight: blueprint?.canvasHeight ?? plan.canvasHeight,
                      );
                      _zoomToFit(bounds, _lastViewportSize!, animate: true);
                    }
                  }
                },
                child: GlassContainer(
                  padding: const EdgeInsets.all(10),
                  borderRadius: 14,
                  child: const Icon(LucideIcons.locateFixed, color: EventzoneTheme.primaryAction, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloorSwitcher(List<SubFloorModel> floors, int activeIdx, ValueChanged<int> onSelect) {
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        borderRadius: 20,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(floors.length, (idx) {
            final isSelected = idx == activeIdx;
            final floor = floors[idx];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? EventzoneTheme.primaryAction : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  floor.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSearchBar(List<FloorElementModel> filteredElements, List<ExhibitorModel> exhibitors, Size viewportSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          borderRadius: 20,
          child: Row(
            children: [
              const Icon(LucideIcons.search, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: "Search booth # or company...".tr(),
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                  child: const Icon(LucideIcons.xCircle, color: Colors.white38, size: 16),
                ),
            ],
          ),
        ),

        // Quick results preview dropdown
        if (_searchQuery.isNotEmpty && filteredElements.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: 16,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: math.min(filteredElements.length, 5),
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, idx) {
                    final el = filteredElements[idx];
                    final ex = _findExhibitorForElement(el, exhibitors);
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      title: Text(
                        "Booth #${el.label}".tr(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: ex != null
                          ? Text(
                              ex.name,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            )
                          : Text(
                              el.statusDisplay,
                              style: TextStyle(color: el.statusStrokeColor, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                      trailing: const Icon(LucideIcons.chevronRight, color: Colors.white38, size: 14),
                      onTap: () {
                        setState(() {
                          _selectedElement = el;
                          _isSearchOpen = false;
                        });
                        _zoomToElement(el, viewportSize);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildElementWidget({
    required FloorElementModel element,
    required ExhibitorModel? exhibitor,
    required bool isSelected,
    required bool isDimmed,
    required VoidCallback onTap,
  }) {
    final double w = element.width;
    final double h = element.height;

    // 1. Specialized rendering for small seats/chairs
    if (element.isChair || (w <= 36 && h <= 36 && !element.isBooth)) {
      return Positioned(
        left: element.x,
        top: element.y,
        width: w,
        height: h,
        child: Transform.rotate(
          angle: element.rotation * (math.pi / 180),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected ? EventzoneTheme.primaryAction : element.statusFillColor,
                borderRadius: BorderRadius.circular(math.min(w, h) * 0.25),
                border: Border.all(
                  color: isSelected ? Colors.white : element.statusStrokeColor,
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: EventzoneTheme.primaryAction.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: (w >= 22 && h >= 22 && element.label.isNotEmpty && !element.label.toLowerCase().startsWith('furniture'))
                    ? Text(
                        element.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : element.statusTextColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                      )
                    : null,
              ),
            ),
          ),
        ),
      );
    }

    // 2. Stage
    if (element.isStage) {
      return Positioned(
        left: element.x,
        top: element.y,
        width: w,
        height: h,
        child: Transform.rotate(
          angle: element.rotation * (math.pi / 180),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: isDimmed ? 0.25 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF3E8FF) : element.statusFillColor,
                  borderRadius: BorderRadius.circular((math.min(w, h) * 0.08).clamp(4.0, 12.0)),
                  border: Border.all(
                    color: isSelected ? EventzoneTheme.primaryAction : element.statusStrokeColor,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: EventzoneTheme.primaryAction.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                padding: const EdgeInsets.all(4.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.mic,
                        size: math.min(w, h) * 0.22,
                        color: element.statusTextColor,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        element.label.isNotEmpty ? element.label : "STAGE".tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: element.statusTextColor,
                          fontSize: (w < 80 || h < 60) ? 9 : 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 3. Screen / AV
    if (element.isScreen) {
      return Positioned(
        left: element.x,
        top: element.y,
        width: w,
        height: h,
        child: Transform.rotate(
          angle: element.rotation * (math.pi / 180),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? EventzoneTheme.primaryAction : const Color(0xFF38BDF8),
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: EventzoneTheme.primaryAction.withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.tv, size: 12, color: Color(0xFF38BDF8)),
                    if (w >= 60) ...[
                      const SizedBox(width: 4),
                      Text(
                        element.label.isNotEmpty ? element.label : "SCREEN".tr(),
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 4. Entrance / Exit
    if (element.isEntrance || element.isExit) {
      final isEnt = element.isEntrance;
      return Positioned(
        left: element.x,
        top: element.y,
        width: w,
        height: h,
        child: Transform.rotate(
          angle: element.rotation * (math.pi / 180),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isEnt ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isEnt ? const Color(0xFF059669) : const Color(0xFFE11D48),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isEnt ? LucideIcons.logIn : LucideIcons.logOut,
                      size: 13,
                      color: isEnt ? const Color(0xFF047857) : const Color(0xFFBE123C),
                    ),
                    if (w >= 60) ...[
                      const SizedBox(width: 4),
                      Text(
                        element.label.isNotEmpty ? element.label : (isEnt ? "ENTRANCE".tr() : "EXIT".tr()),
                        style: TextStyle(
                          color: isEnt ? const Color(0xFF047857) : const Color(0xFFBE123C),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 5. Standard / Semi / Equipped Booths and other general structures
    final double radius = (math.min(w, h) * 0.08).clamp(3.0, 8.0);
    final double labelFontSize = (w < 70 || h < 55) ? 9.0 : ((w < 100 || h < 80) ? 11.0 : 13.0);
    final double exhibitorFontSize = (w < 80 || h < 65) ? 7.5 : 9.0;

    return Positioned(
      left: element.x,
      top: element.y,
      width: w,
      height: h,
      child: Transform.rotate(
        angle: element.rotation * (math.pi / 180),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isDimmed ? 0.25 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEFF6FF)
                    : element.statusFillColor,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: isSelected
                      ? EventzoneTheme.primaryAction
                      : element.statusStrokeColor,
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: EventzoneTheme.primaryAction.withOpacity(0.4),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Booth Label / Number
                      Text(
                        element.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? EventzoneTheme.primaryAction : element.statusTextColor,
                          fontSize: labelFontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Exhibitor name (if present)
                      if (exhibitor != null && h >= 48) ...[
                        const SizedBox(height: 1),
                        Text(
                          exhibitor.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF334155),
                            fontSize: exhibitorFontSize,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else if (h >= 58 && element.isBooth) ...[
                        // Status pill
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: element.statusStrokeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            element.statusDisplay,
                            style: TextStyle(
                              color: element.statusStrokeColor,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedBoothCard(FloorElementModel element, ExhibitorModel? exhibitor) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: element.statusStrokeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: element.statusStrokeColor.withOpacity(0.6)),
                    ),
                    child: Text(
                      element.isBooth ? "Booth #${element.label}".tr() : element.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: element.statusStrokeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: element.statusStrokeColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      element.statusDisplay,
                      style: TextStyle(
                        color: element.statusStrokeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedElement = null),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.x, color: Colors.white70, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (exhibitor != null) ...[
            Row(
              children: [
                if (exhibitor.logo != null && exhibitor.logo!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      exhibitor.logo!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallbackLogo(exhibitor.name),
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  _buildFallbackLogo(exhibitor.name),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exhibitor.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (exhibitor.industry != null && exhibitor.industry!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          exhibitor.industry!,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (exhibitor.description != null && exhibitor.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                exhibitor.description!,
                style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ] else ...[
            Row(
              children: [
                const Icon(LucideIcons.layoutGrid, color: Colors.white60, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        element.isAvailable ? "Space Available".tr() : "${element.statusDisplay} Space".tr(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        element.surfaceArea != null
                            ? "${element.surfaceArea} m² (${element.width.toInt()} × ${element.height.toInt()} px)"
                            : "${(element.width / 20 * element.height / 20).toStringAsFixed(1)} m² (${element.width.toInt()} × ${element.height.toInt()} px)",
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackLogo(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'E';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: EventzoneTheme.primaryAction.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: EventzoneTheme.primaryAction.withOpacity(0.4)),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  List<Widget> _buildGridLines(double width, double height) {
    const double gridSize = 80.0;
    final int rows = (height / gridSize).floor();
    final int cols = (width / gridSize).floor();

    return [
      for (int i = 0; i <= rows; i++)
        Positioned(
          top: i * gridSize,
          left: 0,
          right: 0,
          child: Container(
            height: 1,
            color: (i % 4 == 0) ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
          ),
        ),
      for (int i = 0; i <= cols; i++)
        Positioned(
          left: i * gridSize,
          top: 0,
          bottom: 0,
          child: Container(
            width: 1,
            color: (i % 4 == 0) ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
          ),
        ),
    ];
  }

  Widget _buildEmptyOrErrorState({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: GlassContainer(
          padding: const EdgeInsets.all(28),
          borderRadius: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white30, size: 48),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
