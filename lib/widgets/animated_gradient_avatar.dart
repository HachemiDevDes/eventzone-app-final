import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/eventzone_theme.dart';

class AnimatedGradientAvatar extends StatefulWidget {
  final ImageProvider? backgroundImage;
  final Widget? child;
  final double radius;
  final double strokeWidth;
  final Color? color;

  const AnimatedGradientAvatar({
    super.key,
    this.backgroundImage,
    this.child,
    this.radius = 20,
    this.strokeWidth = 2,
    this.color,
  });

  @override
  State<AnimatedGradientAvatar> createState() => _AnimatedGradientAvatarState();
}

class _AnimatedGradientAvatarState extends State<AnimatedGradientAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final gradientColor = widget.color ?? EventzoneTheme.primaryAction;
        return Container(
          padding: EdgeInsets.all(widget.strokeWidth),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                gradientColor.withValues(alpha: 0.1),
                gradientColor,
                gradientColor.withValues(alpha: 0.1),
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: GradientRotation(_controller.value * 2 * math.pi),
            ),
          ),
          child: CircleAvatar(
            radius: widget.radius,
            backgroundColor: EventzoneTheme.backgroundStart,
            child: CircleAvatar(
              radius: widget.radius - 1.5, // Slightly smaller to show an inner gap
              backgroundColor: Colors.white10,
              backgroundImage: widget.backgroundImage,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
