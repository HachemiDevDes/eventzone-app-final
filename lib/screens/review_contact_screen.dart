import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/device_contacts_service.dart';

class ReviewContactScreen extends StatefulWidget {
  final String initialName;
  final String initialTitle;
  final String initialEmail;
  final String initialPhone;
  final String initialWebsite;
  final String initialCompany;
  final String initialDepartment;
  final String initialAddress;
  final String? initialNotes;
  final String source;

  const ReviewContactScreen({
    super.key,
    required this.initialName,
    required this.initialTitle,
    required this.initialEmail,
    required this.initialPhone,
    required this.initialWebsite,
    required this.initialCompany,
    required this.initialDepartment,
    required this.initialAddress,
    this.initialNotes,
    required this.source,
  });

  @override
  State<ReviewContactScreen> createState() => _ReviewContactScreenState();
}

class _ReviewContactScreenState extends State<ReviewContactScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _titleController;
  late TextEditingController _companyController;
  late TextEditingController _departmentController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _websiteController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;

  File? _selectedImage;
  bool _isSaving = false;
  bool _saveToPhoneAlso = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _titleController = TextEditingController(text: widget.initialTitle);
    _companyController = TextEditingController(text: widget.initialCompany);
    _departmentController = TextEditingController(text: widget.initialDepartment);
    _emailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _websiteController = TextEditingController(text: widget.initialWebsite);
    _addressController = TextEditingController(text: widget.initialAddress);
    _notesController = TextEditingController(text: widget.initialNotes ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _companyController.dispose();
    _departmentController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF0F1322),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(LucideIcons.camera, color: Colors.white70),
                title: Text("Take Photo".tr(), style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 800,
                    maxHeight: 800,
                    imageQuality: 85,
                  );
                  if (file != null) {
                    setState(() => _selectedImage = File(file.path));
                  }
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.image, color: Colors.white70),
                title: Text("Choose from Gallery".tr(), style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 800,
                    maxHeight: 800,
                    imageQuality: 85,
                  );
                  if (file != null) {
                    setState(() => _selectedImage = File(file.path));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final currentUserId = currentUser?.id;
      if (currentUserId == null) {
        setState(() => _isSaving = false);
        return;
      }

      // Check subscription or trial status before proceeding
      final profileRes = await Supabase.instance.client.from('profiles').select('created_at, subscription_end_date').eq('id', currentUserId).single();
      
      final now = DateTime.now();
      bool isActive = false;
      
      if (profileRes['subscription_end_date'] != null) {
        final subEnd = DateTime.parse(profileRes['subscription_end_date']);
        if (subEnd.isAfter(now)) isActive = true;
      }
      
      if (!isActive && profileRes['created_at'] != null) {
        final createdAt = DateTime.parse(profileRes['created_at']);
        final trialEnd = createdAt.add(Duration(days: 15));
        if (trialEnd.isAfter(now)) isActive = true;
      }

      if (!isActive) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Your trial/subscription has expired. Please upgrade to save contacts.".tr()),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() => _isSaving = false);
        }
        return;
      }

      String avatarUrl = "";

      if (_selectedImage != null) {
        try {
          final fileName = "${DateTime.now().millisecondsSinceEpoch}_avatar.jpg";
          await Supabase.instance.client.storage
              .from('avatars')
              .upload(fileName, _selectedImage!);
          avatarUrl = Supabase.instance.client.storage
              .from('avatars')
              .getPublicUrl(fileName);
        } catch (e) {
          avatarUrl = _selectedImage!.path;
        }
      }

      String initialNotes = _notesController.text.trim();
      if (initialNotes.isNotEmpty) {
        initialNotes = jsonEncode([
          {
            "text": initialNotes,
            "date": DateTime.now().toIso8601String()
          }
        ]);
      }

      final newConnection = {
        'user_id': currentUserId,
        'name': _nameController.text.trim(),
        'title': _titleController.text.trim(),
        'company': _companyController.text.trim(),
        'department': _departmentController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'website': _websiteController.text.trim(),
        'address': _addressController.text.trim(),
        'notes': initialNotes,
        'avatar_url': avatarUrl,
        'source': widget.source,
        'is_new': true,
      };

      await Supabase.instance.client.from('connections').insert(newConnection);

      // Also save to device contacts if option enabled
      if (_saveToPhoneAlso) {
        await DeviceContactsService.saveContactToDevice(
          name: _nameController.text.trim(),
          title: _titleController.text.trim(),
          company: _companyController.text.trim(),
          department: _departmentController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          website: _websiteController.text.trim(),
          address: _addressController.text.trim(),
          notes: _notesController.text.trim(),
        );
      }

      if (mounted) {
        final successMsg = _saveToPhoneAlso
            ? "Saved ${_nameController.text.trim()} to App & Phone contacts!".tr()
            : "Successfully saved ${_nameController.text.trim()}!".tr();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: EventzoneTheme.accentSuccess,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving contact: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveToDeviceOnly() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Name is required to save to contacts.".tr()),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final success = await DeviceContactsService.saveContactToDevice(
        name: name,
        title: _titleController.text.trim(),
        company: _companyController.text.trim(),
        department: _departmentController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        website: _websiteController.text.trim(),
        address: _addressController.text.trim(),
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Saved to phone contacts successfully!".tr()),
              backgroundColor: EventzoneTheme.accentSuccess,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Contacts permission was not granted.".tr()),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving to device contacts: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF060913),
      appBar: AppBar(
        backgroundColor: Color(0xFF060913),
        elevation: 0,
        title: Text("Review Scanned Contact".tr(), style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                           CircleAvatar(
                            radius: 54,
                            backgroundColor: Colors.white10,
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : null,
                            child: _selectedImage == null
                                ? Icon(LucideIcons.user, size: 48, color: Colors.white54)
                                : null,
                          ),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: EventzoneTheme.primaryAction,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(LucideIcons.camera, size: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    _buildSectionHeader("Contact Info".tr()),
                    SizedBox(height: 8),
                    _buildTextField("Full Name".tr(), _nameController, LucideIcons.user, fieldKey: 'name', validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Name is required";
                      return null;
                    }),
                    _buildTextField("Job Title".tr(), _titleController, LucideIcons.briefcase, fieldKey: 'title', validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Job title is required";
                      return null;
                    }),
                    _buildTextField("Company".tr(), _companyController, LucideIcons.building2, fieldKey: 'company'),
                    _buildTextField("Department", _departmentController, LucideIcons.layers, fieldKey: 'department'),
                    _buildTextField("Email Address", _emailController, LucideIcons.mail, fieldKey: 'email', keyboardType: TextInputType.emailAddress),
                    _buildTextField("Phone Number".tr(), _phoneController, LucideIcons.phone, fieldKey: 'phone', keyboardType: TextInputType.phone),
                    _buildTextField("Website", _websiteController, LucideIcons.globe, fieldKey: 'website', keyboardType: TextInputType.url),
                    _buildTextField("Address".tr(), _addressController, LucideIcons.mapPin, fieldKey: 'address'),
                    
                    SizedBox(height: 16),
                    _buildSectionHeader("Notes & Tags".tr()),
                    SizedBox(height: 8),
                    _buildTextField("Reminder Notes", _notesController, LucideIcons.fileText, fieldKey: 'notes', maxLines: 3),
                    
                    SizedBox(height: 16),
                    _buildSectionHeader("Save Options".tr()),
                    SizedBox(height: 8),
                    GlassContainer(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(LucideIcons.contact, color: Colors.white70, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Also Save to Phone Contacts".tr(),
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  "Sync to Android or iOS address book".tr(),
                                  style: TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _saveToPhoneAlso,
                            onChanged: (val) => setState(() => _saveToPhoneAlso = val),
                            activeThumbColor: EventzoneTheme.primaryAction,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: Color(0xFF090C16),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveContact,
                        icon: _isSaving
                            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(_saveToPhoneAlso ? LucideIcons.cloudLightning : LucideIcons.cloud, size: 18),
                        label: Text(
                          _saveToPhoneAlso ? "Save to App & Phone".tr() : "Save to Eventzone App".tr(),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EventzoneTheme.primaryAction,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _saveToDeviceOnly,
                        icon: Icon(LucideIcons.contact, size: 16, color: Colors.white70),
                        label: Text(
                          "Save to Phone Contacts Only".tr(),
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white54,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    String? fieldKey,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.0),
      child: GlassContainer(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            icon: Icon(icon, color: Colors.white54, size: 18),
            labelText: label,
            labelStyle: TextStyle(color: Colors.white30, fontSize: 13),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    );
  }
}
