import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/eventzone_theme.dart';
import 'glass_container.dart';

class QRActionSheet extends StatelessWidget {
  const QRActionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 32,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 32),
          Text(
            "Quick Connect".tr(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
          ),
          SizedBox(height: 8),
          Text(
            "Share your profile or scan a colleague".tr(),
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  context,
                  LucideIcons.qrCode,
                  "My QR Code",
                  "Show to others",
                  EventzoneTheme.primaryAction,
                  "my_qr",
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  context,
                  LucideIcons.scan,
                  "Scan QR",
                  "Connect directly",
                  EventzoneTheme.accentSuccess,
                  "scan",
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    String action,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context, action); // Close bottom sheet and return action
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(height: 16),
            Text(
              title.tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle.tr(),
              style: TextStyle(
                fontSize: 11,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
