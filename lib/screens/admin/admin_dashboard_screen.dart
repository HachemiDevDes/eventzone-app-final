import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/eventzone_theme.dart';
import 'package:easy_localization/easy_localization.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _promoCodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPromoCodes();
  }

  Future<void> _fetchPromoCodes() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('promo_codes').select().order('created_at', ascending: false);
      setState(() {
        _promoCodes = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading promo codes: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createPromoCode(String code, int discount) async {
    try {
      await _supabase.from('promo_codes').insert({
        'code': code.toUpperCase(),
        'discount_percentage': discount,
      });
      _fetchPromoCodes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating promo code: $e')));
    }
  }

  Future<void> _togglePromoCode(String id, bool currentStatus) async {
    try {
      await _supabase.from('promo_codes').update({'is_active': !currentStatus}).eq('id', id);
      _fetchPromoCodes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating promo code: $e')));
    }
  }

  void _showCreatePromoCodeDialog() {
    final codeController = TextEditingController();
    final discountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Color(0xFF1E293B),
          title: Text('Create Promo Code'.tr(), style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Code Name'.tr(),
                  labelStyle: TextStyle(color: Colors.white60),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: EventzoneTheme.primaryAction)),
                ),
                style: TextStyle(color: Colors.white),
              ),
              TextField(
                controller: discountController,
                decoration: InputDecoration(
                  labelText: 'Discount Percentage (1-100)'.tr(),
                  labelStyle: TextStyle(color: Colors.white60),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: EventzoneTheme.primaryAction)),
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.tr(), style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                final code = codeController.text.trim();
                final discount = int.tryParse(discountController.text.trim());
                if (code.isNotEmpty && discount != null && discount > 0 && discount <= 100) {
                  Navigator.pop(context);
                  _createPromoCode(code, discount);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: EventzoneTheme.primaryAction),
              child: Text('Create'.tr()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'.tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: EventzoneTheme.buildPlayfulBackground(
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Promo Codes'.tr(), style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          ElevatedButton.icon(
                            onPressed: _showCreatePromoCodeDialog,
                            icon: Icon(LucideIcons.plus, size: 18),
                            label: Text('New'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EventzoneTheme.primaryAction,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Expanded(
                        child: _promoCodes.isEmpty
                            ? Center(child: Text('No promo codes found.'.tr(), style: TextStyle(color: Colors.white60)))
                            : ListView.builder(
                                itemCount: _promoCodes.length,
                                itemBuilder: (context, index) {
                                  final code = _promoCodes[index];
                                  final bool isActive = code['is_active'];
                                  return Card(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    margin: EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      title: Text(
                                        code['code'],
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(height: 4),
                                          Text('${code['discount_percentage']}% Discount'.tr(), style: TextStyle(color: EventzoneTheme.accentSuccess)),
                                          Text('${'Uses:'.tr()} ${code['usage_count']}', style: TextStyle(color: Colors.white70)),
                                        ],
                                      ),
                                      trailing: Switch(
                                        value: isActive,
                                        activeColor: EventzoneTheme.primaryAction,
                                        onChanged: (val) => _togglePromoCode(code['id'], isActive),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
