import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/ticket_model.dart';
import '../models/form_model.dart';
import '../theme/eventzone_theme.dart';

class TicketRegistrationDialog extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final TicketModel ticket;
  final FormModel? form;
  final Map<String, dynamic>? initialProfile;
  final Future<void> Function({
    required String fullName,
    required String email,
    String? phone,
    String? company,
    String? jobTitle,
    Map<String, dynamic>? customAnswers,
  }) onSubmit;

  const TicketRegistrationDialog({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.ticket,
    this.form,
    this.initialProfile,
    required this.onSubmit,
  });

  @override
  State<TicketRegistrationDialog> createState() => _TicketRegistrationDialogState();
}

class _TicketRegistrationDialogState extends State<TicketRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _companyController;
  late TextEditingController _jobTitleController;

  final Map<String, dynamic> _customAnswers = {};
  final Map<String, TextEditingController> _customControllers = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile ?? {};
    _nameController = TextEditingController(text: p['full_name']?.toString() ?? '');
    _emailController = TextEditingController(text: p['email']?.toString() ?? '');
    _phoneController = TextEditingController(text: p['phone']?.toString() ?? '');
    _companyController = TextEditingController(text: p['company_name']?.toString() ?? p['company']?.toString() ?? '');
    _jobTitleController = TextEditingController(text: p['job_title']?.toString() ?? '');

    // Initialize controllers for custom form questions
    if (widget.form != null) {
      for (final field in widget.form!.fields) {
        // Skip standard core fields already handled
        if (field.id == 'f_core_name' ||
            field.id == 'f_core_email' ||
            field.id == 'f_core_phone' ||
            field.id == 'name' ||
            field.id == 'email' ||
            field.id == 'phone') {
          continue;
        }

        if (field.type == 'select') {
          if (field.options.isNotEmpty) {
            // Optional default or empty
          }
        } else {
          _customControllers[field.id] = TextEditingController();
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    for (final c in _customControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Collect custom answers
    final Map<String, dynamic> answers = Map.from(_customAnswers);
    for (final entry in _customControllers.entries) {
      if (entry.value.text.trim().isNotEmpty) {
        answers[entry.key] = entry.value.text.trim();
      }
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        company: _companyController.text.trim(),
        jobTitle: _jobTitleController.text.trim(),
        customAnswers: answers,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final isFree = ticket.isFree;
    final priceStr = isFree
        ? "Free".tr()
        : "${NumberFormat('#,###').format(ticket.price)} ${ticket.currency}";

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1420),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                ticket.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isFree
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : EventzoneTheme.primaryAction.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                priceStr,
                                style: TextStyle(
                                  color: isFree ? const Color(0xFF10B981) : EventzoneTheme.primaryAction,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.eventTitle,
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              if (ticket.requiresApproval) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.info, color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "This ticket requires organizer review. Your registration will be placed in the approval queue.".tr(),
                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),
              const Text(
                "Attendee Information",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Full Name
              _buildTextField(
                controller: _nameController,
                label: "Full Name".tr(),
                icon: LucideIcons.user,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Full name is required".tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Email
              _buildTextField(
                controller: _emailController,
                label: "Email Address".tr(),
                icon: LucideIcons.mail,
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Email address is required".tr();
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return "Enter a valid email".tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Phone
              _buildTextField(
                controller: _phoneController,
                label: "Phone Number".tr(),
                icon: LucideIcons.phone,
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Phone number is required".tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Company
              _buildTextField(
                controller: _companyController,
                label: "Company / Organization (Optional)".tr(),
                icon: LucideIcons.building,
              ),
              const SizedBox(height: 12),

              // Job Title
              _buildTextField(
                controller: _jobTitleController,
                label: "Job Title (Optional)".tr(),
                icon: LucideIcons.briefcase,
              ),

              // Custom Form Questions
              if (widget.form != null && widget.form!.fields.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  widget.form!.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...widget.form!.fields.map((field) {
                  // Skip standard fields already rendered above
                  if (field.id == 'f_core_name' ||
                      field.id == 'f_core_email' ||
                      field.id == 'f_core_phone' ||
                      field.id == 'name' ||
                      field.id == 'email' ||
                      field.id == 'phone') {
                    return const SizedBox.shrink();
                  }

                  if (field.type == 'select') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildSelectField(field),
                    );
                  }

                  final ctrl = _customControllers[field.id];
                  if (ctrl == null) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildTextField(
                      controller: ctrl,
                      label: field.label + (field.required ? " *" : " (Optional)"),
                      icon: LucideIcons.helpCircle,
                      validator: field.required
                          ? (val) {
                              if (val == null || val.trim().isEmpty) {
                                return "${field.label} is required".tr();
                              }
                              return null;
                            }
                          : null,
                    ),
                  );
                }),
              ],

              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ticket.requiresApproval
                        ? const Color(0xFFF59E0B)
                        : EventzoneTheme.primaryAction,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              ticket.requiresApproval ? LucideIcons.send : LucideIcons.checkCircle2,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                ticket.requiresApproval
                                    ? "Submit Application for Approval".tr()
                                    : "Confirm Registration".tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: const Color(0xFF161C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: EventzoneTheme.primaryAction),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildSelectField(FormFieldModel field) {
    final currentValue = _customAnswers[field.id]?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label + (field.required ? " *" : " (Optional)"),
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _showSelectOptionsModal(field);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF161C2C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.list, color: Colors.white38, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentValue ?? (field.placeholder.isNotEmpty ? field.placeholder : "Select an option...".tr()),
                    style: TextStyle(
                      color: currentValue != null ? Colors.white : Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(LucideIcons.chevronDown, color: Colors.white54, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSelectOptionsModal(FormFieldModel field) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1420),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field.label,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: field.options.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (_, idx) {
                    final option = field.options[idx];
                    final isSelected = _customAnswers[field.id] == option;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        option,
                        style: TextStyle(
                          color: isSelected ? EventzoneTheme.primaryAction : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(LucideIcons.check, color: EventzoneTheme.primaryAction, size: 18)
                          : null,
                      onTap: () {
                        setState(() {
                          _customAnswers[field.id] = option;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
