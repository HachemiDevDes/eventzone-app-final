class ExhibitorModel {
  final String id;
  final String? eventId;
  final String name;
  final String? booth;
  final String? industry;
  final String? website;
  final String? logo;
  final String? description;
  final String? contactEmail;

  ExhibitorModel({
    required this.id,
    this.eventId,
    required this.name,
    this.booth,
    this.industry,
    this.website,
    this.logo,
    this.description,
    this.contactEmail,
  });

  factory ExhibitorModel.fromJson(Map<String, dynamic> json) {
    return ExhibitorModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String?,
      name: json['name'] as String? ?? 'Exhibitor',
      booth: json['booth_number'] as String? ?? json['booth'] as String?,
      industry: json['industry'] as String?,
      website: json['website'] as String? ?? json['url'] as String?,
      logo: json['logo_url'] as String? ?? json['logo'] as String? ?? json['image_url'] as String?,
      description: json['description'] as String? ?? json['products'] as String?,
      contactEmail: json['contact_email'] as String? ?? json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'booth': booth,
      'industry': industry,
      'website': website,
      'logo': logo,
      'description': description,
      'contact_email': contactEmail,
    };
  }
}
