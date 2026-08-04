import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'review_contact_screen.dart';
import '../theme/eventzone_theme.dart';

class ProfileDeepLinkHandlerScreen extends StatefulWidget {
  final String? profileId;

  const ProfileDeepLinkHandlerScreen({super.key, required this.profileId});

  @override
  State<ProfileDeepLinkHandlerScreen> createState() => _ProfileDeepLinkHandlerScreenState();
}

class _ProfileDeepLinkHandlerScreenState extends State<ProfileDeepLinkHandlerScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    if (widget.profileId == null) {
      setState(() {
        _error = "Invalid profile link.";
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', widget.profileId!)
          .single();

      if (mounted) {
        final metadata = response['metadata'] ?? {};
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ReviewContactScreen(
              initialName: response['full_name'] ?? '',
              initialTitle: response['job_title'] ?? '',
              initialEmail: metadata['email'] ?? '',
              initialPhone: metadata['phone'] ?? '',
              initialWebsite: metadata['website'] ?? '',
              initialCompany: response['company_name'] ?? '',
              initialDepartment: metadata['department'] ?? '',
              initialAddress: metadata['address'] ?? '',
              source: 'Deep Link / Web Profile',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Could not load profile.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EventzoneTheme.backgroundEnd,
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : Text(
                _error ?? "Unknown error",
                style: TextStyle(color: Colors.white),
              ),
      ),
    );
  }
}
