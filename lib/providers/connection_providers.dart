import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/connection_request_model.dart';
import 'auth_providers.dart';

final supabaseServiceProvider = Provider((ref) => SupabaseService());

// A provider that keeps track of connection statuses for various user IDs
class ConnectionStatusesNotifier extends StateNotifier<Map<String, String>> {
  final SupabaseService _service;

  ConnectionStatusesNotifier(this._service) : super({});

  Future<String> getStatus(String targetUserId) async {
    final status = await _service.fetchConnectionStatus(targetUserId);
    state = {...state, targetUserId: status};
    return status;
  }

  void setStatus(String targetUserId, String status) {
    state = {...state, targetUserId: status};
  }

  Future<void> refreshStatus(String targetUserId) async {
    final status = await _service.fetchConnectionStatus(targetUserId);
    state = {...state, targetUserId: status};
  }
}

final connectionStatusesProvider = StateNotifierProvider<ConnectionStatusesNotifier, Map<String, String>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return ConnectionStatusesNotifier(service);
});

final connectionStatusProvider = FutureProvider.family<String, String>((ref, targetUserId) async {
  final notifier = ref.watch(connectionStatusesProvider.notifier);
  // Watch state changes to trigger rebuilds when state map changes
  ref.watch(connectionStatusesProvider);
  return await notifier.getStatus(targetUserId);
});

// Realtime StreamProvider to count unread messages for the current user.
// Listens to ALL postgres change events (INSERT, UPDATE, DELETE) so it
// correctly decrements when messages are marked as read (UPDATE is_read=true).
final unreadMessagesCountProvider = StreamProvider<int>((ref) {
  ref.watch(authStateProvider);
  final supabase = Supabase.instance.client;
  final currentUserId = supabase.auth.currentUser?.id;
  if (currentUserId == null) return Stream.value(0);

  final controller = StreamController<int>();

  Future<void> updateCount() async {
    try {
      final response = await supabase
          .from('messages')
          .select('id')
          .eq('recipient_id', currentUserId)
          .or('is_read.eq.false,is_read.is.null');
      if (controller.isClosed) return;
      controller.add(response.length);
    } catch (e) {
      if (controller.isClosed) return;
      controller.add(0);
    }
  }

  // Initial fetch
  updateCount();

  // Periodic fallback timer (every 30s)
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => updateCount());

  // Realtime subscription — listen to ALL events so marking as read (UPDATE)
  // is also caught and the badge clears immediately.
  final channelName = 'unread_messages_count_${currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
  final channel = supabase
      .channel(channelName)
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          updateCount();
        },
      )
      .subscribe();

  ref.onDispose(() {
    timer.cancel();
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

// 📥 Incoming connection requests for current user
final incomingConnectionRequestsProvider = FutureProvider.autoDispose<List<ConnectionRequestModel>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.fetchIncomingConnectionRequests();
});

// 📤 Sent connection requests by current user
final sentConnectionRequestsProvider = FutureProvider.autoDispose<List<ConnectionRequestModel>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.fetchSentConnectionRequests();
});

// 🔔 Realtime count of incoming pending connection requests
final incomingRequestsCountProvider = StreamProvider<int>((ref) {
  ref.watch(authStateProvider);
  final supabase = Supabase.instance.client;
  final currentUserId = supabase.auth.currentUser?.id;
  if (currentUserId == null) return Stream.value(0);

  final controller = StreamController<int>();

  Future<void> updateCount() async {
    try {
      final response = await supabase
          .from('connections')
          .select('id')
          .or('connected_user_id.eq.$currentUserId,linked_profile_id.eq.$currentUserId')
          .neq('user_id', currentUserId)
          .eq('status', 'pending');
      if (controller.isClosed) return;
      controller.add(response.length);
    } catch (e) {
      if (controller.isClosed) return;
      controller.add(0);
    }
  }

  // Initial fetch
  updateCount();

  // Periodic fallback timer (every 15s)
  final timer = Timer.periodic(const Duration(seconds: 15), (_) => updateCount());

  // Realtime subscription to connections table changes
  final channelName = 'incoming_requests_count_${currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
  final channel = supabase
      .channel(channelName)
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'connections',
        callback: (payload) {
          updateCount();
        },
      )
      .subscribe();

  ref.onDispose(() {
    timer.cancel();
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

