import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/eventzone_theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final double blur;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding,
    this.width,
    this.height,
    this.showBorder = true,
    this.borderColor,
    this.borderWidth = 1.0,
    this.backgroundColor,
    this.boxShadow,
    this.blur = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = backgroundColor ?? EventzoneTheme.glassBackground;
    final bool needsBlur = blur > 0 && (backgroundColor == null || effectiveColor.a < 1.0);

    Widget inner = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(
                color: borderColor ?? EventzoneTheme.glassBorder,
                width: borderWidth,
              )
            : null,
        gradient: backgroundColor != null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.white.withValues(alpha: 0.01),
                ],
              ),
      ),
      child: child,
    );

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: needsBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: inner,
            )
          : inner,
    );

    if (boxShadow != null && boxShadow!.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: boxShadow,
        ),
        child: content,
      );
    }

    return content;
  }
}
