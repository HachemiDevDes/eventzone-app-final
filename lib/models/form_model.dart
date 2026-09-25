class FormModel {
  final String id;
  final String? eventId;
  final String title;
  final String? description;
  final String? type;
  final String? ticketId;
  final List<FormFieldModel> fields;

  FormModel({
    required this.id,
    this.eventId,
    required this.title,
    this.description,
    this.type,
    this.ticketId,
    required this.fields,
  });

  factory FormModel.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'] as List? ?? [];
    final parsedFields = rawFields.map((f) {
      if (f is Map<String, dynamic>) {
        return FormFieldModel.fromJson(f);
      } else if (f is Map) {
        return FormFieldModel.fromJson(Map<String, dynamic>.from(f));
      }
      return FormFieldModel(id: 'unknown', label: 'Field');
    }).toList();

    return FormModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String?,
      title: json['title'] as String? ?? 'Registration Form',
      description: json['description'] as String?,
      type: json['type'] as String?,
      ticketId: json['ticket_id']?.toString(),
      fields: parsedFields,
    );
  }
}

class FormFieldModel {
  final String id;
  final String type;
  final String label;
  final bool required;
  final String placeholder;
  final String helpText;
  final List<String> options;
  final bool isLocked;
  final bool showsOnBadge;

  FormFieldModel({
    required this.id,
    this.type = 'text',
    required this.label,
    this.required = false,
    this.placeholder = '',
    this.helpText = '',
    this.options = const [],
    this.isLocked = false,
    this.showsOnBadge = false,
  });

  factory FormFieldModel.fromJson(Map<String, dynamic> json) {
    final rawOpts = json['options'];
    List<String> parsedOptions = [];
    if (rawOpts is List) {
      parsedOptions = rawOpts.map((o) => o.toString()).toList();
    }

    return FormFieldModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      label: json['label']?.toString() ?? 'Question',
      required: json['required'] as bool? ?? false,
      placeholder: json['placeholder']?.toString() ?? '',
      helpText: json['helpText']?.toString() ?? json['help_text']?.toString() ?? '',
      options: parsedOptions,
      isLocked: json['isLocked'] as bool? ?? json['is_locked'] as bool? ?? false,
      showsOnBadge: json['showsOnBadge'] as bool? ?? json['shows_on_badge'] as bool? ?? false,
    );
  }
}
