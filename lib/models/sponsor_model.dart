class SponsorModel {
  final String id;
  final String? eventId;
  final String name;
  final String? tier;
  final String? industry;
  final String? website;
  final String? logo;
  final String? description;

  SponsorModel({
    required this.id,
    this.eventId,
    required this.name,
    this.tier,
    this.industry,
    this.website,
    this.logo,
    this.description,
  });

  factory SponsorModel.fromJson(Map<String, dynamic> json) {
    return SponsorModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String?,
      name: json['name'] as String? ?? 'Sponsor',
      tier: json['tier'] as String?,
      industry: json['industry'] as String?,
      website: json['website'] as String? ?? json['url'] as String?,
      logo: json['logo_url'] as String? ?? json['logo'] as String? ?? json['image_url'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'tier': tier,
      'industry': industry,
      'website': website,
      'logo': logo,
      'description': description,
    };
  }
}
