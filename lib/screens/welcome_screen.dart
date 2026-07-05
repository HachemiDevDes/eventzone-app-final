import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../providers/auth_providers.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      
      // Native Google Sign-In flow
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User cancelled
      }
      
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      
      if (idToken == null) {
        throw 'No ID Token found';
      }
      
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      debugPrint("Native Google Sign-In failed, falling back to OAuth: $e");
      try {
        await ref.read(supabaseProvider).auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'eventzone://login-callback',
        );
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Google sign-in failed. Please try again."),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EventzoneTheme.backgroundStart,
      body: Stack(
        children: [
          // Background Gradient Animation
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      0.5 * (1 - _animController.value),
                      -0.5 * (1 - _animController.value),
                    ),
                    radius: 1.5,
                    colors: const [
                      Color(0xFF0F1B35),
                      Color(0xFF0B0F19),
                      Color(0xFF06080F),
                    ],
                  ),
                ),
              );
            },
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top half: Logo & Header
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Eventzone Premium Logo
                          Image.asset(
                            "assets/images/logo.png",
                            height: 32, // Optimal premium size
                            color: Colors.white,
                            colorBlendMode: BlendMode.srcIn,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Where professionals connect",
                            style: TextStyle(
                              
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              color: Colors.white60,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom half: Onboarding Card
                  GlassContainer(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Your professional network starts here",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Connect with the right people at every event",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            color: Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Google Sign-In Button
                        _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: EventzoneTheme.primaryAction,
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: _handleGoogleSignIn,
                                icon: Image.network(
                                  'https://developers.google.com/identity/images/g-logo.png',
                                  height: 20,
                                  width: 20,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.black, size: 30),
                                ),
                                label: const Text(
                                  "Continue with Google",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 16),

                        // OR Divider
                        Row(
                          children: const [
                            Expanded(child: Divider(color: Colors.white12)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                "or",
                                style: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 14,
                                  
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.white12)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Email Sign-In Button
                        ElevatedButton(
                          onPressed: () => context.push('/signin'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EventzoneTheme.primaryAction,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            "Sign in with Email",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Sign Up Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                                
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push('/signin'),
                              child: const Text(
                                "Sign up",
                                style: TextStyle(
                                  color: EventzoneTheme.primaryAction,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
