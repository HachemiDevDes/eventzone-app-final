import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import '../models/connection_request_model.dart';
import '../models/meeting_model.dart';
import '../models/session_model.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // 📅 Fetch all events from the 'events' table
  Future<List<EventModel>> fetchEvents() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return [];
      
      final registrationsResponse = await _supabase
          .from('event_registrations')
          .select('event_id')
          .eq('profile_id', currentUserId);
      
      final registeredEventIds = (registrationsResponse as List)
          .map((reg) => reg['event_id'] as String)
          .toSet();

      final response = await _supabase
          .from('events')
          .select()
          .order('created_at', ascending: false);
      
      return (response as List).map((data) {
        final id = data['id'] as String;
        final isJoined = registeredEventIds.contains(id);
        return EventModel(
          id: id,
          title: data['name'] ?? 'Untitled Event',
          date: data['start_date'] ?? data['date'] ?? 'TBA',
          location: data['location'] ?? 'Online',
          category: data['type'] ?? 'EVENT',
          imageUrl: data['banner'] ?? data['cover_url'] ?? 'https://images.unsplash.com/photo-1540575861501-7cf05a4b125a?w=800&q=80',
          description: data['description'] ?? '',
          stats: data['capacity'] != null ? '${data['capacity']} Capacity' : null,
          startDate: data['start_date'] ?? 'TBA',
          endDate: data['end_date'] ?? data['start_date'] ?? 'TBA',
          isJoined: isJoined,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching events: $e');
      return [];
    }
  }

  // 📝 Register for an event
  Future<bool> registerForEvent(String eventId, String profileId) async {
    try {
      await _supabase.from('event_registrations').insert({
        'event_id': eventId,
        'profile_id': profileId,
      });
      return true;
    } catch (e) {
      debugPrint('Error registering: $e');
      return false;
    }
  }

  // 🤝 Connect with another attendee via QR
  Future<void> connectWithUser(String currentUserId, String targetUserId) async {
    try {
      await _supabase.from('connections').upsert({
        'user_id': currentUserId,
        'connected_user_id': targetUserId,
        'status': 'connected',
      });
    } catch (e) {
      debugPrint('Error connecting: $e');
    }
  }

  // 👤 Fetch a user profile
  Future<Map<String, dynamic>?> fetchProfile(String profileId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', profileId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      throw e; // Rethrow to let providers handle the error state
    }
  }

  // 👤 Update a user profile
  Future<String?> updateProfile(
    String profileId, {
    required String fullName,
    required String jobTitle,
    required String companyName,
    String? avatarUrl,
    String? address,
    String? bio,
    String? whatImLookingFor,
    List<String>? industries,
    List<String>? interests,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Build metadata including top-level socials shortcuts
      final Map<String, dynamic> finalMetadata = Map<String, dynamic>.from(metadata ?? {});

      if (finalMetadata['socials'] != null) {
        final socials = finalMetadata['socials'] as List;
        for (var item in socials) {
          if (item is Map<String, dynamic> || item is Map) {
            final platform = (item['platform'] as String?)?.toLowerCase().replaceAll(' ', '_');
            final value = (item['value'] as String?)?.trim() ?? '';
            if (platform != null && value.isNotEmpty) {
              // Populate metadata shortcuts for quick access
              if (platform == 'email') {
                finalMetadata['email'] = value;
              } else if (platform == 'phone' || platform == 'phone_number') {
                finalMetadata['phone'] = value;
              } else if (platform == 'website' || platform == 'company_website') {
                finalMetadata['website'] = value;
              }
            }
          }
        }
      }

      final updates = <String, dynamic>{
        'full_name': fullName,
        'job_title': jobTitle,
        'company_name': companyName,
        'avatar_url': avatarUrl,
        'address': address,
        'metadata': finalMetadata,
      };

      if (bio != null) updates['bio'] = bio;
      if (whatImLookingFor != null) updates['what_im_looking_for'] = whatImLookingFor;
      if (industries != null) updates['industries'] = industries;
      if (interests != null) updates['interests'] = interests;

      await _supabase.from('profiles').update(updates).eq('id', profileId);

      return null;
    } on PostgrestException catch (e) {
      debugPrint('Profile save error: ${e.message} | code: ${e.code}');
      return 'Failed to save profile. Please try again.';
    } catch (e) {
      debugPrint('Generic profile save error: $e');
      return 'Failed to save profile. Please try again.';
    }
  }

  // 🤝 Fetch connections/leads
  Future<List<Map<String, dynamic>>> fetchConnections(String userId) async {
    try {
      final response = await _supabase
          .from('connections')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching connections: $e');
      return [];
    }
  }

  // 🔥 Calculate daily connection streak
  Future<int> calculateDailyStreak(String userId) async {
    try {
      final response = await _supabase
          .from('connections')
          .select('created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List data = response as List;
      if (data.isEmpty) return 0;

      // Extract unique dates (ignoring time)
      final Set<String> uniqueDatesStr = {};
      for (var row in data) {
        if (row['created_at'] != null) {
          final date = DateTime.parse(row['created_at']).toLocal();
          uniqueDatesStr.add("${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}");
        }
      }

      if (uniqueDatesStr.isEmpty) return 0;

      final List<DateTime> sortedDates = uniqueDatesStr.map((e) => DateTime.parse(e)).toList();
      sortedDates.sort((a, b) => b.compareTo(a));

      final today = DateTime.now();
      final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final todayDate = DateTime.parse(todayStr);

      final yesterdayDate = todayDate.subtract(const Duration(days: 1));

      // If the most recent date is not today or yesterday, the streak is 0.
      if (sortedDates.first.isBefore(yesterdayDate)) {
        return 0;
      }

      int streak = 0;
      DateTime currentDateToCheck = sortedDates.first == todayDate ? todayDate : yesterdayDate;

      for (var date in sortedDates) {
        if (date.isAtSameMomentAs(currentDateToCheck)) {
          streak++;
          currentDateToCheck = currentDateToCheck.subtract(const Duration(days: 1));
        } else if (date.isBefore(currentDateToCheck)) {
          // A gap in the streak was found
          break;
        }
      }

      return streak;
    } catch (e) {
      debugPrint('Error calculating streak: $e');
      return 0;
    }
  }

  // 💳 Check if the user has an active subscription
  Future<bool> hasActiveSubscription(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('subscription_end_date')
          .eq('id', userId)
          .single();
      
      final endDateStr = response['subscription_end_date'] as String?;
      if (endDateStr == null) return false;

      final endDate = DateTime.parse(endDateStr);
      return endDate.isAfter(DateTime.now());
    } catch (e) {
      debugPrint('Error checking subscription: $e');
      return false;
    }
  }

  // 💾 Save connection/lead
  Future<bool> saveConnection(Map<String, dynamic> connectionData) async {
    try {
      await _supabase.from('connections').insert(connectionData);
      return true;
    } catch (e) {
      debugPrint('Error saving connection: $e');
      return false;
    }
  }

  // ❌ Delete connection/lead
  Future<bool> deleteConnection(String connectionId) async {
    try {
      await _supabase.from('connections').delete().eq('id', connectionId);
      return true;
    } catch (e) {
      debugPrint('Error deleting connection: $e');
      return false;
    }
  }

  // 🤝 Connect directly (bypasses requests)
  Future<bool> connectDirectly(String targetUserId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return false;

      // Check active subscription first!
      final hasSub = await hasActiveSubscription(currentUserId);
      if (!hasSub) {
        return false;
      }

      // Check if already connected
      final existingConn = await _supabase
          .from('connections')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('linked_profile_id', targetUserId)
          .maybeSingle();

      if (existingConn != null) return true;

      // 1. Fetch sender profile
      final senderProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', currentUserId)
          .maybeSingle();

      // 2. Fetch receiver profile
      final receiverProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', targetUserId)
          .maybeSingle();

      if (senderProfile != null && receiverProfile != null) {
        final senderMeta = senderProfile['metadata'] as Map<String, dynamic>? ?? {};
        final receiverMeta = receiverProfile['metadata'] as Map<String, dynamic>? ?? {};

        // Insert receiver into sender's connections
        try {
          await _supabase.from('connections').insert({
            'user_id': currentUserId,
            'name': receiverProfile['full_name'] ?? 'Attendee',
            'title': receiverProfile['job_title'] ?? '',
            'avatar_url': receiverProfile['avatar_url'] ?? '',
            'company': receiverProfile['company_name'] ?? '',
            'email': receiverProfile['email'] ?? receiverMeta['email'] ?? '',
            'phone': receiverProfile['phone'] ?? receiverMeta['phone'] ?? '',
            'website': receiverProfile['website'] ?? receiverMeta['website'] ?? '',
            'address': receiverProfile['address'] ?? receiverMeta['address'] ?? '',
            'tags': receiverProfile['interests'] ?? [],
            'source': 'B2B Connection',
            'is_new': true,
            'linked_profile_id': targetUserId,
          });
        } catch (_) {}

        // Insert sender into receiver's connections
        try {
          await _supabase.from('connections').insert({
            'user_id': targetUserId,
            'name': senderProfile['full_name'] ?? 'Attendee',
            'title': senderProfile['job_title'] ?? '',
            'avatar_url': senderProfile['avatar_url'] ?? '',
            'company': senderProfile['company_name'] ?? '',
            'email': senderProfile['email'] ?? senderMeta['email'] ?? '',
            'phone': senderProfile['phone'] ?? senderMeta['phone'] ?? '',
            'website': senderProfile['website'] ?? senderMeta['website'] ?? '',
            'address': senderProfile['address'] ?? senderMeta['address'] ?? '',
            'tags': senderProfile['interests'] ?? [],
            'source': 'B2B Connection',
            'is_new': true,
            'linked_profile_id': currentUserId,
          });
        } catch (_) {}
      }
      return true;
    } catch (e) {
      debugPrint('Error connecting directly: $e');
      return false;
    }
  }

  // 🤝 Fetch accepted B2B connections registered for a specific event
  Future<List<Map<String, dynamic>>> fetchAcceptedConnectionsForEvent(String eventId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return [];
      
      // 1. Fetch all connections for current user
      final connections = await _supabase
          .from('connections')
          .select('linked_profile_id')
          .eq('user_id', currentUserId)
          .not('linked_profile_id', 'is', null);
          
      final connectionIds = (connections as List)
          .map((c) => c['linked_profile_id'] as String)
          .toSet()
          .toList();

      if (connectionIds.isEmpty) return [];
      
      // 2. Fetch profiles registered for this event that are in the user's connections
      final registrations = await _supabase
          .from('event_registrations')
          .select('profile_id, profiles!event_registrations_profile_id_fkey(*)')
          .eq('event_id', eventId)
          .inFilter('profile_id', connectionIds);
      
      final list = <Map<String, dynamic>>[];
      for (var reg in (registrations as List)) {
        final profile = reg['profiles'];
        if (profile != null) {
          list.add(Map<String, dynamic>.from(profile));
        }
      }
      
      list.sort((a, b) => (a['full_name'] ?? '').compareTo(b['full_name'] ?? ''));
      return list;
    } catch (e) {
      debugPrint('Error fetching event connections: $e');
      return [];
    }
  }

  // 🤝 Fetch connection status between current user and target user
  Future<String> fetchConnectionStatus(String targetUserId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return 'none';
      if (currentUserId == targetUserId) return 'accepted'; // Self is always accepted/fully visible

      // 1. Check if an active connection already exists in the connections table
      final existingConn = await _supabase
          .from('connections')
          .select('id')
          .eq('user_id', currentUserId)
          .eq('linked_profile_id', targetUserId)
          .maybeSingle();

      if (existingConn != null) {
        return 'accepted';
      }

      return 'none';
    } catch (e) {
      debugPrint('Error fetching connection status: $e');
      return 'none';
    }
  }

  // 👤 Fetch all profiles (for directory) excluding self
  Future<List<Map<String, dynamic>>> fetchProfiles() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return [];
      final response = await _supabase
          .from('profiles')
          .select()
          .neq('id', currentUserId)
          .order('full_name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching profiles: $e');
      return [];
    }
  }

  // 👤 Fetch profiles registered for a specific event excluding self
  Future<List<Map<String, dynamic>>> fetchProfilesForEvent(String eventId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return [];
      final response = await _supabase
          .from('event_registrations')
          .select('profiles(*)')
          .eq('event_id', eventId)
          .neq('profile_id', currentUserId);
      
      final list = <Map<String, dynamic>>[];
      for (var item in (response as List)) {
        if (item['profiles'] != null) {
          list.add(Map<String, dynamic>.from(item['profiles']));
        }
      }
      
      list.sort((a, b) => (a['full_name'] ?? '').compareTo(b['full_name'] ?? ''));
      return list;
    } catch (e) {
      debugPrint('Error fetching profiles for event: $e');
      return fetchProfiles(); // Fallback to all profiles
    }
  }

  // 📅 Fetch all meetings with joined profiles for a user
  Future<List<MeetingModel>> fetchMeetings(String userId) async {
    try {
      final response = await _supabase
          .from('meetings')
          .select('*, organizer_profile:profiles!organizer_id(*), attendee_profile:profiles!attendee_id(*)')
          .or('organizer_id.eq.$userId,attendee_id.eq.$userId')
          .order('date', ascending: true)
          .order('start_time', ascending: true);
      
      return (response as List).map((json) => MeetingModel.fromJson(json, userId)).toList();
    } catch (e) {
      debugPrint('Error fetching meetings: $e');
      return [];
    }
  }

  // 📅 Stream meetings with joined profiles in real-time
  Stream<List<MeetingModel>> streamMeetings(String userId) {
    final controller = StreamController<List<MeetingModel>>();
    
    // Initial fetch
    fetchMeetings(userId).then((meetings) {
      if (!controller.isClosed) {
        controller.add(meetings);
      }
    });
    
    // Subscribe to real-time changes on meetings table
    final channel = _supabase
        .channel('public:meetings:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'meetings',
          callback: (payload) async {
            final updatedMeetings = await fetchMeetings(userId);
            if (!controller.isClosed) {
              controller.add(updatedMeetings);
            }
          },
        )
        .subscribe();
        
    controller.onCancel = () {
      channel.unsubscribe();
      controller.close();
    };
    
    return controller.stream;
  }

  // 📅 Create a new meeting request
  Future<bool> createMeeting(MeetingModel meeting) async {
    try {
      await _supabase.from('meetings').insert(meeting.toJson());
      return true;
    } catch (e) {
      debugPrint('Error creating meeting: $e');
      return false;
    }
  }

  // 📅 Update meeting status (accepted, declined, cancelled)
  Future<bool> updateMeetingStatus(String meetingId, String status) async {
    try {
      await _supabase
          .from('meetings')
          .update({'status': status})
          .eq('id', meetingId);
      return true;
    } catch (e) {
      debugPrint('Error updating meeting status: $e');
      return false;
    }
  }

  // 📅 Fetch booked slots (accepted meetings) for a user on a specific date
  Future<List<Map<String, String>>> fetchBookedSlots(String userId, String date) async {
    try {
      final response = await _supabase
          .from('meetings')
          .select('start_time, end_time')
          .eq('date', date)
          .eq('status', 'accepted')
          .or('organizer_id.eq.$userId,attendee_id.eq.$userId');
      
      return (response as List).map((item) {
        return {
          'start_time': item['start_time'].toString().substring(0, 5),
          'end_time': item['end_time'].toString().substring(0, 5),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching booked slots: $e');
      return [];
    }
  }

  // Helper method to parse time string "HH:MM" to double
  double _parseTimeToDouble(String timeStr) {
    final parts = timeStr.split(':');
    final hour = double.parse(parts[0]);
    final minute = double.parse(parts[1]);
    return hour + (minute / 60.0);
  }

  // Helper method to check overlap
  bool isSlotOverlapping(String proposedStartStr, String proposedEndStr, List<Map<String, String>> bookedSlots) {
    final propStart = _parseTimeToDouble(proposedStartStr);
    final propEnd = _parseTimeToDouble(proposedEndStr);
    
    for (var slot in bookedSlots) {
      final slotStart = _parseTimeToDouble(slot['start_time']!);
      final slotEnd = _parseTimeToDouble(slot['end_time']!);
      
      if (propStart < slotEnd && propEnd > slotStart) {
        return true; // Overlap detected
      }
    }
    return false;
  }

  // 📅 Check if either user has an overlapping accepted meeting before submission
  Future<bool> hasMeetingConflict(String organizerId, String attendeeId, String date, String startTime, String endTime) async {
    try {
      // Fetch all accepted meetings for either user on that date
      final response = await _supabase
          .from('meetings')
          .select('start_time, end_time')
          .eq('date', date)
          .eq('status', 'accepted')
          .or('organizer_id.eq.$organizerId,attendee_id.eq.$organizerId,organizer_id.eq.$attendeeId,attendee_id.eq.$attendeeId');
      
      final booked = (response as List).map((item) {
        return {
          'start_time': item['start_time'].toString().substring(0, 5),
          'end_time': item['end_time'].toString().substring(0, 5),
        };
      }).toList();

      return isSlotOverlapping(startTime, endTime, booked);
    } catch (e) {
      debugPrint('Error checking meeting conflict: $e');
      return false; // Fail safe
    }
  }

  // 📅 Stream a single meeting's status updates in real-time
  Stream<String> streamMeetingStatus(String meetingId) {
    return _supabase
        .from('meetings')
        .stream(primaryKey: ['id'])
        .eq('id', meetingId)
        .map((maps) {
          if (maps.isNotEmpty) {
            return maps.first['status'] as String;
          }
          return 'pending';
        });
  }

  // 📚 Fetch all sessions for a specific event
  Future<List<SessionModel>> fetchSessionsForEvent(String eventId) async {
    try {
      final response = await _supabase
          .from('sessions')
          .select()
          .eq('event_id', eventId)
          .order('start_time', ascending: true);
      
      return (response as List).map((data) => SessionModel.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
      return [];
    }
  }

  // ⭐ Fetch favorited sessions for the current/mock user
  Future<List<String>> fetchSessionFavorites() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return [];
      final response = await _supabase
          .from('session_favorites')
          .select('session_id')
          .eq('user_id', currentUserId);
      
      return (response as List).map((data) => data['session_id'].toString()).toList();
    } catch (e) {
      debugPrint('Error fetching favorites: $e');
      return [];
    }
  }

  // ⭐ Toggle session favorite (add/remove from agenda)
  Future<bool> toggleSessionFavorite(String sessionId, bool isFavorite) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return false;
      if (isFavorite) {
        await _supabase.from('session_favorites').insert({
          'user_id': currentUserId,
          'session_id': sessionId,
        });
      } else {
        await _supabase
            .from('session_favorites')
            .delete()
            .eq('user_id', currentUserId)
            .eq('session_id', sessionId);
      }
      return true;
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      return false;
    }
  }

  // 🤝 Fetch total accepted connections count for the current/mock user
  Future<int> fetchConnectionsCount() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return 0;
      final response = await _supabase
          .from('connections')
          .select('id')
          .eq('user_id', currentUserId);
      
      return (response as List).length;
    } catch (e) {
      debugPrint('Error fetching connections count: $e');
      return 0;
    }
  }

  // 📅 Fetch the next upcoming accepted meeting for the current/mock user
  Future<MeetingModel?> fetchNextMeeting() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return null;
      final response = await _supabase
          .from('meetings')
          .select('*, organizer_profile:profiles!organizer_id(*), attendee_profile:profiles!attendee_id(*)')
          .eq('status', 'accepted')
          .or('organizer_id.eq.$currentUserId,attendee_id.eq.$currentUserId')
          .order('date', ascending: true)
          .order('start_time', ascending: true);
      
      final list = response as List;
      if (list.isEmpty) return null;
      
      final now = DateTime.now();
      for (var item in list) {
        final meeting = MeetingModel.fromJson(item, currentUserId);
        try {
          final dateParts = meeting.date.split('-');
          final timeParts = meeting.startTime.split(':');
          final meetingDateTime = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
          if (meetingDateTime.isAfter(now)) {
            return meeting;
          }
        } catch (_) {
          return meeting;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching next meeting: $e');
      return null;
    }
  }
}
