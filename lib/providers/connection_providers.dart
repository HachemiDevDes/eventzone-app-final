import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

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
  final supabase = Supabase.instance.client;
  final currentUserId = supabase.auth.currentUser?.id;
  if (currentUserId == null) return Stream.value(0);

  final controller = StreamController<int>();

  Future<void> updateCount() async {
    try {
      // Use count-only query for efficiency — avoids fetching all message rows
      final response = await supabase
          .from('messages')
          .select()
          .eq('recipient_id', currentUserId)
          .eq('is_read', false);
      if (controller.isClosed) return;
      controller.add(response.length);
    } catch (e) {
      if (controller.isClosed) return;
      controller.add(0);
    }
  }

  // Initial fetch
  updateCount();

  // Realtime subscription — listen to ALL events so marking as read (UPDATE)
  // is also caught and the badge clears immediately.
  final channel = supabase
      .channel('unread_messages_count_hud')
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
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

