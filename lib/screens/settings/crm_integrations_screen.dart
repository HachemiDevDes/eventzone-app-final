import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/eventzone_theme.dart';
import '../../providers/crm_providers.dart';
import 'crm_setup_screen.dart';

class CrmIntegrationsScreen extends ConsumerWidget {
  const CrmIntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(crmConnectionsProvider);

    return Scaffold(
      backgroundColor: EventzoneTheme.backgroundStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "CRM Integrations",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: CrmType.values.length,
        itemBuilder: (context, index) {
          final crm = CrmType.values[index];
          final isConnected = connections[crm] == true;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildCrmCard(context, crm, isConnected),
          );
        },
      ),
    );
  }

  Widget _buildCrmCard(BuildContext context, CrmType crm, bool isConnected) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CrmSetupScreen(crmType: crm),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: EventzoneTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: EventzoneTheme.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                crm.id.substring(0, 2).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crm.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
