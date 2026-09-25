class MeetingModel {
  final String id;
  final String? eventId;
  final String organizerId;
  final String attendeeId;
  final String title;
  final String date; // YYYY-MM-DD
  final String startTime; // HH:MM
  final String endTime; // HH:MM
  final String? location;
  final String? note;
  final String status; // pending, accepted, declined, cancelled
  final DateTime createdAt;

  // Joined profile details for displaying in the schedule list
  final String? otherName;
  final String? otherAvatarUrl;
  final String? otherTitle;
  final String? otherCompany;

  MeetingModel({
    required this.id,
    this.eventId,
    required this.organizerId,
    required this.attendeeId,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.location,
    this.note,
    required this.status,
    required this.createdAt,
    this.otherName,
    this.otherAvatarUrl,
    this.otherTitle,
    this.otherCompany,
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json, String currentUserId) {
    // Determine the "other" party profile depending on whether we are organizer or attendee
    final isOrganizer = json['organizer_id'] == currentUserId;
    final otherProfile = isOrganizer 
        ? json['attendee_profile'] as Map<String, dynamic>?
        : json['organizer_profile'] as Map<String, dynamic>?;

    return MeetingModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String?,
      organizerId: json['organizer_id'] as String,
      attendeeId: json['attendee_id'] as String,
      title: json['title'] as String,
      date: json['date'] as String,
      startTime: json['start_time'].toString().substring(0, 5), // Keep only HH:MM
      endTime: json['end_time'].toString().substring(0, 5),
      location: json['location'] as String?,
      note: json['note'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      otherName: otherProfile?['full_name'] as String?,
      otherAvatarUrl: otherProfile?['avatar_url'] as String?,
      otherTitle: otherProfile?['job_title'] as String?,
      otherCompany: otherProfile?['company_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'organizer_id': organizerId,
      'attendee_id': attendeeId,
      'title': title,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'location': location,
      'note': note,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (eventId != null && eventId!.isNotEmpty) {
      map['event_id'] = eventId;
    }
    return map;
  }
}
