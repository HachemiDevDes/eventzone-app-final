import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../providers/auth_providers.dart';
import '../services/supabase_service.dart';
import 'package:easy_localization/easy_localization.dart';

class EmailSignInScreen extends ConsumerStatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  ConsumerState<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends ConsumerState<EmailSignInScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _codeSent = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _resendCountdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.auth.signInWithOtp(
        email: _emailController.text.trim(),
        emailRedirectTo: 'eventzone://login-callback',
        shouldCreateUser: true, // Automatically registers them if it's their first time
      );

      setState(() {
        _codeSent = true;
      });
      _startCountdown();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Magic sign-in link sent to your email!".tr()),
            backgroundColor: EventzoneTheme.accentSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send magic link. Please check your connection.".tr()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter a valid 6-digit verification code.".tr()),
          backgroundColor: Colors.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: code,
        type: OtpType.email,
      );

      if (response.user != null) {
        // Fetch profile to verify onboarding status
        final profile = await SupabaseService().fetchProfile(response.user!.id);
        if (!mounted) return;

        if (profile == null || profile['onboarding_completed'] != true) {
          context.go('/onboarding');
        } else {
          context.go('/home');
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Verification failed. Please try again.".tr()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            if (_codeSent) {
              setState(() {
                _codeSent = false;
                _codeController.clear();
              });
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 20),
              Text(
                _codeSent ? "Enter Code".tr() : "Sign In with Email".tr(),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 32,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _codeSent
                    ? "Enter the 6-digit code sent to your email address.".tr()
                    : "No password needed. We'll send you a secure OTP verification code.".tr(),
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 32),

              Form(
                key: _formKey,
                child: GlassContainer(
                  borderRadius: 24,
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Step 1: Email Address
                      Text(
                        "Email Address".tr(),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_codeSent,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          color: _codeSent ? Colors.white38 : Colors.white,
                          
                        ),
                        decoration: InputDecoration(
                          hintText: "you@example.com".tr(),
                          hintStyle: TextStyle(color: Colors.white24),
                          fillColor: Color(0xFF1A1E2E),
                          filled: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: EventzoneTheme.primaryAction, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!emailRegExp.hasMatch(value.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),

                      // Step 2: OTP Verification Code (Only visible after sending)
                      if (_codeSent) ...[
                        Text(
                          "Verification Code".tr(),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                          ),
                          decoration: InputDecoration(
                            counterText: "",
                            hintText: "000000".tr(),
                            hintStyle: TextStyle(color: Colors.white12, letterSpacing: 8),
                            fillColor: Color(0xFF1A1E2E),
                            filled: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: EventzoneTheme.primaryAction, width: 2),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                      ],

                      // CTA Button
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : (_codeSent ? _verifyOtp : _sendOtp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EventzoneTheme.primaryAction,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          disabledBackgroundColor: EventzoneTheme.primaryAction.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _codeSent ? "Verify & Sign In" : "Send Verification Code",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                      ),

                      // Countdown / Resend Option
                      if (_codeSent) ...[
                        SizedBox(height: 20),
                        Center(
                          child: _resendCountdown > 0
                              ? Text(
                                  "Resend code in ${_resendCountdown}s",
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 13,
                                  ),
                                )
                              : GestureDetector(
                                  onTap: _isLoading ? null : _sendOtp,
                                  child: Text(
                                    "Resend Code".tr(),
                                    style: TextStyle(
                                      color: EventzoneTheme.primaryAction,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Redirect back to Welcome Screen options
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Want to try another way? ".tr(),
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      "Go back".tr(),
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
      ),
    );
  }
}
