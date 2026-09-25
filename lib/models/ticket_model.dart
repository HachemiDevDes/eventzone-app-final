class TicketModel {
  final String id;
  final String? eventId;
  final String name;
  final double price;
  final String currency;
  final int totalQuantity;
  final int quantityAvailable;
  final int soldQuantity;
  final bool isActive;
  final String description;
  final String color;
  final String badgeType;
  final List<String> features;
  final String? formId;
  final bool requiresApproval;
  final bool isPopular;
  final String status;

  TicketModel({
    required this.id,
    this.eventId,
    required this.name,
    this.price = 0.0,
    this.currency = 'DZD',
    this.totalQuantity = 100,
    this.quantityAvailable = 100,
    this.soldQuantity = 0,
    this.isActive = true,
    this.description = '',
    this.color = 'indigo',
    this.badgeType = 'thermal_qr',
    this.features = const [],
    this.formId,
    this.requiresApproval = false,
    this.isPopular = false,
    this.status = 'published',
  });

  bool get isFree => price <= 0;

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    double parsedPrice = 0.0;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else if (rawPrice != null) {
      parsedPrice = double.tryParse(rawPrice.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    }

    final rawFeatures = json['features'];
    List<String> parsedFeatures = [];
    if (rawFeatures is List) {
      parsedFeatures = rawFeatures.map((f) => f.toString()).toList();
    }

    final totalQty = json['total_quantity'] as int? ?? json['quantity_available'] as int? ?? 100;

    return TicketModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String?,
      name: json['name'] as String? ?? 'General Admission',
      price: parsedPrice,
      currency: json['currency'] as String? ?? 'DZD',
      totalQuantity: totalQty,
      quantityAvailable: json['quantity_available'] as int? ?? totalQty,
      soldQuantity: json['sold_quantity'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      description: json['description'] as String? ?? '',
      color: json['color'] as String? ?? 'indigo',
      badgeType: json['badge_type'] as String? ?? 'thermal_qr',
      features: parsedFeatures,
      formId: json['form_id'] as String?,
      requiresApproval: json['requires_approval'] as bool? ?? false,
      isPopular: json['is_popular'] as bool? ?? false,
      status: json['status'] as String? ?? 'published',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'price': price,
      'currency': currency,
      'total_quantity': totalQuantity,
      'quantity_available': quantityAvailable,
      'sold_quantity': soldQuantity,
      'is_active': isActive,
      'description': description,
      'color': color,
      'badge_type': badgeType,
      'features': features,
      'form_id': formId,
      'requires_approval': requiresApproval,
      'is_popular': isPopular,
      'status': status,
    };
  }
}
