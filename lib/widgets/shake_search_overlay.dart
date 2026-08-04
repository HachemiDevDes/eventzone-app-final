import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../providers/shake_providers.dart';
import '../providers/connection_providers.dart';
import '../theme/eventzone_theme.dart';
import 'glass_container.dart';

class ShakeSearchOverlay extends ConsumerStatefulWidget {
  const ShakeSearchOverlay({super.key});

  @override
  ConsumerState<ShakeSearchOverlay> createState() => _ShakeSearchOverlayState();
}

class _ShakeSearchOverlayState extends ConsumerState<ShakeSearchOverlay> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _countdownController;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownController.dispose();
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _handleCancel() {
    ref.read(shakeSessionProvider.notifier).cancelSession();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final sessionStateAsync = ref.watch(shakeSessionProvider);

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85),
      body: sessionStateAsync.when(
        data: (state) {
          if (state.status == ShakeStatus.idle) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop();
            });
            return const SizedBox.shrink();
          } else if (state.status == ShakeStatus.expired) {
            _autoDismissTimer ??= Timer(const Duration(seconds: 4), () {
              if (mounted) {
                Navigator.of(context).pop();
                ref.read(shakeSessionProvider.notifier).reset();
              }
            });
            return _buildTimeoutUI(context);
          } else if (state.status == ShakeStatus.matched && state.matchedUser != null) {
            _pulseController.stop();
            return _buildMatchedUI(context, state.matchedUser!);
          } else if (state.status == ShakeStatus.error) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.alertCircle, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(state.errorMessage ?? "An error occurred".tr(), style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      ref.read(shakeSessionProvider.notifier).forceReset();
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: Text("Close".tr(), style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          } else if (state.status == ShakeStatus.searching) {
            return _buildSearchingUI(context);
          }

          // Fallback / default case for any unexpected state
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertTriangle, color: Colors.orange, size: 48),
                const SizedBox(height: 16),
                Text("An unexpected state occurred".tr(), style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    ref.read(shakeSessionProvider.notifier).forceReset();
                    if (mounted) Navigator.of(context).pop();
                  },
                  child: Text("Close".tr(), style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    ).animate().fade(duration: 300.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), duration: 300.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildSearchingUI(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 200,
                width: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Radar pulse
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: List.generate(3, (index) {
                            final delay = index * 0.33;
                            var value = _pulseController.value - delay;
                            if (value < 0) value += 1.0;
                            
                            final size = 50 + (150 * value);
                            final opacity = (1.0 - value).clamp(0.0, 1.0);
                            
                            return Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: EventzoneTheme.primaryAction.withOpacity(opacity),
                                  width: 2,
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                    const Icon(LucideIcons.smartphone, color: EventzoneTheme.primaryAction, size: 40),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Looking for nearby professionals…".tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 32),
              // Countdown arc
              SizedBox(
                height: 60,
                width: 60,
                child: AnimatedBuilder(
                  animation: _countdownController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _CountdownPainter(
                        progress: 1.0 - _countdownController.value,
                        color: EventzoneTheme.primaryAction,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: TextButton(
              onPressed: _handleCancel,
              child: Text("Cancel".tr(), style: const TextStyle(color: Colors.white54)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeoutUI(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 200,
            width: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.withOpacity(0.3), width: 2),
                  ),
                ),
                const Icon(Icons.phonelink_erase, color: Colors.grey, size: 40),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No one nearby shook their phone at the same time.".tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              _autoDismissTimer?.cancel();
              _autoDismissTimer = null;
              ref.read(shakeSessionProvider.notifier).startSession(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EventzoneTheme.primaryAction,
              minimumSize: const Size(200, 48),
            ),
            child: Text("Try Again".tr(), style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(shakeSessionProvider.notifier).reset();
              // Navigate to QR scanner
              context.go('/scan_qr'); // Assuming this route exists, otherwise just pop
            },
            child: Text("Scan QR Instead".tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ).animate().fade(),
    );
  }

  Widget _buildMatchedUI(BuildContext context, Map<String, dynamic> user) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.checkCircle2, color: EventzoneTheme.primaryAction, size: 80)
                  .animate()
                  .scale(duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text(
                "Match Found!".tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ).animate().fade(delay: 200.ms),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty
                      ? NetworkImage(user['avatar_url'])
                      : null,
                  child: user['avatar_url'] == null || user['avatar_url'].toString().isEmpty
                      ? const Icon(LucideIcons.user, size: 40, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  user['full_name'] ?? 'Attendee',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  [user['job_title'], user['company_name']].where((e) => e != null && e.toString().isNotEmpty).join(' @ '),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                if (user['industries'] != null && (user['industries'] as List).isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: (user['industries'] as List).take(3).map((ind) => Chip(
                      label: Text(ind.toString(), style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.white10,
                      side: BorderSide.none,
                    )).toList(),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    // Trigger connection
                    final service = ref.read(supabaseServiceProvider);
                    final success = await service.connectDirectly(user['id']);
                    if (mounted) {
                      if (success) {
                        ref.invalidate(connectionStatusProvider(user['id']));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connected with ${user['full_name']}!")));
                        Navigator.of(context).pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to connect.".tr())));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EventzoneTheme.primaryAction,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Send Connection Request".tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _handleCancel,
                  child: Text("Dismiss".tr(), style: const TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ).animate().slideY(begin: 1.0, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
        ),
      ],
    );
  }
}

class _CountdownPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CountdownPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Start at top (-pi/2), sweep based on progress (2 * pi * progress)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -pi/2
      6.2832 * progress, // 2*pi * progress
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
