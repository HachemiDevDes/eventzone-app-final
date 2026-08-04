import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final bool isLive;

  const StatusPill({
    super.key,
    required this.label,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget pill = Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isLive 
            ? Color(0xFFE11D48) // Red color for live
            : Color(0xFF1E293B), // Solid slate grey
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLive ? Color(0xFFFDA4AF) : Colors.white54,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive)
            Container(
              width: 6,
              height: 6,
              margin: EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .fade(begin: 0.3, end: 1.0, duration: 800.ms),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );

    if (isLive) {
      return pill.animate(onPlay: (controller) => controller.repeat(reverse: true))
                 .scaleXY(end: 1.03, duration: 1200.ms, curve: Curves.easeInOut);
    }

    return pill;
  }
}
