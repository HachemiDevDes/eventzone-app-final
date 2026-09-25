import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_model.dart';
import '../models/meeting_model.dart';
import '../models/floor_plan_model.dart';
import '../models/exhibitor_model.dart';
import '../models/sponsor_model.dart';
import '../services/supabase_service.dart';
import 'connection_providers.dart';

// FutureProvider for fetching sessions for an event
final sessionsProvider = FutureProvider.family<List<SessionModel>, String>((ref, eventId) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.fetchSessionsForEvent(eventId);
});

// StateNotifier for favorited session IDs
class SessionFavoritesNotifier extends StateNotifier<AsyncValue<List<String>>> {
  final SupabaseService _service;

  SessionFavoritesNotifier(this._service) : super(AsyncValue.loading()) {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    try {
      final list = await _service.fetchSessionFavorites();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> toggleFavorite(String sessionId) async {
    final currentList = state.value ?? [];
    final isFav = currentList.contains(sessionId);
    
    // Optimistic UI update
    final updatedList = isFav
        ? currentList.where((id) => id != sessionId).toList()
        : [...currentList, sessionId];
    
    state = AsyncValue.data(updatedList);

    final success = await _service.toggleSessionFavorite(sessionId, !isFav);
    if (!success) {
      // Revert if API call failed
      state = AsyncValue.data(currentList);
    }
    return success;
  }
}

final sessionFavoritesProvider = StateNotifierProvider<SessionFavoritesNotifier, AsyncValue<List<String>>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return SessionFavoritesNotifier(service);
});

// FutureProvider for connections count
final connectionsCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.fetchConnectionsCount();
});

// FutureProvider for next planned meeting
final nextMeetingProvider = FutureProvider<MeetingModel?>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.fetchNextMeeting();
});

// FutureProvider for fetching floor plans for an event
final eventFloorPlansProvider = FutureProvider.family<List<FloorPlanModel>, String>((ref, eventId) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.fetchEventFloorPlans(eventId);
});

// FutureProvider for fetching exhibitors for an event
final eventExhibitorsProvider = FutureProvider.family<List<ExhibitorModel>, String>((ref, eventId) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.fetchEventExhibitors(eventId);
});

// FutureProvider for fetching speakers for an event
final eventSpeakersProvider = FutureProvider.family<List<SessionSpeaker>, String>((ref, eventId) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.fetchEventSpeakers(eventId);
});

// FutureProvider for fetching sponsors for an event
final eventSponsorsProvider = FutureProvider.family<List<SponsorModel>, String>((ref, eventId) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.fetchEventSponsors(eventId);
});
