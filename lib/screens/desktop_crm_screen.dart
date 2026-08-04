import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';

class DesktopCrmScreen extends StatefulWidget {
  const DesktopCrmScreen({super.key});

  @override
  State<DesktopCrmScreen> createState() => _DesktopCrmScreenState();
}

class _DesktopCrmScreenState extends State<DesktopCrmScreen> {
  final _supabase = Supabase.instance.client;
  String? _token;
  bool _loading = true;
  bool _refreshing = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  /// Generates a random 8-char alphanumeric code like "X7K2-M9QR"
  String _generateToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous chars
    final rand = Random.secure();
    final part1 = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    final part2 = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return '$part1-$part2';
  }

  Future<void> _loadToken() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final res = await _supabase
          .from('profiles')
          .select('crm_token')
          .eq('id', userId)
          .single();

      if (res['crm_token'] != null && (res['crm_token'] as String).isNotEmpty) {
        setState(() => _token = res['crm_token']);
      } else {
        // First time — auto-generate one
        await _generateAndSave();
      }
    } catch (_) {
      await _generateAndSave();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateAndSave() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    String newToken;
    // Retry until unique (collision is astronomically rare but handle it)
    for (int i = 0; i < 5; i++) {
      newToken = _generateToken();
      try {
        await _supabase
            .from('profiles')
            .update({'crm_token': newToken})
            .eq('id', userId);
        setState(() => _token = newToken);
        return;
      } catch (_) {
        // Likely unique constraint violation — try again
        continue;
      }
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final messenger = ScaffoldMessenger.of(context);
    // Confirm refresh
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Refresh Login Code?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Your old code will stop working immediately. Any CRM session using the old code will be logged out.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refresh', style: TextStyle(color: Color(0xFF7c3aed), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _refreshing = true);
    await _generateAndSave();
    setState(() => _refreshing = false);

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Login code refreshed!'),
        backgroundColor: Color(0xFF22c55e),
      ),
    );
  }

  Future<void> _copyToClipboard() async {
    if (_token == null) return;
    await Clipboard.setData(ClipboardData(text: _token!));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EventzoneTheme.backgroundStart,
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Desktop CRM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),

                      // Monitor icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF7c3aed), const Color(0xFF4f46e5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7c3aed).withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(LucideIcons.monitor, color: Colors.white, size: 36),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Your Desktop Login Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Enter this code on the CRM web app to log in instantly — no password needed.',
                        style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),
                      
                      // CRM Link Section
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(LucideIcons.link, color: Colors.white70, size: 16),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'crm.eventzone.dz',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                await Clipboard.setData(const ClipboardData(text: 'https://crm.eventzone.dz'));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('CRM Link copied to clipboard!'),
                                      backgroundColor: Color(0xFF22c55e),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7c3aed).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF7c3aed).withValues(alpha: 0.3)),
                                ),
                                child: const Text(
                                  'Copy Link',
                                  style: TextStyle(
                                    color: Color(0xFFa78bfa),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Token display card
                      GlassContainer(
                        borderRadius: 24,
                        padding: const EdgeInsets.all(32),
                        child: _loading
                            ? const Center(
                                child: CircularProgressIndicator(color: Color(0xFF7c3aed)),
                              )
                            : Column(
                                children: [
                                  // The code
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFF7c3aed).withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      _token ?? '----',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 6,
                                        fontFamily: 'monospace',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Action buttons
                                  Row(
                                    children: [
                                      // Copy
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: _copyToClipboard,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            decoration: BoxDecoration(
                                              color: _copied
                                                  ? const Color(0xFF22c55e).withValues(alpha: 0.15)
                                                  : Colors.white.withValues(alpha: 0.06),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: _copied
                                                    ? const Color(0xFF22c55e).withValues(alpha: 0.4)
                                                    : Colors.white.withValues(alpha: 0.1),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _copied ? LucideIcons.check : LucideIcons.copy,
                                                  color: _copied ? const Color(0xFF22c55e) : Colors.white70,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _copied ? 'Copied!' : 'Copy',
                                                  style: TextStyle(
                                                    color: _copied ? const Color(0xFF22c55e) : Colors.white70,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // Refresh
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: _refreshing ? null : _refresh,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF7c3aed), Color(0xFF4f46e5)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                _refreshing
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child: CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                      )
                                                    : const Icon(LucideIcons.refreshCw, color: Colors.white, size: 18),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _refreshing ? 'Refreshing…' : 'Refresh',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),

                      const SizedBox(height: 32),

                      // Instructions
                      GlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'How to use',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildStep('1', 'Open the EventZone CRM on your desktop browser'),
                            _buildStep('2', 'Click "Login with Code" on the login page'),
                            _buildStep('3', 'Enter your code above and you\'re in!'),
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(LucideIcons.shieldCheck, color: Color(0xFF7c3aed), size: 16),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Your code is private. Refreshing it immediately invalidates the old one.',
                                    style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF7c3aed).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF9d5ff5),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
