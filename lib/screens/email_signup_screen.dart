import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../providers/auth_providers.dart';
import 'package:easy_localization/easy_localization.dart';

class EmailSignUpScreen extends ConsumerStatefulWidget {
  const EmailSignUpScreen({super.key});

  @override
  ConsumerState<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends ConsumerState<EmailSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _showVerificationMessage = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      
      // Attempt Sign Up
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'full_name': _nameController.text.trim(),
        },
      );

      if (response.user != null) {
        setState(() {
          _showVerificationMessage = true;
        });
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("An unexpected error occurred. Please try again.".tr()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Re-trigger sign up which resends confirmation in Supabase if unverified
      await ref.read(supabaseProvider).auth.resend(
        type: OtpType.signup,
        email: email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Verification email resent!".tr()),
            backgroundColor: EventzoneTheme.accentSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Resend failed: ${e.toString()}"),
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
    if (_showVerificationMessage) {
      return Scaffold(
        backgroundColor: EventzoneTheme.backgroundStart,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: GlassContainer(
                borderRadius: 24,
                padding: EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mark_email_unread_outlined,
                      size: 64,
                      color: EventzoneTheme.primaryAction,
                    ),
                    SizedBox(height: 24),
                    Text(
                      "Check your inbox to verify your email".tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "We've sent a verification link to ${_emailController.text.trim()}. Please click the link in the email to complete your registration.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        
                        fontSize: 14,
                        color: Colors.white60,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context.go('/welcome'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EventzoneTheme.primaryAction,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text("Back to Sign In".tr()),
                    ),
                    SizedBox(height: 16),
                    GestureDetector(
                      onTap: _isLoading ? null : _resendVerificationEmail,
                      child: Text(
                        "Didn't receive the email? Resend".tr(),
                        style: TextStyle(
                          color: EventzoneTheme.primaryAction,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: EventzoneTheme.backgroundStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 10),
              Text(
                "Create Account".tr(),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 32,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Register now to unlock event directory, networking, and meetings.".tr(),
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                  
                ),
              ),
              SizedBox(height: 24),

              Form(
                key: _formKey,
                child: GlassContainer(
                  borderRadius: 24,
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Full Name Field
                      Text(
                        "Full Name".tr(),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          
                        ),
                      ),
                      SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: Colors.white, fontSize: 14, ),
                        decoration: InputDecoration(
                          hintText: "John Doe".tr(),
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                          fillColor: Color(0xFF1A1E2E),
                          filled: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: EventzoneTheme.primaryAction, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Email Field
                      Text(
                        "Email Address".tr(),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          
                        ),
                      ),
                      SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        style: TextStyle(color: Colors.white, fontSize: 14, ),
                        decoration: InputDecoration(
                          hintText: "john@example.com".tr(),
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                          fillColor: Color(0xFF1A1E2E),
                          filled: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: EventzoneTheme.primaryAction, width: 2),
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
                      SizedBox(height: 16),

                      // Password Field
                      Text(
                        "Password".tr(),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          
                        ),
                      ),
                      SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: Colors.white, fontSize: 14, ),
                        decoration: InputDecoration(
                          hintText: "Min. 8 characters".tr(),
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                          fillColor: Color(0xFF1A1E2E),
                          filled: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: EventzoneTheme.primaryAction, width: 2),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          if (!RegExp(r'[0-9]').hasMatch(value)) {
                            return 'Password must contain at least 1 number';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Confirm Password Field
                      Text(
                        "Confirm Password".tr(),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          
                        ),
                      ),
                      SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: TextStyle(color: Colors.white, fontSize: 14, ),
                        decoration: InputDecoration(
                          hintText: "Re-enter password".tr(),
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                          fillColor: Color(0xFF1A1E2E),
                          filled: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: EventzoneTheme.primaryAction, width: 2),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 28),

                      // Create Account Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignUp,
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
                                "Create Account".tr(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Redirect to Sign In
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ".tr(),
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.pushReplacement('/signin'),
                    child: Text(
                      "Sign in".tr(),
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
