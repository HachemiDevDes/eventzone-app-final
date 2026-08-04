import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/eventzone_theme.dart';
import '../providers/crm_providers.dart';
import '../services/export_service.dart';

class ExportContactsSheet extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> connections;

  const ExportContactsSheet({Key? key, required this.connections}) : super(key: key);

  @override
  ConsumerState<ExportContactsSheet> createState() => _ExportContactsSheetState();
}

class _ExportContactsSheetState extends ConsumerState<ExportContactsSheet> {
  final PageController _pageController = PageController();
  
  String? _selectedTimeFilterTitle;
  int? _selectedTimeFilterDays;
  
  String? _selectedFormat; // 'XLSX', 'CSV', or CrmType.id

  void _goToFormatSelection(String title, int? days) {
    setState(() {
      _selectedTimeFilterTitle = title;
      _selectedTimeFilterDays = days;
      _selectedFormat = 'XLSX'; // Hardcode format to hide CRM options for now
    });
    _handleExport(); // Export immediately without going to the next page
  }

  void _goBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleExport() async {
    if (_selectedFormat == null) return;

    // Filter connections based on time filter
    List<Map<String, dynamic>> filtered = widget.connections;
    if (_selectedTimeFilterDays != null) {
      final now = DateTime.now();
      filtered = widget.connections.where((c) {
        final createdAtStr = c['created_at'];
        if (createdAtStr == null) return false;
        try {
          final createdAt = DateTime.parse(createdAtStr);
          final diff = now.difference(createdAt).inDays;
          return diff <= _selectedTimeFilterDays!;
        } catch (_) {
          return false;
        }
      }).toList();
    }

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No contacts found for this time range.".tr())),
      );
      return;
    }

    if (_selectedFormat == 'XLSX') {
      Navigator.pop(context);
      ExportService.exportContactsToExcel(filtered, _selectedTimeFilterTitle ?? 'All Time'.tr()).catchError((e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export failed: \$e".tr())));
      });
    } else if (_selectedFormat == 'CSV') {
      Navigator.pop(context);
      ExportService.exportContactsToCsv(filtered, _selectedTimeFilterTitle ?? 'All Time'.tr()).catchError((e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export failed: \$e".tr())));
      });
    } else {
      // It's a CRM Push
      final crmType = CrmType.values.firstWhere((t) => t.id == _selectedFormat);
      
      // Check connection first
      final connectionsStatus = ref.read(crmConnectionsProvider);
      if (connectionsStatus[crmType] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please connect to \${crmType.name} in Settings first.")),
        );
        return;
      }
      
      // Start push
      ref.read(crmExportProvider.notifier).reset();
      
      // Trigger API in background and wait for result on screen
      await ref.read(crmExportProvider.notifier).pushContacts(crmType, filtered);
      
      final exportState = ref.read(crmExportProvider);
      
      if (exportState.status == CrmExportStatus.success) {
        _showSummaryBottomSheet(
          success: exportState.successCount,
          skipped: exportState.skipCount,
          failed: exportState.errorCount,
        );
      } else if (exportState.status == CrmExportStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Export failed: \${exportState.errorMessage}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showSummaryBottomSheet({required int success, required int skipped, required int failed}) {
    // Hide current bottom sheet
    Navigator.pop(context);
    
    // Show summary
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: EventzoneTheme.backgroundStart,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: EventzoneTheme.glassBorder),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Export Summary".tr(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (success > 0)
                    _buildSummaryRow(
                      icon: Icons.check_circle,
                      color: EventzoneTheme.accentSuccess,
                      text: "\$success contacts exported successfully",
                    ),
                  if (skipped > 0)
                    _buildSummaryRow(
                      icon: Icons.warning_amber_rounded,
                      color: EventzoneTheme.accentWarning,
                      text: "\$skipped duplicates skipped",
                    ),
                  if (failed > 0)
                    _buildSummaryRow(
                      icon: Icons.error_outline,
                      color: Colors.redAccent,
                      text: "\$failed failed",
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EventzoneTheme.cardColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text("Done".tr()),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildSummaryRow({required IconData icon, required Color color, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EventzoneTheme.backgroundStart,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 480, // Fixed height for page view transitions
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // Only manual navigation
            children: [
              _buildTimeFilterPage(),
              _buildFormatSelectionPage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeFilterPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "Export Contacts".tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildTimeFilterOption("All Time".tr(), null),
                _buildTimeFilterOption("Today".tr(), 1),
                _buildTimeFilterOption("Last 7 Days".tr(), 7),
                _buildTimeFilterOption("Last 15 Days".tr(), 15),
                _buildTimeFilterOption("Last 30 Days".tr(), 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterOption(String title, int? days) {
    return ListTile(
      leading: const Icon(LucideIcons.calendar, color: EventzoneTheme.primaryAction),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(LucideIcons.chevronRight, color: Colors.white54, size: 16),
      onTap: () => _goToFormatSelection(title, days),
    );
  }

  Widget _buildFormatSelectionPage() {
    final connectionsStatus = ref.watch(crmConnectionsProvider);
    final exportState = ref.watch(crmExportProvider);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: exportState.status == CrmExportStatus.pushing ? null : _goBack,
              ),
              Text(
                "Select Format".tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (exportState.status == CrmExportStatus.pushing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  LinearProgressIndicator(color: EventzoneTheme.primaryAction, backgroundColor: Colors.white10),
                  SizedBox(height: 8),
                  Text("Pushing contacts...", style: TextStyle(color: EventzoneTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            
          Expanded(
            child: ListView(
              children: [
                _buildFormatCard('XLSX', "Excel Spreadsheet", "XLSX", null),
                const SizedBox(height: 12),
                _buildFormatCard('CSV', "Plain CSV file", "CSV", null),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Text("CRM Integrations", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                ),
                for (var crm in CrmType.values) ...[
                  _buildFormatCard(
                    crm.id,
                    crm.name,
                    crm.id.substring(0, 2).toUpperCase(),
                    connectionsStatus[crm] == true,
                  ),
                  const SizedBox(height: 12),
                ]
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedFormat != null && exportState.status != CrmExportStatus.pushing
                  ? _handleExport
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: EventzoneTheme.primaryAction,
                disabledBackgroundColor: EventzoneTheme.cardColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "Export Now".tr(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatCard(String id, String name, String initials, bool? isConnected) {
    final isSelected = _selectedFormat == id;
    
    return GestureDetector(
      onTap: () {
        final exportState = ref.read(crmExportProvider);
        if (exportState.status == CrmExportStatus.pushing) return;
        
        setState(() {
          _selectedFormat = id;
        });
      },
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: EventzoneTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? EventzoneTheme.primaryAction : EventzoneTheme.glassBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            if (isConnected != null)
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? EventzoneTheme.accentSuccess : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isConnected ? "Connected" : "Not Connected",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }
}
