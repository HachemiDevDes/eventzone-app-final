import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'connection_providers.dart';

// --- SHAKE DETECTION ---

final shakeDetectionProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  final List<DateTime> shakeTimestamps = [];
  bool isDebouncing = false;

  final subscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
    if (isDebouncing) return;

    // "magnitude exceeds a threshold of 8 m/s² on any axis"
    if (event.x.abs() > 8 || event.y.abs() > 8 || event.z.abs() > 8) {
      final now = DateTime.now();
      shakeTimestamps.add(now);

      // Keep only timestamps within the last 1 second
      shakeTimestamps.removeWhere((t) => now.difference(t).inMilliseconds > 1000);

      // "Require the threshold to be exceeded 3 times within 1 second"
      if (shakeTimestamps.length >= 3) {
        shakeTimestamps.clear();
        isDebouncing = true;
        HapticFeedback.mediumImpact();
        controller.add(DateTime.now());

        // "Debounce for 5 seconds"
        Timer(const Duration(seconds: 5), () {
          isDebouncing = false;
        });
      }
    }
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

// --- SHAKE SESSION MANAGEMENT ---

enum ShakeStatus { idle, searching, matched, expired, error }

class ShakeSessionState {
  final ShakeStatus status;
  final Map<String, dynamic>? matchedUser;
  final String? errorMessage;
  final String? sessionId;

  ShakeSessionState({
    this.status = ShakeStatus.idle,
    this.matchedUser,
    this.errorMessage,
    this.sessionId,
  });

  ShakeSessionState copyWith({
    ShakeStatus? status,
    Map<String, dynamic>? matchedUser,
    String? errorMessage,
    String? sessionId,
  }) {
    return ShakeSessionState(
      status: status ?? this.status,
      matchedUser: matchedUser ?? this.matchedUser,
      errorMessage: errorMessage ?? this.errorMessage,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

class ShakeSessionNotifier extends AsyncNotifier<ShakeSessionState> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  Timer? _timeoutTimer;

  @override
  FutureOr<ShakeSessionState> build() {
    ref.onDispose(() {
      _cancelSession();
    });
    return ShakeSessionState();
  }

  Future<void> startSession(BuildContext context) async {
    // Only allow starting if idle or expired
    if (state.value?.status == ShakeStatus.searching) return;

    state = AsyncValue.data(ShakeSessionState(status: ShakeStatus.searching));
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      state = AsyncValue.data(ShakeSessionState(
        status: ShakeStatus.error,
        errorMessage: 'User not logged in.',
      ));
      return;
    }

    try {
      // 1. Location Permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = AsyncValue.data(ShakeSessionState(
            status: ShakeStatus.error, 
            errorMessage: "Location access is required to find nearby users."
          ));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = AsyncValue.data(ShakeSessionState(
          status: ShakeStatus.error, 
          errorMessage: "Location permission is permanently denied. Please enable it in your device settings."
        ));
        return;
      }

      // 2. Get Location with a 5 second timeout to prevent indefinite hangs
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      ).catchError((e) {
        throw Exception("Could not get your location. Make sure GPS is enabled and try again.");
      });

      // 3. Insert or update session (Duplicate prevention)
      final existing = await _supabase
          .from('shake_sessions')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'searching')
          .maybeSingle();

      String sessionId;
      if (existing != null) {
        sessionId = existing['id'] as String;
        await _supabase.from('shake_sessions').update({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', sessionId).eq('user_id', userId);
      } else {
        final response = await _supabase.from('shake_sessions').insert({
          'user_id': userId,
          'latitude': position.latitude,
          'longitude': position.longitude,
        }).select('id').single();
        sessionId = response['id'] as String;
      }

      state = AsyncValue.data(ShakeSessionState(status: ShakeStatus.searching, sessionId: sessionId));

      // 4. Try to find an immediate match (Haversine formula in query)
      final matchFound = await _tryFindMatch(userId, position.latitude, position.longitude, sessionId);
      
      if (matchFound) {
        return; // Handled in _tryFindMatch
      }

      // 5. If no immediate match, subscribe to realtime for updates to OUR row
      _channel = _supabase
          .channel('public:shake_sessions:id=eq.$sessionId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'shake_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: sessionId,
            ),
            callback: (payload) async {
              final newStatus = payload.newRecord['status'] as String?;
              if (newStatus == 'matched') {
                await _handleMatchFound(userId);
              }
            },
          )
          .subscribe();

      // 6. Set 10 second timeout
      _timeoutTimer = Timer(const Duration(seconds: 10), () {
        _handleTimeout(sessionId);
      });
    } catch (e) {
      state = AsyncValue.data(ShakeSessionState(
        status: ShakeStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<bool> _tryFindMatch(String currentUserId, double lat, double lng, String sessionId) async {
    try {
      // Raw SQL is not directly supported via postgrest for complex math, 
      // but we can fetch recent searching sessions and calculate locally since limit is small.
      // Fetch users who are searching in the last 10 seconds.
      final tenSecondsAgo = DateTime.now().toUtc().subtract(const Duration(seconds: 10)).toIso8601String();
      
      final candidates = await _supabase
          .from('shake_sessions')
          .select()
          .eq('status', 'searching')
          .gte('created_at', tenSecondsAgo)
          .neq('user_id', currentUserId);

      for (var row in (candidates as List)) {
        final otherLat = row['latitude'] as double;
        final otherLng = row['longitude'] as double;
        
        // Haversine calculation locally for ease, alternative to RPC
        final distance = Geolocator.distanceBetween(lat, lng, otherLat, otherLng);
        
        if (distance <= 50) {
          final targetUserId = row['user_id'] as String;
          
          // Check if already connected via SupabaseService
          final service = ref.read(supabaseServiceProvider);
          final status = await service.fetchConnectionStatus(targetUserId);
          
          if (status != 'accepted') {
            // Match found! Update both rows
            await _supabase.from('shake_sessions').update({'status': 'matched'}).inFilter('id', [sessionId, row['id']]);
            await _handleMatchFound(currentUserId, targetUserId: targetUserId);
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint("Error finding match: $e");
      return false;
    }
  }

  Future<void> _handleMatchFound(String currentUserId, {String? targetUserId}) async {
    _cancelTimerAndChannel();

    if (targetUserId == null) {
       // Target matched with us, let's find who it is (the other matched row within last 10s nearby)
       // This is a bit tricky if they just updated our status. 
       // The easiest way is to find the other user whose status is 'matched' and is recent.
       final tenSecondsAgo = DateTime.now().toUtc().subtract(const Duration(seconds: 12)).toIso8601String();
       final matches = await _supabase
           .from('shake_sessions')
           .select()
           .eq('status', 'matched')
           .gte('created_at', tenSecondsAgo)
           .neq('user_id', currentUserId)
           .order('created_at', ascending: false)
           .limit(1);
           
       if ((matches as List).isNotEmpty) {
         targetUserId = matches[0]['user_id'] as String;
       }
    }

    if (targetUserId != null) {
      // Fetch user profile
      final service = ref.read(supabaseServiceProvider);
      final profile = await service.fetchProfile(targetUserId);
      
      state = AsyncValue.data(ShakeSessionState(
        status: ShakeStatus.matched,
        matchedUser: profile,
        sessionId: state.value?.sessionId,
      ));
    } else {
      // Fallback
      state = AsyncValue.data(ShakeSessionState(status: ShakeStatus.expired));
    }
  }

  Future<void> _handleTimeout(String sessionId) async {
    _cancelTimerAndChannel();
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _supabase.from('shake_sessions').update({'status': 'expired'}).eq('id', sessionId).eq('user_id', userId);
      } catch (_) {}
    }
    
    state = AsyncValue.data(ShakeSessionState(status: ShakeStatus.expired));
  }

  void cancelSession() {
    final sessionId = state.value?.sessionId;
    final userId = _supabase.auth.currentUser?.id;
    if (sessionId != null && userId != null && state.value?.status == ShakeStatus.searching) {
      _supabase.from('shake_sessions').delete().eq('id', sessionId).eq('user_id', userId).then((_) {}).catchError((_) {});
    }
    _cancelSession();
    state = AsyncValue.data(ShakeSessionState(status: ShakeStatus.idle));
  }

  void forceReset() {
    final sessionId = state.value?.sessionId;
    final userId = _supabase.auth.currentUser?.id;
    if (sessionId != null && userId != null && state.value?.status == ShakeStatus.searching) {
      _supabase.from('shake_sessions').update({'status': 'expired'}).eq('id', sessionId).eq('user_id', userId).then((_) {}).catchError((_) {});
    }
    _cancelSession();
    state = AsyncValue.data(ShakeSessionState(status: ShakeStatus.idle));
  }

  void _cancelTimerAndChannel() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
      _channel = null;
    }
  }

  void _cancelSession() {
    _cancelTimerAndChannel();
  }
  
  void reset() {
    cancelSession();
  }

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

final shakeSessionProvider = AsyncNotifierProvider<ShakeSessionNotifier, ShakeSessionState>(() {
  return ShakeSessionNotifier();
});
