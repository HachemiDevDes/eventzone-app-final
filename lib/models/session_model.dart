class SessionModel {
  final String id;
  final String? eventId;
  final String title;
  final String? description;
  final String? speakerId;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? track;
  final String? date;
  final List<SessionSpeaker> speakers;
  final List<String> logos;

  SessionModel({
    required this.id,
    this.eventId,
    required this.title,
    this.description,
    this.speakerId,
    required this.startTime,
    required this.endTime,
    this.location,
    this.track,
    this.date,
    required this.speakers,
    required this.logos,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    // Parse speakers JSON array
    final rawSpeakers = json['speakers'] as List? ?? [];
    final parsedSpeakers = rawSpeakers.map((s) {
      final map = s as Map<String, dynamic>;
      return SessionSpeaker(
        name: map['name'] as String? ?? 'Speaker',
        title: map['title'] as String? ?? '',
        company: map['company'] as String? ?? '',
        avatarUrl: map['avatar_url'] as String? ?? '',
      );
    }).toList();

    // Parse logos JSON array
    final rawLogos = json['logos'] as List? ?? [];
    final parsedLogos = rawLogos.map((l) => l.toString()).toList();

    return SessionModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String?,
      title: json['title'] as String? ?? 'Untitled Session',
      description: json['description'] as String?,
      speakerId: json['speaker_id'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      location: json['location'] as String?,
      track: json['track'] as String?,
      date: json['date'] as String?,
      speakers: parsedSpeakers,
      logos: parsedLogos,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'title': title,
      'description': description,
      'speaker_id': speakerId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'location': location,
      'track': track,
      'date': date,
      'speakers': speakers.map((s) => s.toJson()).toList(),
      'logos': logos,
    };
  }
}

class SessionSpeaker {
  final String name;
  final String title;
  final String company;
  final String avatarUrl;

  SessionSpeaker({
    required this.name,
    required this.title,
    required this.company,
    required this.avatarUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'title': title,
      'company': company,
      'avatar_url': avatarUrl,
    };
  }
}
