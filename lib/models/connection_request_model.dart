import 'dart:convert';

class ConnectionRequestModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String? message;
  final String status;
  final DateTime createdAt;
  final String? eventId;
  
  // Sender details (for incoming requests)
  final String? senderName;
  final String? senderAvatarUrl;
  final String? senderTitle;
  final String? senderCompany;
  final String? senderEmail;
  final String? senderPhone;

  // Receiver details (for outgoing sent requests)
  final String? receiverName;
  final String? receiverAvatarUrl;
  final String? receiverTitle;
  final String? receiverCompany;

  ConnectionRequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.message,
    required this.status,
    required this.createdAt,
    this.eventId,
    this.senderName,
    this.senderAvatarUrl,
    this.senderTitle,
    this.senderCompany,
    this.senderEmail,
    this.senderPhone,
    this.receiverName,
    this.receiverAvatarUrl,
    this.receiverTitle,
    this.receiverCompany,
  });

  factory ConnectionRequestModel.fromJson(Map<String, dynamic> json) {
    final senderProfile = json['sender_profile'] as Map<String, dynamic>?;
    final receiverProfile = json['receiver_profile'] as Map<String, dynamic>?;

    Map<String, dynamic> notesData = {};
    if (json['notes'] != null && json['notes'].toString().trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(json['notes'].toString());
        if (parsed is Map) notesData = Map<String, dynamic>.from(parsed);
      } catch (_) {}
    }

    DateTime parsedDate;
    try {
      parsedDate = json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final senderId = json['sender_id']?.toString() ??
        json['user_id']?.toString() ??
        notesData['sender_id']?.toString() ??
        '';

    final receiverId = json['receiver_id']?.toString() ??
        json['connected_user_id']?.toString() ??
        json['linked_profile_id']?.toString() ??
        notesData['recipient_id']?.toString() ??
        '';

    return ConnectionRequestModel(
      id: json['id'] as String? ?? '',
      senderId: senderId,
      receiverId: receiverId,
      message: json['message'] as String? ?? notesData['message'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: parsedDate,
      eventId: json['event_id'] as String?,
      senderName: json['sender_name'] as String? ??
          senderProfile?['full_name'] as String? ??
          notesData['sender_name'] as String?,
      senderAvatarUrl: json['sender_avatar'] as String? ??
          senderProfile?['avatar_url'] as String? ??
          notesData['sender_avatar'] as String?,
      senderTitle: json['sender_title'] as String? ??
          senderProfile?['job_title'] as String? ??
          notesData['sender_title'] as String?,
      senderCompany: json['sender_company'] as String? ??
          senderProfile?['company_name'] as String? ??
          notesData['sender_company'] as String?,
      senderEmail: json['sender_email'] as String? ??
          senderProfile?['email'] as String? ??
          notesData['sender_email'] as String?,
      senderPhone: json['sender_phone'] as String? ??
          senderProfile?['phone'] as String? ??
          notesData['sender_phone'] as String?,
      receiverName: json['name'] as String? ??
          receiverProfile?['full_name'] as String? ??
          notesData['recipient_name'] as String?,
      receiverAvatarUrl: json['avatar_url'] as String? ??
          receiverProfile?['avatar_url'] as String?,
      receiverTitle: json['title'] as String? ??
          receiverProfile?['job_title'] as String?,
      receiverCompany: json['company'] as String? ??
          receiverProfile?['company_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      if (eventId != null) 'event_id': eventId,
    };
  }
}
