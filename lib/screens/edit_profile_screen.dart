import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import '../services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _jobController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  String _phoneCountryCode = '+1';
  final _bioController = TextEditingController();
  final ExpansionTileController _bioExpansionController = ExpansionTileController();

  final List<String> _lookingForOptions = [
    'Investors', 'Clients', 'Partners', 'Talent', 'Opportunities', 'Mentorship',
    'Networking', 'Co-founders', 'Freelancers', 'Knowledge Sharing', 'Distributors',
    'Sponsors', 'Job Opportunities', 'Internships', 'Venture Capital', 'Dev Partners',
    'Brand Ambassadors', 'Content Creators', 'Influencers'
  ];
  List<String> _selectedLookingFor = [];

  final List<String> _predefinedIndustries = [
    'Artificial Intelligence', 'Blockchain & Web3', 'Cybersecurity', 'FinTech',
    'HealthTech', 'EdTech', 'CleanTech & Energy', 'E-Commerce'.tr(), 'SaaS',
    'Venture Capital', 'Angel Investing', 'Product Management', 'Software Engineering',
    'UX/UI Design', 'Digital Marketing', 'Sales & Business Dev', 'Cloud Computing',
    'Data Science', 'Mobile Development', 'AR/VR', 'IoT (Internet of Things)',
    'Game Development', 'Robotics', 'Aerospace', 'HR & Recruiting', 'Legal Tech',
    'PropTech', 'InsurTech', 'Media & Entertainment', 'BioTech', 'Devops & SRE', 'ClimateTech'
  ];
  String _industrySearchQuery = "";
  List<String> _selectedIndustries = [];
  List<String> _selectedInterests = [];

  final _supabaseService = SupabaseService();
  String _avatarUrl = "";

  List<Map<String, dynamic>> _socialLinks = [];

  bool _isAutoSaving = false;
  String? _syncError;
  bool _isLoaded = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _nameController.addListener(_onFieldChanged);
    _jobController.addListener(_onFieldChanged);
    _companyController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _jobController.removeListener(_onFieldChanged);
    _companyController.removeListener(_onFieldChanged);
    _phoneController.removeListener(_onFieldChanged);
    _bioController.removeListener(_onFieldChanged);
    _debounceTimer?.cancel();
    _nameController.dispose();
    _jobController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_isLoaded) return;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 750), () {
      _autoSaveProfile();
    });
  }

  Future<void> _autoSaveProfile() async {
    if (!mounted) return;
    setState(() {
      _isAutoSaving = true;
      _syncError = null;
    });

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      if (mounted) {
        setState(() {
          _isAutoSaving = false;
          _syncError = "User not authenticated";
        });
      }
      return;
    }
    final errorMsg = await _supabaseService.updateProfile(
      currentUserId,
      fullName: _nameController.text,
      jobTitle: _jobController.text,
      companyName: _companyController.text,
      avatarUrl: _avatarUrl,
      phone: '$_phoneCountryCode ${_phoneController.text.trim()}',
      bio: _bioController.text,
      whatImLookingFor: _selectedLookingFor.join(', '),
      industries: _selectedIndustries,
      interests: _selectedInterests,
      metadata: {
        "socials": _socialLinks,
      },
    );
    
    // Update local cache so returning to other screens instantly shows changes
    if (errorMsg == null && mounted) {
      ref.read(currentUserProvider.notifier).updateLocalProfile({
        'full_name': _nameController.text,
        'job_title': _jobController.text,
        'company_name': _companyController.text,
        'avatar_url': _avatarUrl,
        'phone': '$_phoneCountryCode ${_phoneController.text.trim()}',
        'bio': _bioController.text,
        'what_im_looking_for': _selectedLookingFor.join(', '),
        'industries': _selectedIndustries,
        'interests': _selectedInterests,
        'metadata': {
          "socials": _socialLinks,
        },
      });
    }

    if (mounted) {
      setState(() {
        _isAutoSaving = false;
        _syncError = errorMsg;
      });
    }
  }

  Future<void> _loadProfile() async {
    final cachedData = ref.read(currentUserProvider).value;
    if (cachedData != null) {
      _populateData(cachedData);
      return;
    }
    
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;
    final data = await _supabaseService.fetchProfile(currentUserId);
    if (data != null) {
      _populateData(data);
    }
  }

  void _populateData(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      _nameController.text = data['full_name'] ?? '';
      _jobController.text = data['job_title'] ?? '';
      _companyController.text = data['company_name'] ?? '';
      
      String savedPhone = data['phone'] ?? '';
      if (savedPhone.isNotEmpty && savedPhone.contains(' ')) {
        final parts = savedPhone.split(' ');
        if (parts[0].startsWith('+')) {
          _phoneCountryCode = parts[0];
          _phoneController.text = parts.sublist(1).join(' ');
        } else {
          _phoneController.text = savedPhone;
        }
      } else {
        _phoneController.text = savedPhone;
      }

      _bioController.text = data['bio'] ?? '';
      
      final lookingForStr = data['what_im_looking_for'] as String?;
      if (lookingForStr != null && lookingForStr.isNotEmpty) {
        _selectedLookingFor = lookingForStr.split(',').map((e) => e.trim()).toList();
      } else {
        _selectedLookingFor = [];
      }
      
      _selectedIndustries = (data['industries'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      _selectedInterests = (data['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      
      _avatarUrl = data['avatar_url'] ?? "";
      
      final metadata = data['metadata'] as Map<String, dynamic>?;
      if (metadata != null && metadata['socials'] != null) {
        _socialLinks = List<Map<String, dynamic>>.from(
          (metadata['socials'] as List).map((e) => Map<String, dynamic>.from(e))
        );
      } else {
        _socialLinks = [];
      }
      _isLoaded = true;
    });
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await File(pickedFile.path).readAsBytes();
        final base64String = base64Encode(bytes);
        setState(() {
          _avatarUrl = "data:image/jpeg;base64,$base64String";
        });
        _autoSaveProfile();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  ImageProvider _getAvatarProvider(String url) {
    if (url.startsWith("data:image")) {
      try {
        final base64Content = url.split(",")[1];
        return MemoryImage(base64Decode(base64Content));
      } catch (_) {
        // Fallback to placeholder if base64 decoding fails
      }
    }
    return NetworkImage(url);
  }

  FaIconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'phone':
      case 'phone number':
        return FontAwesomeIcons.phone;
      case 'email':
        return FontAwesomeIcons.envelope;
      case 'link':
        return FontAwesomeIcons.link;
      case 'linkedin':
        return FontAwesomeIcons.linkedinIn;
      case 'instagram':
        return FontAwesomeIcons.instagram;
      case 'x':
      case 'twitter':
        return FontAwesomeIcons.xTwitter;
      case 'facebook':
        return FontAwesomeIcons.facebookF;
      case 'website':
      case 'company website':
        return FontAwesomeIcons.globe;
      case 'whatsapp':
        return FontAwesomeIcons.whatsapp;
      case 'threads':
        return FontAwesomeIcons.threads;
      case 'youtube':
        return FontAwesomeIcons.youtube;
      case 'snapchat':
        return FontAwesomeIcons.snapchat;
      case 'tiktok':
        return FontAwesomeIcons.tiktok;
      case 'github':
        return FontAwesomeIcons.github;
      case 'yelp':
        return FontAwesomeIcons.yelp;
      case 'venmo':
        return FontAwesomeIcons.moneyBill;
      case 'address':
        return FontAwesomeIcons.locationDot;
      case 'calendly':
        return FontAwesomeIcons.calendarCheck;
      default:
        return FontAwesomeIcons.link;
    }
  }

  void _showAddEditSocialDialog({Map<String, dynamic>? existingLink, int? index, String? platformName}) {
    final isEditing = existingLink != null;
    final platform = isEditing ? existingLink['platform'] as String : (platformName ?? 'LinkedIn'.tr());
    final isPhoneOrWhatsApp = platform == 'Phone Number'.tr() || platform == 'WhatsApp'.tr();
    
    String selectedCode = '+1';
    String initialValue = isEditing ? existingLink['value'] as String : '';
    
    if (isEditing && isPhoneOrWhatsApp) {
      final parts = initialValue.split(' ');
      if (parts.length > 1 && parts[0].startsWith('+')) {
        selectedCode = parts[0];
        initialValue = parts.sublist(1).join(' ');
      } else if (initialValue.startsWith('+')) {
        selectedCode = '+1'; 
      }
    }

    final valueController = TextEditingController(text: initialValue);
    final labelController = TextEditingController(text: isEditing ? existingLink['label'] as String : (platform == 'Email'.tr() ? 'Work' : platform == 'Phone Number'.tr() ? 'Mobile' : platform));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: GlassContainer(
                borderRadius: 32,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        isEditing ? "Edit $platform" : "Add $platform",
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                            ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(isPhoneOrWhatsApp ? "Phone Number".tr() : "Value / URL", style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: TextField(
                        controller: valueController,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        keyboardType: isPhoneOrWhatsApp ? TextInputType.phone : TextInputType.url,
                        decoration: InputDecoration(
                          prefixIcon: isPhoneOrWhatsApp 
                            ? Padding(
                                padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                                child: CountryCodePicker(
                                  onChanged: (countryCode) {
                                    if (countryCode.dialCode != null) {
                                      setModalState(() => selectedCode = countryCode.dialCode!);
                                    }
                                  },
                                  initialSelection: selectedCode,
                                  favorite: const ['+1', '+44'],
                                  showCountryOnly: false,
                                  showOnlyCountryWhenClosed: false,
                                  alignLeft: false,
                                  padding: EdgeInsets.zero,
                                  textStyle: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  dialogTextStyle: const TextStyle(color: Colors.white),
                                  dialogBackgroundColor: const Color(0xFF141927),
                                  searchStyle: const TextStyle(color: Colors.white),
                                  searchDecoration: InputDecoration(
                                    hintText: "Search country".tr(),
                                    hintStyle: const TextStyle(color: Colors.white54),
                                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                                  ),
                                  closeIcon: const Icon(Icons.close, color: Colors.white),
                                ),
                              )
                            : null,
                          hintText: platform == 'Email'.tr() ? 'example@email.com' : isPhoneOrWhatsApp ? '555-5555' : 'https://...',
                          hintStyle: const TextStyle(color: Colors.white24),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: isPhoneOrWhatsApp ? 0 : 16, vertical: 16),
                        ),
                        autofocus: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text("Label", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: TextField(
                        controller: labelController,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'e.g. Work, Personal, Mobile',
                          hintStyle: TextStyle(color: Colors.white24),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        if (isEditing)
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _socialLinks.removeAt(index!);
                                });
                                _autoSaveProfile();
                                Navigator.pop(context);
                              },
                              child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        if (!isEditing)
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel", style: TextStyle(color: Colors.white38, fontSize: 16)),
                            ),
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              if (valueController.text.isNotEmpty) {
                                final finalValue = isPhoneOrWhatsApp ? '$selectedCode ${valueController.text.trim()}' : valueController.text.trim();
                                setState(() {
                                  if (isEditing) {
                                    _socialLinks[index!] = {
                                      "platform": platform,
                                      "value": finalValue,
                                      "label": labelController.text,
                                    };
                                  } else {
                                    _socialLinks.add({
                                      "platform": platform,
                                      "value": finalValue,
                                      "label": labelController.text,
                                    });
                                  }
                                });
                                _autoSaveProfile();
                              }
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EventzoneTheme.primaryAction,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              isEditing ? "Save" : "Add", 
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: EventzoneTheme.backgroundStart,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft, color: Colors.white70),
                onPressed: () => Navigator.pop(context, true),
              )
            : null,
        title: Text("Edit Profile".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_isAutoSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: EventzoneTheme.primaryAction),
                ),
              ),
            )
          else if (_syncError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Tooltip(
                message: _syncError!,
                child: const Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 20),
              ),
            )
          else if (_isLoaded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(LucideIcons.cloudCheck, color: Colors.white24, size: 18),
                  const SizedBox(width: 4),
                  Text("Saved".tr(), style: const TextStyle(color: Colors.white24, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
      body: EventzoneTheme.buildPlayfulBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: EventzoneTheme.primaryAction.withOpacity(0.6),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _avatarUrl.isEmpty
                              ? const CircleAvatar(
                                  backgroundColor: Colors.white10,
                                  child: Icon(Icons.person, size: 50, color: Colors.white54),
                                )
                              : Image(
                                  image: _getAvatarProvider(_avatarUrl),
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: EventzoneTheme.primaryAction,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.pencil, size: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              const SizedBox(height: 32),
              _buildSectionTitle("Personal Details".tr()),
              _buildTextField("Full Name".tr(), _nameController),
              _buildTextField("Job Title".tr(), _jobController),
              _buildTextField("Company".tr(), _companyController),
              _buildPhoneField(),
              
              const SizedBox(height: 32),
              _buildSectionTitle("About Me".tr()),
              const SizedBox(height: 8),
              _buildCollapsibleBio(),
              _buildCollapsibleLookingFor(),
              _buildCollapsibleIndustriesAndInterests(),
              
              const SizedBox(height: 32),
              _buildSectionTitle("Social Links".tr()),
              const SizedBox(height: 8),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Builder(
                  builder: (context) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final itemWidth = (screenWidth - 88 - 40) / 3;
                    return Wrap(
                      spacing: 20,
                      runSpacing: 24,
                      alignment: WrapAlignment.center,
                      children: [
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.phone, "Phone Number".tr())),
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.envelope, "Email".tr())),
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.link, "Link".tr())),
                        
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.locationDot, "Address".tr())),
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.globe, "Company Website".tr())),
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.linkedinIn, "LinkedIn".tr())),
                        
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.instagram, "Instagram".tr())),
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.xTwitter, "X".tr())),
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.calendarCheck, "Calendly".tr())),
                        
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.facebookF, "Facebook".tr())),
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.threads, "Threads".tr())),
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.youtube, "YouTube".tr())),
                        
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.whatsapp, "WhatsApp".tr())),
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.snapchat, "Snapchat".tr())),
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.tiktok, "TikTok".tr())),
                        
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.github, "GitHub".tr())),
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.yelp, "Yelp".tr())),
                        SizedBox(width: itemWidth, child: _buildSocialAddButton(FontAwesomeIcons.moneyBill, "Venmo".tr())),
                      ],
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 32),
              _buildSectionTitle("Active Links".tr()),
              
              const SizedBox(height: 16),
              
              if (_socialLinks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      "No social links added yet.",
                      style: TextStyle(color: Colors.white24, fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _socialLinks.length,
                  itemBuilder: (context, index) {
                    return _buildActiveLink(_socialLinks[index], index);
                  },
                ),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showSignOutDialog,
                  icon: const Icon(LucideIcons.logOut, size: 18),
                  label: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSignOutDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Sign Out",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Are you sure you want to sign out? Your session will be ended.",
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Supabase.instance.client.auth.signOut();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Phone Number".tr(), style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              prefixIcon: Container(
                margin: const EdgeInsets.only(bottom: 4, right: 8),
                child: CountryCodePicker(
                  onChanged: (countryCode) {
                    if (countryCode.dialCode != null) {
                      setState(() {
                        _phoneCountryCode = countryCode.dialCode!;
                      });
                      _onFieldChanged();
                    }
                  },
                  initialSelection: _phoneCountryCode,
                  favorite: const ['+213', '+216', '+20', '+33', '+1', '+34', '+39', '+351', '+7', '+227', '+223', '+221'],
                  countryFilter: codes.map<String>((c) => c['code']!).where((code) => code != 'IL').toList(),
                  showCountryOnly: false,
                  showOnlyCountryWhenClosed: false,
                  alignLeft: false,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(color: Colors.white, fontSize: 16),
                  dialogTextStyle: const TextStyle(color: Colors.white),
                  dialogBackgroundColor: Colors.transparent,
                  barrierColor: Colors.black87,
                  dialogSize: Size(MediaQuery.of(context).size.width * 0.85, MediaQuery.of(context).size.height * 0.7),
                  boxDecoration: BoxDecoration(
                    color: const Color(0xFF1A1E2E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                  ),
                  closeIcon: const Icon(Icons.close, color: Colors.white54),
                  searchStyle: const TextStyle(color: Colors.white),
                  searchDecoration: InputDecoration(
                    hintText: "Search country".tr(),
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: EventzoneTheme.primaryAction)),
              contentPadding: const EdgeInsets.only(top: 10, bottom: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: EventzoneTheme.primaryAction)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialAddButton(FaIconData icon, String platform) {
    return GestureDetector(
      onTap: () => _showAddEditSocialDialog(platformName: platform),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EventzoneTheme.primaryAction,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: EventzoneTheme.primaryAction.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FaIcon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            platform,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveLink(Map<String, dynamic> link, int index) {
    final platform = link['platform'] as String;
    final value = link['value'] as String;
    final label = link['label'] as String;
    final icon = _getPlatformIcon(platform);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _showAddEditSocialDialog(existingLink: link, index: index),
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EventzoneTheme.primaryAction.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FaIcon(icon, color: EventzoneTheme.primaryAction, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.gripVertical, color: Colors.white10, size: 18),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _socialLinks.removeAt(index);
                  });
                  _autoSaveProfile();
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(LucideIcons.x, color: Colors.white24, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleBio() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: ExpansionTile(
          controller: _bioExpansionController,
          title: Text("Professional Bio".tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white70,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          children: [
            TextFormField(
              controller: _bioController,
              maxLines: 4,
              maxLength: 300,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Briefly tell us about your experience and background...",
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                fillColor: const Color(0xFF1A1E2E),
                filled: true,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: EventzoneTheme.primaryAction, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _bioExpansionController.collapse();
                  _onFieldChanged();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Bio saved!", style: TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(LucideIcons.checkCircle2, color: EventzoneTheme.primaryAction, size: 16),
                label: const Text("Save Bio", style: TextStyle(color: EventzoneTheme.primaryAction, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  backgroundColor: EventzoneTheme.primaryAction.withOpacity(0.12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleLookingFor() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: ExpansionTile(
          title: Text("What I'm Looking For".tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white70,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _lookingForOptions.map((option) {
                  final isSelected = _selectedLookingFor.contains(option);
                  return FilterChip(
                    label: Text(option),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedLookingFor.add(option);
                        } else {
                          _selectedLookingFor.remove(option);
                        }
                      });
                      _onFieldChanged();
                    },
                    backgroundColor: const Color(0xFF1A1E2E),
                    selectedColor: EventzoneTheme.primaryAction,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleIndustriesAndInterests() {
    final filteredOptions = _predefinedIndustries
        .where((opt) => opt.toLowerCase().contains(_industrySearchQuery.toLowerCase()))
        .toList();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: ExpansionTile(
          title: Text("Industries & Interests".tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white70,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          children: [
            TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Search areas...".tr(),
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                fillColor: const Color(0xFF1A1E2E),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (val) {
                setState(() {
                  _industrySearchQuery = val;
                });
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: filteredOptions.map((option) {
                  final isSelected = _selectedIndustries.contains(option);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIndustries.remove(option);
                          _selectedInterests.remove(option);
                        } else {
                          if (_selectedIndustries.length >= 5) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("You can select up to 5 tags maximum."),
                                backgroundColor: Colors.amber,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          _selectedIndustries.add(option);
                          _selectedInterests.add(option);
                        }
                      });
                      _onFieldChanged();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? EventzoneTheme.primaryAction.withOpacity(0.2) 
                            : const Color(0xFF1A1E2E),
                        border: Border.all(
                          color: isSelected 
                              ? EventzoneTheme.primaryAction 
                              : Colors.white10,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            option,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
