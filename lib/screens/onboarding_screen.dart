import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/eventzone_theme.dart';
import '../providers/auth_providers.dart';

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
    'HealthTech', 'EdTech', 'CleanTech & Energy', 'E-Commerce', 'SaaS',
    'Venture Capital', 'Angel Investing', 'Product Management', 'Software Engineering',
    'UX/UI Design', 'Digital Marketing', 'Sales & Business Dev', 'Cloud Computing',
    'Data Science', 'Mobile Development', 'AR/VR', 'IoT (Internet of Things)',
    'Game Development', 'Robotics', 'Aerospace', 'HR & Recruiting', 'Legal Tech',
    'PropTech', 'InsurTech', 'Media & Entertainment', 'BioTech', 'Devops & SRE', 'ClimateTech'
  ];
  String _industrySearchQuery = "";
  final List<String> _selectedIndustries = [];
  final List<String> _selectedInterests = [];

  // Step 4: Social Links
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();
  final _whatsappController = TextEditingController();
  String _whatsappCountryCode = '+1';
  final _websiteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Prefill user details if available
    Future.microtask(() {
      final profile = ref.read(currentUserProvider).value;
      if (profile != null) {
        setState(() {
          _nameController.text = profile['full_name'] ?? '';
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
    _jobController.dispose();
    _companyController.dispose();
    _bioController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    _whatsappController.dispose();
    _websiteController.dispose();
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
      backgroundColor: const Color(0xFF141927),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white70),
              title: const Text('Photo Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white70),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
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

    final socialLinks = {
      if (_linkedinController.text.trim().isNotEmpty) 'linkedin': _linkedinController.text.trim(),
      if (_githubController.text.trim().isNotEmpty) 'github': _githubController.text.trim(),
      if (_whatsappController.text.trim().isNotEmpty) 'whatsapp': '$_whatsappCountryCode ${_whatsappController.text.trim()}',
      if (_websiteController.text.trim().isNotEmpty) 'website': _websiteController.text.trim(),
    };

    final errorMessage = await ref.read(currentUserProvider.notifier).updateProfileData(
      fullName: _nameController.text.trim(),
      jobTitle: _jobController.text.trim(),
      company: _companyController.text.trim(),
      avatarUrl: _avatarUrl,
      bio: _bioController.text.trim(),
      whatImLookingFor: _selectedLookingFor.join(', '),
      industries: _selectedIndustries,
      interests: _selectedInterests,
      socialLinks: socialLinks,
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
            duration: const Duration(seconds: 6),
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
    if (_currentStep < 3) {
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
        title: const Text(
          "Set Up Profile",
          style: TextStyle( fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          if (_currentStep == 3) // Step 4 (Social Connections) is optional
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      _linkedinController.clear();
                      _githubController.clear();
                      _whatsappController.clear();
                      _websiteController.clear();
                      _completeOnboarding();
                    },
              child: const Text(
                "Skip",
                style: TextStyle(
                  color: EventzoneTheme.primaryAction,
                  fontWeight: FontWeight.bold,
                  
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 4,
                  backgroundColor: Colors.white10,
                  color: EventzoneTheme.primaryAction,
                  minHeight: 6,
                ),
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildCurrentStepView(),
              ),
            ),

            // Bottom Navigation Actions
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _prevStep,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white12),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text("Back"),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EventzoneTheme.primaryAction,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(_currentStep == 3 ? "Finish" : "Next"),
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
      case 3:
        return _buildStep4Socials();
      default:
        return const SizedBox.shrink();
    }
  }

  // Step 1: Basics
  Widget _buildStep1Basics() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const Text(
            "Profile Basics",
            style: TextStyle( fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            "Help other attendees identify you at a glance.",
            style: TextStyle(color: Colors.white38, fontSize: 14, ),
          ),
          const SizedBox(height: 32),

          // Profile Photo Picker
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundImage: _getAvatarProvider(_avatarUrl),
                  backgroundColor: Colors.white10,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _showImageSourceActionSheet,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: EventzoneTheme.primaryAction,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Full Name
          const Text("Full Name", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 14, ),
            decoration: InputDecoration(
              hintText: "John Doe",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
              fillColor: const Color(0xFF1A1E2E),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: EventzoneTheme.primaryAction, width: 2),
              ),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Full Name is required' : null,
          ),
          const SizedBox(height: 20),

          // Job Title
          const Text("Job Title", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
          const SizedBox(height: 6),
          TextFormField(
            controller: _jobController,
            style: const TextStyle(color: Colors.white, fontSize: 14, ),
            decoration: InputDecoration(
              hintText: "Product Lead",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
              fillColor: const Color(0xFF1A1E2E),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: EventzoneTheme.primaryAction, width: 2),
              ),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Job Title is required' : null,
          ),
          const SizedBox(height: 20),

          // Company
          const Text("Company", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
          const SizedBox(height: 6),
          TextFormField(
            controller: _companyController,
            style: const TextStyle(color: Colors.white, fontSize: 14, ),
            decoration: InputDecoration(
              hintText: "TechFlow",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
              fillColor: const Color(0xFF1A1E2E),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: EventzoneTheme.primaryAction, width: 2),
              ),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? 'Company is required' : null,
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
        const SizedBox(height: 10),
        const Text(
          "About You",
          style: TextStyle( fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          "Share a short bio and what you're looking to achieve.",
          style: TextStyle(color: Colors.white38, fontSize: 14, ),
        ),
        const SizedBox(height: 32),

        // Bio Field
        const Text("Professional Bio", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bioController,
          maxLines: 4,
          maxLength: 300,
          style: const TextStyle(color: Colors.white, fontSize: 14, ),
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
        const SizedBox(height: 24),

        // What I'm Looking For Multi-select
        const Text("What I'm Looking For", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
        const SizedBox(height: 12),
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
        const SizedBox(height: 10),
        const Text(
          "Industries & Interests",
          style: TextStyle( fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          "Select up to 5 areas that match your expertise or interest.",
          style: TextStyle(color: Colors.white38, fontSize: 14, ),
        ),
        const SizedBox(height: 24),

        // Search Box
        TextField(
          style: const TextStyle(color: Colors.white, fontSize: 14, ),
          decoration: InputDecoration(
            hintText: "Search areas...",
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
        const SizedBox(height: 20),

        // Selected counter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Popular Tags",
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
        const SizedBox(height: 12),

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
                        const SnackBar(
                          content: Text("You can select up to 5 tags maximum."),
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
        const SizedBox(height: 24),
      ],
    );
  }

  // Step 4: Social Links
  Widget _buildStep4Socials() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        const Text(
          "Social Connections",
          style: TextStyle( fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          "Add your online profiles so others can follow up with you (Optional).",
          style: TextStyle(color: Colors.white38, fontSize: 14, ),
        ),
        const SizedBox(height: 32),

        // LinkedIn
        const Text("LinkedIn", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
        const SizedBox(height: 6),
        TextField(
          controller: _linkedinController,
          style: const TextStyle(color: Colors.white, fontSize: 14, ),
          decoration: InputDecoration(
            hintText: "linkedin.com/in/username",
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
            fillColor: const Color(0xFF1A1E2E),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: EventzoneTheme.primaryAction, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // GitHub
        const Text("GitHub", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
        const SizedBox(height: 6),
        TextField(
          controller: _githubController,
          style: const TextStyle(color: Colors.white, fontSize: 14, ),
          decoration: InputDecoration(
            hintText: "github.com/username",
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
            fillColor: const Color(0xFF1A1E2E),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: EventzoneTheme.primaryAction, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // WhatsApp
        const Text("WhatsApp Number", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
        const SizedBox(height: 6),
        TextField(
          controller: _whatsappController,
          style: const TextStyle(color: Colors.white, fontSize: 14, ),
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 8.0),
              child: CountryCodePicker(
                onChanged: (countryCode) {
                  if (countryCode.dialCode != null) {
                    setState(() {
                      _whatsappCountryCode = countryCode.dialCode!;
                    });
                  }
                },
                initialSelection: _whatsappCountryCode,
                favorite: const ['+1', '+44'],
                showCountryOnly: false,
                showOnlyCountryWhenClosed: false,
                alignLeft: false,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                dialogTextStyle: const TextStyle(color: Colors.white),
                dialogBackgroundColor: const Color(0xFF141927),
                searchStyle: const TextStyle(color: Colors.white),
                searchDecoration: const InputDecoration(
                  hintText: "Search country",
                  hintStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.search, color: Colors.white54),
                ),
                closeIcon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            hintText: "555-5555",
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
            fillColor: const Color(0xFF1A1E2E),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: EventzoneTheme.primaryAction, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Personal/Company Website
        const Text("Website URL", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, )),
        const SizedBox(height: 6),
        TextField(
          controller: _websiteController,
          style: const TextStyle(color: Colors.white, fontSize: 14, ),
          decoration: InputDecoration(
            hintText: "https://yourwebsite.com",
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
            fillColor: const Color(0xFF1A1E2E),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: EventzoneTheme.primaryAction, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
