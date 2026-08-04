import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/eventzone_theme.dart';
import '../providers/auth_providers.dart';
import 'package:easy_localization/easy_localization.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1: Basics
  final _step1FormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _phoneCountryCode = '+1';
  final _jobController = TextEditingController();
  final _companyController = TextEditingController();
  String? _avatarUrl;

  // Step 2: About You
  final _bioController = TextEditingController();
  final List<String> _lookingForOptions = ['Investors', 'Clients', 'Partners', 'Talent', 'Opportunities', 'Mentorship', 'Networking', 'Co-founders', 'Freelancers', 'Knowledge Sharing', 'Distributors', 'Sponsors', 'Job Opportunities', 'Internships', 'Venture Capital', 'Dev Partners', 'Brand Ambassadors', 'Content Creators', 'Influencers'];
  final List<String> _selectedLookingFor = [];

  // Step 3: Industries & Interests
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
  final List<String> _selectedIndustries = [];
  final List<String> _selectedInterests = [];


  @override
  void initState() {
    super.initState();
    // Prefill user details if available
    Future.microtask(() {
      final profile = ref.read(currentUserProvider).value;
      if (profile != null) {
        setState(() {
          _nameController.text = profile['full_name'] ?? '';
          
          String savedPhone = profile['phone'] ?? '';
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

          _jobController.text = profile['job_title'] ?? '';
          _companyController.text = profile['company'] ?? profile['company_name'] ?? '';
          _avatarUrl = profile['avatar_url'];
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _jobController.dispose();
    _companyController.dispose();
    _bioController.dispose();

    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
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
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF141927),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.white70),
              title: Text('Photo Gallery'.tr(), style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.white70),
              title: Text('Camera'.tr(), style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _getAvatarProvider(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }
    if (url.startsWith("data:image")) {
      try {
        final base64Content = url.split(",")[1];
        return MemoryImage(base64Decode(base64Content));
      } catch (_) {}
    }
    return NetworkImage(url);
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isSubmitting = true);

    final errorMessage = await ref.read(currentUserProvider.notifier).updateProfileData(
      fullName: _nameController.text.trim(),
      jobTitle: _jobController.text.trim(),
      company: _companyController.text.trim(),
      phone: '$_phoneCountryCode ${_phoneController.text.trim()}',
      avatarUrl: _avatarUrl,
      bio: _bioController.text.trim(),
      whatImLookingFor: _selectedLookingFor.join(', '),
      industries: _selectedIndustries,
      interests: _selectedInterests,
      onboardingCompleted: true,
    );

    if (errorMessage == null) {
      final firstName = _nameController.text.trim().split(' ').first;
      
      // Update local provider state synchronously in memory so that GoRouter's
      // redirect check immediately resolves to onboardingCompleted = true.
      ref.read(currentUserProvider.notifier).updateLocalProfile({
        'onboarding_completed': true,
        'full_name': _nameController.text.trim(),
        'job_title': _jobController.text.trim(),
        'company': _companyController.text.trim(),
        'phone': '$_phoneCountryCode ${_phoneController.text.trim()}',
        'avatar_url': _avatarUrl,
      });

      if (mounted) {
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Welcome to Eventzone, $firstName 👋"),
            backgroundColor: EventzoneTheme.accentSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Refresh from database in background to get everything fully updated
        ref.read(currentUserProvider.notifier).refresh();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 6),
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_step1FormKey.currentState!.validate()) return;
    }
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    } else {
      _completeOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EventzoneTheme.backgroundStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Set Up Profile".tr(),
          style: TextStyle( fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 3,
                  backgroundColor: Colors.white10,
                  color: EventzoneTheme.primaryAction,
                  minHeight: 6,
                ),
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildCurrentStepView(),
              ),
            ),

            // Bottom Navigation Actions
            Padding(
              padding: EdgeInsets.all(24.0),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _prevStep,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white12),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Text("Back".tr()),
                      ),
                    ),
                  if (_currentStep > 0) SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EventzoneTheme.primaryAction,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(_currentStep == 2 ? "Finish" : "Next"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Basics();
      case 1:
        return _buildStep2About();
      case 2:
        return _buildStep3Industries();
      default:
        return SizedBox.shrink();
    }
  }

  // Step 1: Basics
  Widget _buildStep1Basics() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 10),
          Text(
            "Profile Basics".tr(),
            style: TextStyle( fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 8),
          Text(
            "Help other attendees identify you at a glance.".tr(),
            style: TextStyle(color: Colors.white38, fontSize: 14, ),
          ),
          SizedBox(height: 32),

          // Profile Photo Picker
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundImage: _getAvatarProvider(_avatarUrl),
                  backgroundColor: Colors.white10,
                  child: _getAvatarProvider(_avatarUrl) == null
                      ? Icon(Icons.person, size: 55, color: Colors.white38)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _showImageSourceActionSheet,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EventzoneTheme.primaryAction,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.camera_alt, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 32),

          // Full Name
          Text("Full Name *".tr(), style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
          SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            style: TextStyle(color: Colors.white, fontSize: 14, ),
            decoration: InputDecoration(
              hintText: "John Doe".tr(),
              hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
              fillColor: Color(0xFF1A1E2E),
              filled: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: EventzoneTheme.primaryAction, width: 2),
              ),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Full Name is required'.tr() : null,
          ),
          SizedBox(height: 20),

          // Phone Number
          Text("Phone Number *".tr(), style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
          SizedBox(height: 6),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: Colors.white, fontSize: 14, ),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 16.0, right: 8.0),
                child: CountryCodePicker(
                  onChanged: (countryCode) {
                    if (countryCode.dialCode != null) {
                      setState(() {
                        _phoneCountryCode = countryCode.dialCode!;
                      });
                    }
                  },
                  initialSelection: _phoneCountryCode,
                  favorite: const ['+213', '+216', '+20', '+33', '+1', '+34', '+39', '+351', '+7', '+227', '+223', '+221'],
                  countryFilter: codes.map<String>((c) => c['code']!).where((code) => code != 'IL').toList(),
                  showCountryOnly: false,
                  showOnlyCountryWhenClosed: false,
                  alignLeft: false,
                  padding: EdgeInsets.zero,
                  textStyle: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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
              hintText: "234 567 8900".tr(),
              hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
              fillColor: Color(0xFF1A1E2E),
              filled: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: EventzoneTheme.primaryAction, width: 2),
              ),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Phone Number is required'.tr() : null,
          ),
          SizedBox(height: 20),

          // Job Title
          Text("Job Title".tr(), style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
          SizedBox(height: 6),
          TextFormField(
            controller: _jobController,
            style: TextStyle(color: Colors.white, fontSize: 14, ),
            decoration: InputDecoration(
              hintText: "Product Lead (Optional)".tr(),
              hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
              fillColor: Color(0xFF1A1E2E),
              filled: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: EventzoneTheme.primaryAction, width: 2),
              ),
            ),
          ),
          SizedBox(height: 20),

          // Company
          Text("Company".tr(), style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
          SizedBox(height: 6),
          TextFormField(
            controller: _companyController,
            style: TextStyle(color: Colors.white, fontSize: 14, ),
            decoration: InputDecoration(
              hintText: "TechFlow (Optional)".tr(),
              hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
              fillColor: Color(0xFF1A1E2E),
              filled: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: EventzoneTheme.primaryAction, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 2: About You
  Widget _buildStep2About() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 10),
        Text(
          "About You".tr(),
          style: TextStyle( fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 8),
        Text(
          "Share a short bio and what you're looking to achieve.".tr(),
          style: TextStyle(color: Colors.white38, fontSize: 14, ),
        ),
        SizedBox(height: 32),

        // Bio Field
        Text("Professional Bio".tr(), style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
        SizedBox(height: 8),
        TextFormField(
          controller: _bioController,
          maxLines: 4,
          maxLength: 300,
          style: TextStyle(color: Colors.white, fontSize: 14, ),
          decoration: InputDecoration(
            hintText: "Briefly tell us about your experience and background...".tr(),
            hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
            fillColor: Color(0xFF1A1E2E),
            filled: true,
            contentPadding: EdgeInsets.all(16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: EventzoneTheme.primaryAction, width: 2),
            ),
          ),
        ),
        SizedBox(height: 24),

        // What I'm Looking For Multi-select
        Text("What I'm Looking For".tr(), style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
        SizedBox(height: 12),
        Wrap(
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
              },
              backgroundColor: Color(0xFF1A1E2E),
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
      ],
    );
  }

  // Step 3: Industries & Interests
  Widget _buildStep3Industries() {
    final filteredOptions = _predefinedIndustries
        .where((opt) => opt.toLowerCase().contains(_industrySearchQuery.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 10),
        Text(
          "Industries & Interests".tr(),
          style: TextStyle( fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 8),
        Text(
          "Select up to 5 areas that match your expertise or interest.".tr(),
          style: TextStyle(color: Colors.white38, fontSize: 14, ),
        ),
        SizedBox(height: 24),

        // Search Box
        TextField(
          style: TextStyle(color: Colors.white, fontSize: 14, ),
          decoration: InputDecoration(
            hintText: "Search areas...".tr(),
            hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.white38, size: 20),
            fillColor: Color(0xFF1A1E2E),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (val) {
            setState(() {
              _industrySearchQuery = val;
            });
          },
        ),
        SizedBox(height: 20),

        // Selected counter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Popular Tags".tr(),
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, ),
            ),
            Text(
              "${_selectedIndustries.length} of 5 selected",
              style: TextStyle(
                color: _selectedIndustries.length == 5 ? EventzoneTheme.accentSuccess : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                
              ),
            ),
          ],
        ),
        SizedBox(height: 12),

        // Grid/Wrap of all options
        Wrap(
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
                        SnackBar(
                          content: Text("You can select up to 5 tags maximum.".tr()),
                          backgroundColor: Colors.amber,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    _selectedIndustries.add(option);
                    _selectedInterests.add(option); // fill both for compatibility
                  }
                });
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? EventzoneTheme.primaryAction.withOpacity(0.2) 
                      : Color(0xFF1A1E2E),
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
                      Icon(Icons.check, size: 14, color: Colors.white),
                      SizedBox(width: 6),
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
        SizedBox(height: 24),
      ],
    );
  }

}
