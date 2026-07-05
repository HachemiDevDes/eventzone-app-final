import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meeting_model.dart';
import '../services/supabase_service.dart';

class BookedSlotsParam {
  final String userId;
  final String date;

  BookedSlotsParam({required this.userId, required this.date});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookedSlotsParam &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          date == other.date;

  @override
  int get hashCode => userId.hashCode ^ date.hashCode;
}

// 📅 Riverpod stream provider for all meetings of a user
final meetingsProvider = StreamProvider.family<List<MeetingModel>, String>((ref, userId) {
  final supabaseService = SupabaseService();
  return supabaseService.streamMeetings(userId);
});

// 📅 Riverpod future provider for booked time slots of a user on a given date
final bookedSlotsProvider = FutureProvider.family<List<Map<String, String>>, BookedSlotsParam>((ref, param) {
  final supabaseService = SupabaseService();
  return supabaseService.fetchBookedSlots(param.userId, param.date);
});

// 📅 Riverpod stream provider for a specific meeting's status updates
final meetingStatusProvider = StreamProvider.family<String, String>((ref, meetingId) {
  final supabaseService = SupabaseService();
  return supabaseService.streamMeetingStatus(meetingId);
});
