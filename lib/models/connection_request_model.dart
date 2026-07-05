class ConnectionRequestModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String? message;
  final String status;
  final DateTime createdAt;
  
  // Optional sender profile details fetched with the request
  final String? senderName;
  final String? senderAvatarUrl;
  final String? senderTitle;
  final String? senderCompany;

  ConnectionRequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.message,
    required this.status,
    required this.createdAt,
    this.senderName,
    this.senderAvatarUrl,
    this.senderTitle,
    this.senderCompany,
  });

  factory ConnectionRequestModel.fromJson(Map<String, dynamic> json) {
    // Parse sender profile if present from Supabase select with joins
    final senderProfile = json['sender_profile'] as Map<String, dynamic>?;
    
    return ConnectionRequestModel(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      message: json['message'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: senderProfile?['full_name'] as String?,
      senderAvatarUrl: senderProfile?['avatar_url'] as String?,
      senderTitle: senderProfile?['job_title'] as String?,
      senderCompany: senderProfile?['company_name'] as String?,
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
    };
  }
}
