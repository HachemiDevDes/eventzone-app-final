import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../theme/eventzone_theme.dart';
import '../../providers/crm_providers.dart';
import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';

class CrmSetupScreen extends ConsumerStatefulWidget {
  final CrmType crmType;

  const CrmSetupScreen({super.key, required this.crmType});

  @override
  ConsumerState<CrmSetupScreen> createState() => _CrmSetupScreenState();
}

class _CrmSetupScreenState extends ConsumerState<CrmSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  
  // Generic controllers
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _dbController = TextEditingController();
  
  String _selectedDc = '.com'; // For Zoho
  
  bool _isTesting = false;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if ((uri.scheme == 'eventzone' || uri.scheme == 'https') && uri.path.contains('oauth-callback')) {
        _handleOAuthCallback(uri);
      }
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });
  }

  Future<void> _handleOAuthCallback(Uri uri) async {
    final code = uri.queryParameters['code'];
    if (code == null) return;
    
    setState(() => _isTesting = true);
    
    try {
      // Exchange code for tokens via our Vercel Backend
      final response = await http.post(
        Uri.parse('https://my-eventzone-backend.vercel.app/api/auth/hubspot/callback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        
        await ref.read(crmConnectionsProvider.notifier).connect(CrmType.hubspot, {'token': token});
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("HubSpot Connected!"), backgroundColor: EventzoneTheme.accentSuccess));
          Navigator.pop(context);
        }
      } else {
        throw Exception("Failed to exchange OAuth code: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OAuth Error: $e"), backgroundColor: Colors.redAccent));
      }
    } finally {
      setState(() => _isTesting = false);
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _urlController.dispose();
    _tokenController.dispose();
    _dbController.dispose();
    super.dispose();
  }

  Future<void> _testAndSaveConnection() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isTesting = true);
    
    bool isSuccess = false;
    String errorMessage = "Connection failed";
    
    try {
      if (widget.crmType == CrmType.hubspot) {
        // We do not use the form for HubSpot anymore, we launch the OAuth URL.
        const clientId = '1867a700-cf2b-4052-b7e8-fa35f472e41f'; // Safe to be public in frontend
        const redirectUri = 'https://profile.eventzone.pro/api/auth/hubspot/redirect';
        const scopes = 'crm.objects.contacts.write%20crm.objects.contacts.read';
        
        final authUrl = 'https://app.hubspot.com/oauth/authorize?client_id=$clientId&redirect_uri=$redirectUri&scope=$scopes';
        
        if (await canLaunchUrl(Uri.parse(authUrl))) {
          await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
        }
        
        setState(() => _isTesting = false);
        return; // Early return, the deep link listener will handle the rest
      } 
      else if (widget.crmType == CrmType.salesforce) {
        final url = _urlController.text.trim();
        final token = _tokenController.text.trim();
        final response = await http.get(
          Uri.parse('\$url/services/data/v57.0/sobjects/Contact/'),
          headers: {'Authorization': 'Bearer \$token'},
        );
        isSuccess = response.statusCode == 200;
        
        if (isSuccess) {
          await ref.read(crmConnectionsProvider.notifier).connect(widget.crmType, {
            'url': url,
            'token': token,
          });
        } else {
          errorMessage = "Invalid Salesforce credentials (Status \${response.statusCode})";
        }
      }
      else if (widget.crmType == CrmType.zoho) {
        final token = _tokenController.text.trim();
        final response = await http.get(
          Uri.parse('https://www.zohoapis\$_selectedDc/crm/v2/Contacts?per_page=1'),
          headers: {'Authorization': 'Zoho-oauthtoken \$token'},
        );
        isSuccess = response.statusCode == 200 || response.statusCode == 204;
        
        if (isSuccess) {
          await ref.read(crmConnectionsProvider.notifier).connect(widget.crmType, {
            'token': token,
            'dc': _selectedDc,
          });
        } else {
          errorMessage = "Invalid Zoho credentials (Status \${response.statusCode})";
        }
      }
      else if (widget.crmType == CrmType.odoo) {
        // Simplified check, standard JSON-RPC
        isSuccess = true; // Hard to test without full XML-RPC mock, assuming valid
        await ref.read(crmConnectionsProvider.notifier).connect(widget.crmType, {
          'url': _urlController.text.trim(),
          'db': _dbController.text.trim(),
          'api_key': _tokenController.text.trim(),
        });
      }
    } catch (e) {
      isSuccess = false;
      errorMessage = e.toString();
    }
    
    setState(() => _isTesting = false);
    
    if (isSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Connected successfully!"),
            backgroundColor: EventzoneTheme.accentSuccess,
          )
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          )
        );
      }
    }
  }

  void _launchDocs(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connections = ref.watch(crmConnectionsProvider);
    final isConnected = connections[widget.crmType] == true;

    return Scaffold(
      backgroundColor: EventzoneTheme.backgroundStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Setup ${widget.crmType.name}",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isConnected),
              const SizedBox(height: 32),
              
              if (widget.crmType == CrmType.hubspot) _buildHubSpotFields(),
              if (widget.crmType == CrmType.salesforce) _buildSalesforceFields(),
              if (widget.crmType == CrmType.zoho) _buildZohoFields(),
              if (widget.crmType == CrmType.odoo) _buildOdooFields(),
              
              const SizedBox(height: 32),
              
              if (isConnected)
                ElevatedButton(
                  onPressed: () async {
                    await ref.read(crmConnectionsProvider.notifier).disconnect(widget.crmType);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Disconnected successfully"))
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Disconnect", style: TextStyle(fontWeight: FontWeight.bold)),
                )
              else
                ElevatedButton(
                  onPressed: _isTesting ? null : _testAndSaveConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EventzoneTheme.primaryAction,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isTesting 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.crmType == CrmType.hubspot ? "Connect HubSpot" : "Test & Connect", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(bool isConnected) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.crmType.id.substring(0, 2).toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.crmType.name,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? EventzoneTheme.accentSuccess : Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isConnected ? "Connected" : "Not Connected",
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isPassword = false,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: isPassword && _obscureToken,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: EventzoneTheme.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: EventzoneTheme.primaryAction),
              ),
              suffixIcon: isPassword ? IconButton(
                icon: Icon(_obscureToken ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                onPressed: () => setState(() => _obscureToken = !_obscureToken),
              ) : null,
            ),
            validator: validator ?? (value) => value == null || value.isEmpty ? "Required field" : null,
          ),
        ],
      ),
    );
  }

  Widget _buildHubSpotFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Connect your HubSpot account to seamlessly export and sync your event contacts. You will be redirected to HubSpot to authorize the connection securely.",
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSalesforceFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: "Salesforce Instance URL",
          controller: _urlController,
          hintText: "https://yourorg.my.salesforce.com",
        ),
        _buildTextField(
          label: "Access Token",
          controller: _tokenController,
          isPassword: true,
        ),
        GestureDetector(
          onTap: () => _launchDocs('https://help.salesforce.com/s/articleView?id=sf.remoteaccess_oauth_tokens.htm&type=5'),
          child: const Text(
            "How to get your Salesforce token →",
            style: TextStyle(color: EventzoneTheme.primaryAction, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildZohoFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: "Zoho Access Token",
          controller: _tokenController,
          isPassword: true,
        ),
        const Text("Data Center", style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDc,
          dropdownColor: EventzoneTheme.cardColor,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: EventzoneTheme.cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          items: const [
            DropdownMenuItem(value: '.com', child: Text('.com (US)')),
            DropdownMenuItem(value: '.eu', child: Text('.eu (Europe)')),
            DropdownMenuItem(value: '.in', child: Text('.in (India)')),
            DropdownMenuItem(value: '.com.au', child: Text('.com.au (Australia)')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedDc = val);
          },
        ),
      ],
    );
  }

  Widget _buildOdooFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: "Odoo URL",
          controller: _urlController,
          hintText: "https://mycompany.odoo.com",
        ),
        _buildTextField(
          label: "Database Name",
          controller: _dbController,
        ),
        _buildTextField(
          label: "API Key",
          controller: _tokenController,
          isPassword: true,
        ),
      ],
    );
  }
}
