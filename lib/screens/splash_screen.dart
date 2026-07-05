import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import '../theme/eventzone_theme.dart';
import '../providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _particleController;

  // Icon animations
  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;

  // Glow ring animation
  late Animation<double> _glowScale;
  late Animation<double> _glowOpacity;

  // Wordmark animations
  late Animation<double> _wordmarkOpacity;
  late Animation<Offset> _wordmarkSlide;

  // Tagline animations
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;

  // Loading indicator
  late Animation<double> _loaderOpacity;

  // Continuous pulse
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    // Main sequenced animation — 2.5 seconds
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Continuous subtle pulse on the icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Particle/shimmer rotation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    // ── Animation Sequence ──

    // 0.0 → 0.3: Icon drops in with elastic scale + fade
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.35, curve: Curves.elasticOut),
      ),
    );
    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
      ),
    );

    // 0.1 → 0.4: Glow ring expands outward
    _glowScale = Tween<double>(begin: 0.5, end: 1.3).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.1, 0.45, curve: Curves.easeOutCubic),
      ),
    );
    _glowOpacity = Tween<double>(begin: 0.0, end: 0.6).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.1, 0.45, curve: Curves.easeOut),
      ),
    );

    // 0.35 → 0.6: Wordmark slides up + fades in
    _wordmarkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.6, curve: Curves.easeOut),
      ),
    );
    _wordmarkSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // 0.5 → 0.75: Tagline fades in
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 0.75, curve: Curves.easeOut),
      ),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    // 0.7 → 0.9: Loader dots appear
    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.7, 0.9, curve: Curves.easeOut),
      ),
    );

    // Pulse breathe
    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _mainController.forward();
    _pulseController.repeat(reverse: true);
    _particleController.repeat();
    _startTimer();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  bool _timerDone = false;

  Future<void> _startTimer() async {
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;
    _timerDone = true;
    _checkAndNavigate();
  }

  void _checkAndNavigate() {
    if (!_timerDone || !mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      context.go('/welcome');
      return;
    }

    final profileAsync = ref.read(currentUserProvider);
    if (profileAsync.isLoading) return;

    if (profileAsync.hasError) {
      context.go('/home');
    } else {
      final profile = profileAsync.value;
      if (profile == null || profile['onboarding_completed'] != true) {
        context.go('/onboarding');
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider, (_, __) {
      _checkAndNavigate();
    });

    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _pulseController, _particleController]),
        builder: (context, _) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A1628), // Deep navy
                  Color(0xFF060E1A), // Near black
                  Color(0xFF030812), // True dark
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // ── Ambient glow orbs ──
                Positioned(
                  top: size.height * 0.15,
                  left: size.width * 0.5 - 150,
                  child: _buildGlowOrb(
                    300,
                    EventzoneTheme.primaryAction.withValues(alpha: 0.12),
                  ),
                ),
                Positioned(
                  bottom: size.height * 0.2,
                  right: -80,
                  child: _buildGlowOrb(
                    250,
                    EventzoneTheme.accentSuccess.withValues(alpha: 0.06),
                  ),
                ),
                Positioned(
                  top: size.height * 0.6,
                  left: -60,
                  child: _buildGlowOrb(
                    200,
                    const Color(0xFF6366F1).withValues(alpha: 0.06),
                  ),
                ),

                // ── Rotating particle ring ──
                Positioned(
                  top: size.height * 0.5 - 120,
                  left: size.width * 0.5 - 120,
                  child: Transform.rotate(
                    angle: _particleController.value * 2 * math.pi,
                    child: Opacity(
                      opacity: _glowOpacity.value * 0.3,
                      child: CustomPaint(
                        size: const Size(240, 240),
                        painter: _OrbitDotsPainter(
                          progress: _particleController.value,
                          color: EventzoneTheme.primaryAction,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Main content ──
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glow ring behind icon
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow
                          Transform.scale(
                            scale: _glowScale.value,
                            child: Opacity(
                              opacity: _glowOpacity.value * 0.4,
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      EventzoneTheme.primaryAction.withValues(alpha: 0.3),
                                      EventzoneTheme.primaryAction.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Icon with pulse + scale
                          Transform.scale(
                            scale: _iconScale.value * _pulse.value,
                            child: Opacity(
                              opacity: _iconOpacity.value,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: EventzoneTheme.primaryAction.withValues(alpha: 0.3),
                                      blurRadius: 40,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Image.asset(
                                    "assets/icon/app_icon.png",
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 36),

                      // Wordmark
                      SlideTransition(
                        position: _wordmarkSlide,
                        child: Opacity(
                          opacity: _wordmarkOpacity.value,
                          child: Image.asset(
                            "assets/images/logo.png",
                            height: 32,
                            color: Colors.white,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tagline
                      SlideTransition(
                        position: _taglineSlide,
                        child: Opacity(
                          opacity: _taglineOpacity.value,
                          child: const Text(
                            "Your network, everywhere.",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Color(0x99FFFFFF),
                              letterSpacing: 0.5,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Loading shimmer dots
                      Opacity(
                        opacity: _loaderOpacity.value,
                        child: _buildLoadingDots(),
                      ),
                    ],
                  ),
                ),

                // ── Bottom branding ──
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: _loaderOpacity.value * 0.5,
                    child: const Text(
                      "by Eventzone",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0x55FFFFFF),
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlowOrb(double diameter, Color color) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }

  Widget _buildLoadingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            // Stagger the animation for each dot
            final delay = index * 0.15;
            final t = ((_pulseController.value + delay) % 1.0);
            final opacity = (math.sin(t * math.pi) * 0.7 + 0.3).clamp(0.0, 1.0);
            final scale = (math.sin(t * math.pi) * 0.3 + 0.7).clamp(0.0, 1.0);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: EventzoneTheme.primaryAction.withValues(alpha: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: EventzoneTheme.primaryAction.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Custom painter for the orbiting dots around the icon
class _OrbitDotsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _OrbitDotsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const dotCount = 12;

    for (int i = 0; i < dotCount; i++) {
      final angle = (i / dotCount) * 2 * math.pi + progress * 2 * math.pi;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      final opacity = ((math.sin(angle + progress * math.pi * 2) + 1) / 2 * 0.6 + 0.1);
      final dotRadius = 1.5 + (math.sin(angle + progress * math.pi) + 1) / 2 * 1.0;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitDotsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
