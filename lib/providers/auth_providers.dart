import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Streams the auth state change and maps it to the current User?
final authStateProvider = StreamProvider<User?>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.onAuthStateChange.map((data) => data.session?.user);
});

// A notifier to fetch and manage the logged-in user's profile state
class CurrentUserNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  final _service = SupabaseService();

  @override
  FutureOr<Map<String, dynamic>?> build() async {
    ref.watch(authStateProvider);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final profile = await _service.fetchProfile(user.id);
    return profile;
  }

  Future<void> refresh() async {
    // Don't set loading state — that causes onboardingStatusProvider to
    // momentarily flip to false, which rebuilds GoRouter and forces
    // navigation back to /onboarding.
    final result = await AsyncValue.guard(() async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;
      return await _service.fetchProfile(user.id);
    });
    state = result;
  }

  void updateLocalProfile(Map<String, dynamic> updates) {
    state.whenData((currentProfile) {
      final Map<String, dynamic> newProfile = {
        ...?currentProfile,
        ...updates,
      };
      state = AsyncValue.data(newProfile);
    });
  }

  /// Updates the profile in the database and returns null on success,
  /// or an error message string on failure.
  /// Does NOT call refresh() — the caller is responsible for refreshing
  /// the provider state after navigation to avoid race conditions.
  Future<String?> updateProfileData({
    required String fullName,
    required String jobTitle,
    required String company,
    String? avatarUrl,
    String? bio,
    List<String>? industries,
    List<String>? interests,
    String? whatImLookingFor,
    Map<String, dynamic>? socialLinks,
    bool? onboardingCompleted,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return "No authenticated user found.";

    try {
      final updates = <String, dynamic>{
        'id': user.id,
        'full_name': fullName,
        'job_title': jobTitle,
        'company_name': company,
      };

      if (user.email != null) {
        updates['email'] = user.email;
      }

      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (bio != null) updates['bio'] = bio;
      if (industries != null) updates['industries'] = industries;
      if (interests != null) updates['interests'] = interests;
      if (whatImLookingFor != null) updates['what_im_looking_for'] = whatImLookingFor;
      if (onboardingCompleted != null) updates['onboarding_completed'] = onboardingCompleted;

      await ref.read(supabaseProvider)
          .from('profiles')
          .upsert(updates);

      return null;
    } on PostgrestException catch (e) {
      debugPrint('Profile save error: ${e.message} | code: ${e.code}');
      return 'Failed to save profile. Please try again.';
    } catch (e) {
      debugPrint('Generic profile save error: $e');
      return 'Failed to save profile. Please try again.';
    }
  }
}

final currentUserProvider = AsyncNotifierProvider<CurrentUserNotifier, Map<String, dynamic>?>(() {
  return CurrentUserNotifier();
});

// A provider that returns the onboarding status
final onboardingStatusProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(currentUserProvider);
  
  // Prevent kicking existing users to onboarding if there is a network error
  if (profileAsync.hasError) {
    return true; 
  }
  
  return profileAsync.maybeWhen(
    data: (profile) => profile != null && profile['onboarding_completed'] == true,
    orElse: () => false,
  );
});

class SubscriptionStatus {
  final bool isActive;
  final int daysRemaining;
  final bool isTrial;

  SubscriptionStatus({
    required this.isActive,
    required this.daysRemaining,
    required this.isTrial,
  });
}

// A provider that streams the user's subscription and trial status
final subscriptionStatusProvider = StreamProvider<SubscriptionStatus>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) {
    return Stream.value(SubscriptionStatus(isActive: false, daysRemaining: 0, isTrial: false));
  }

  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .map((event) {
        if (event.isNotEmpty) {
          final profile = event.first;
          final createdAtStr = profile['created_at'];
          final subEndDateStr = profile['subscription_end_date'];
          
          final now = DateTime.now();
          
          // Check Subscription
          if (subEndDateStr != null) {
            final subEndDate = DateTime.parse(subEndDateStr);
            if (subEndDate.isAfter(now)) {
              return SubscriptionStatus(
                isActive: true,
                daysRemaining: subEndDate.difference(now).inDays,
                isTrial: false,
              );
            }
          }

          // Check Trial (15 days from created_at)
          if (createdAtStr != null) {
            final createdAt = DateTime.parse(createdAtStr);
            final trialEndDate = createdAt.add(const Duration(days: 15));
            if (trialEndDate.isAfter(now)) {
              return SubscriptionStatus(
                isActive: true,
                daysRemaining: trialEndDate.difference(now).inDays,
                isTrial: true,
              );
            }
          }
        }
        
        return SubscriptionStatus(isActive: false, daysRemaining: 0, isTrial: false);
      })
      .handleError((e) {
        debugPrint('Error streaming subscription status: $e');
      });
});
