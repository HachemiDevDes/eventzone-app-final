import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/settings_providers.dart';
import 'package:chargily_pay/chargily_pay.dart';
import '../../../theme/eventzone_theme.dart';
import '../../widgets/glass_container.dart';
// ignore: depend_on_referenced_packages
import '../../widgets/custom_checkout_view.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math' as math;

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  final TextEditingController _promoController = TextEditingController();
  bool _isCheckingPromo = false;
  String? _promoError;
  String? _appliedPromoCode;
  int _discountPercentage = 0;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _promoController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isCheckingPromo = true;
      _promoError = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('promo_codes')
          .select('discount_percentage')
          .eq('code', code)
          .eq('is_active', true)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _appliedPromoCode = code;
          _discountPercentage = response['discount_percentage'] as int;
          _promoError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promo code applied successfully!'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: EventzoneTheme.accentSuccess,
          )
        );
      } else {
        setState(() {
          _promoError = 'Invalid or inactive promo code'.tr();
          _appliedPromoCode = null;
          _discountPercentage = 0;
        });
      }
    } catch (e) {
      setState(() {
        _promoError = 'Error checking promo code'.tr();
        _appliedPromoCode = null;
        _discountPercentage = 0;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPromo = false;
        });
      }
    }
  }

  String _formatPrice(int price) {
    return NumberFormat('#,##0', 'en_US').format(price);
  }

  Future<void> _mockPurchase(int planMonths, int price, String planName) async {
    int finalPrice = price;
    if (_discountPercentage > 0) {
      finalPrice = price - (price * _discountPercentage ~/ 100);
      if (finalPrice < 100) finalPrice = 100; // minimum amount
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: 24,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 20,
          top: 12,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 24),
            Icon(LucideIcons.creditCard, size: 48, color: EventzoneTheme.primaryAction),
            SizedBox(height: 16),
            Text(
              'Purchase $planName Plan?'.tr(),
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 16),
            if (_discountPercentage > 0)
              Text(
                'Originally ${_formatPrice(price)} DZD'.tr(),
                style: TextStyle(color: Colors.white54, fontSize: 14, decoration: TextDecoration.lineThrough),
              ),
            Text(
              'for ${_formatPrice(finalPrice)} DZD'.tr(),
              style: TextStyle(color: _discountPercentage > 0 ? EventzoneTheme.accentSuccess : Colors.white60, fontSize: _discountPercentage > 0 ? 20 : 16, fontWeight: _discountPercentage > 0 ? FontWeight.w800 : FontWeight.w500),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: EventzoneTheme.primaryAction.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: EventzoneTheme.primaryAction.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  Text(
                    planName,
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'for ${_formatPrice(price)} DZD',
              style: TextStyle(color: Colors.white60, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 24),
            // Payment logos
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMiniPaymentBadge('assets/images/cib_logo.png'),
                SizedBox(width: 12),
                _buildMiniPaymentBadge('assets/images/dahabia_logo.png'),
              ],
            ),
            SizedBox(height: 32),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text('Cancel'.tr(), style: TextStyle(color: Colors.white60, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EventzoneTheme.primaryAction,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: Text('Confirm'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(color: EventzoneTheme.primaryAction),
          ),
        );

        final Map<String, dynamic> requestBody = {
          'amount': price,
          'plan_months': planMonths,
        };
        if (_appliedPromoCode != null) {
          requestBody['promo_code'] = _appliedPromoCode!;
        }

        final response = await Supabase.instance.client.functions.invoke(
          'chargily-create-checkout',
          body: requestBody,
        );

        if (response.status != 200) {
          throw Exception('Edge Function Error: ${response.data}');
        }

        final responseData = response.data as Map<String, dynamic>;
        
        if (responseData['checkout_url'] != null) {
          String checkoutUrl = responseData['checkout_url'];
          checkoutUrl = checkoutUrl.replaceFirst('http://', 'https://');
          checkoutUrl = checkoutUrl.replaceFirst('pay.chargily.dz', 'pay.chargily.net');
          responseData['checkout_url'] = checkoutUrl;
        }

        final checkout = Checkout.fromJson(responseData);

        // Dismiss loading dialog
        if (mounted) Navigator.pop(context);

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomCheckoutView(
                checkout: checkout,
                onPaymentSuccess: () async {
                  if (mounted) {
                    Navigator.of(context).pop(); // Close checkout view
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Confirming your payment…'.tr()),
                          ],
                        ),
                        duration: Duration(seconds: 30),
                        backgroundColor: EventzoneTheme.primaryAction,
                      ),
                    );
                  }

                  try {
                    // Call edge function to verify with Chargily and activate subscription
                    final confirmResponse = await Supabase.instance.client.functions.invoke(
                      'confirm-subscription',
                      body: {
                        'checkout_id': checkout.id,
                        'plan_months': planMonths,
                      },
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    }

                    if (confirmResponse.status == 200) {
                      // Force refresh the subscription status provider
                      ref.invalidate(subscriptionStatusProvider);

                      if (mounted) {
                        final data = confirmResponse.data as Map<String, dynamic>;
                        final daysRemaining = data['days_remaining'] ?? '';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(LucideIcons.checkCircle, color: Colors.white, size: 20),
                                SizedBox(width: 12),
                                Expanded(child: Text('Successfully subscribed to $planName! ($daysRemaining days remaining)')),
                              ],
                            ),
                            backgroundColor: EventzoneTheme.accentSuccess,
                            duration: Duration(seconds: 5),
                          ),
                        );
                      }
                    } else {
                      throw Exception(confirmResponse.data?['error'] ?? 'Verification failed');
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not confirm payment: ${e.toString()}'),
                          backgroundColor: Colors.redAccent,
                          duration: Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                },
                onPaymentFailure: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Payment was failed or cancelled.'.tr()), backgroundColor: Colors.redAccent),
                  );
                },
                onPaymentCancel: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          );
        }
      } catch (e) {
        // Dismiss loading dialog if error happens before it was dismissed
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment initiation failed: ${e.toString()}'), 
              backgroundColor: Colors.redAccent
            ),
          );
        }
      }
    }
  }

  Widget _buildMiniPaymentBadge(String assetPath) {
    return Container(
      width: 48,
      height: 32,
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B), // Dark slate
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }

  Widget build(BuildContext context) {
    final subStatusAsync = ref.watch(subscriptionStatusProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final appConfigAsync = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Subscription'.tr(), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A1628),
              Color(0xFF060E1A),
              Color(0xFF030812),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status Card ──
                _buildStatusCard(subStatusAsync),

                SizedBox(height: 28),

                // ── Section Header ──
                Text(
                  'Choose a Plan'.tr(),
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 16),

                // ── Promo Code ──
                _buildPromoCodeSection(),
                
                SizedBox(height: 24),

                // ── Subscription Options ──
                appConfigAsync.when(
                  data: (config) {
                    final basicPrice = int.tryParse(config['plan_basic_price'] ?? '500') ?? 500;
                    final popPrice = int.tryParse(config['plan_popular_price'] ?? '2500') ?? 2500;
                    final premPrice = int.tryParse(config['plan_premium_price'] ?? '5000') ?? 5000;
                    final popFree = config['plan_popular_free_months'] ?? '1 MONTH FREE';
                    final premFree = config['plan_premium_free_months'] ?? '2 MONTHS FREE';
                    
                    return Column(
                      children: [
                        _buildPurchaseCard(
                          planMonths: 1,
                          price: basicPrice,
                          packName: 'Basic',
                          displayValue: '1 Month',
                          iconColor: Color(0xFF60A5FA),
                          gradientColors: [Color(0xFF1E3A5F), Color(0xFF0F2136)],
                        ),
                        SizedBox(height: 12),
                        _buildPurchaseCard(
                          planMonths: 6,
                          price: popPrice,
                          packName: 'Popular',
                          displayValue: '6 Months',
                          badge: popFree.isNotEmpty ? popFree : null,
                          iconColor: Color(0xFFFB923C),
                          gradientColors: [Color(0xFF2D1B4E), Color(0xFF1A1040)],
                          isHighlighted: true,
                        ),
                        SizedBox(height: 12),
                        _buildPurchaseCard(
                          planMonths: 12,
                          price: premPrice,
                          packName: 'Premium',
                          displayValue: '12 Months',
                          badge: premFree.isNotEmpty ? premFree : null,
                          iconColor: Color(0xFFFFD700),
                          gradientColors: [Color(0xFF1A3A2F), Color(0xFF0F2420)],
                        ),
                      ],
                    );
                  },
                  loading: () => Container(
                    padding: EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(color: EventzoneTheme.primaryAction, strokeWidth: 3),
                  ),
                  error: (err, stack) => Text(
                    'Failed to load plans.'.tr(),
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),

                SizedBox(height: 24),

                // ── Payment Methods ──
                _buildPaymentMethodsSection(),

                SizedBox(height: 28),

                // ── Transaction History ──
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EventzoneTheme.accentSuccess.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(LucideIcons.history, color: EventzoneTheme.accentSuccess, size: 18),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Transaction History'.tr(),
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                _buildTransactionHistory(transactionsAsync),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Status Card ──
  Widget _buildStatusCard(AsyncValue<SubscriptionStatus> subStatusAsync) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A2B4A),
                Color(0xFF0E1B32),
                Color(0xFF0A1425),
              ],
            ),
            border: Border.all(
              color: EventzoneTheme.primaryAction.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: EventzoneTheme.primaryAction.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: subStatusAsync.when(
            data: (status) {
              final String labelText = status.isActive
                  ? (status.isTrial ? 'FREE TRIAL ACTIVE'.tr() : 'SUBSCRIPTION ACTIVE'.tr())
                  : 'SUBSCRIPTION EXPIRED'.tr();
                  
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: status.isActive ? EventzoneTheme.accentSuccess : Colors.redAccent,
                          boxShadow: [
                            BoxShadow(
                              color: (status.isActive ? EventzoneTheme.accentSuccess : Colors.redAccent).withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        labelText,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (status.isActive) ...[
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Color(0xFF60A5FA), Color(0xFF818CF8), Color(0xFFA78BFA)],
                      ).createShader(bounds),
                      child: Text(
                        '${status.daysRemaining}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'days remaining'.tr(),
                      style: TextStyle(color: Colors.white30, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ] else ...[
                    Text(
                      'Expired'.tr(),
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please choose a plan to continue'.tr(),
                      style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                  SizedBox(height: 16),

                ],
              );
            },
            loading: () => SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction, strokeWidth: 3)),
            ),
            error: (_, _) => SizedBox(
              height: 150,
              child: Center(child: Text('Error loading status'.tr(), style: TextStyle(color: Colors.redAccent))),
            ),
          ),
        );
      },
    );
  }

  // ── Purchase Card ──
  Widget _buildPurchaseCard({
    required int planMonths,
    required int price,
    required String packName,
    required String displayValue,
    String? badge,
    required Color iconColor,
    required List<Color> gradientColors,
    bool isHighlighted = false,
  }) {
    return GestureDetector(
      onTap: () => _mockPurchase(planMonths, price, displayValue),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          border: Border.all(
            color: isHighlighted
                ? iconColor.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
            width: isHighlighted ? 1.5 : 1,
          ),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        packName.tr().toUpperCase(),
                        style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                      ),
                      if (badge != null) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            badge.tr(),
                            style: TextStyle(color: iconColor, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        displayValue.tr(),
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_discountPercentage > 0)
                        Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Text(
                            '${_formatPrice(price)}',
                            style: TextStyle(color: Colors.white38, fontSize: 14, decoration: TextDecoration.lineThrough),
                          ),
                        ),
                      Text(
                        '${_formatPrice(_discountPercentage > 0 ? math.max(100, price - (price * _discountPercentage ~/ 100)) : price)} ${'DZD'.tr()}',
                        style: TextStyle(color: _discountPercentage > 0 ? EventzoneTheme.accentSuccess : Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Buy button
            Container(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: EventzoneTheme.primaryAction,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: EventzoneTheme.primaryAction.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Choose'.tr(),
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Payment Methods Section ──
  Widget _buildPaymentMethodsSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Color(0xFF0E1726),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.shield, color: EventzoneTheme.accentSuccess, size: 16),
              SizedBox(width: 8),
              Text(
                'Secure Payment Methods'.tr(),
                style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // CIB Logo
              _buildPaymentBadge(
                assetPath: 'assets/images/cib_logo.png',
                label: 'CIB',
              ),
              SizedBox(width: 16),
              // Dahabia Logo
              _buildPaymentBadge(
                assetPath: 'assets/images/dahabia_logo.png',
                label: 'Dahabia',
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.lock, color: Colors.white.withValues(alpha: 0.2), size: 12),
              SizedBox(width: 6),
              Text(
                'Your payment is encrypted and secure'.tr(),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge({required String assetPath, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B), // Dark slate
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 32,
            width: 80,
            child: Image.asset(assetPath, fit: BoxFit.contain),
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  // ── Transaction History ──
  Widget _buildTransactionHistory(AsyncValue<List<Map<String, dynamic>>> transactionsAsync) {
    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: Color(0xFF0E1726),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.receipt, color: Colors.white.withValues(alpha: 0.15), size: 32),
                ),
                SizedBox(height: 16),
                Text(
                  "No transactions yet".tr(),
                  style: TextStyle(color: Colors.white30, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4),
                Text(
                  "Your purchase history will appear here".tr(),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.15), fontSize: 12),
                ),
              ],
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFF0E1726),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.white.withValues(alpha: 0.04),
              height: 1,
              indent: 68,
            ),
            itemBuilder: (context, index) {
              final t = transactions[index];
              final isPurchase = t['type'] == 'purchase';
              final amount = t['amount'];
              final date = (t['created_at'] ?? '').toString().split('T').first;

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isPurchase ? EventzoneTheme.accentSuccess : EventzoneTheme.accentWarning).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPurchase ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                        color: isPurchase ? EventzoneTheme.accentSuccess : EventzoneTheme.accentWarning,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (t['description'] ?? 'Transaction').toString().tr(),
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 2),
                          Text(
                            date,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (amount != null)
                      Text(
                        "${isPurchase ? '+' : ''}$amount DZD",
                        style: TextStyle(
                          color: isPurchase ? EventzoneTheme.accentSuccess : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction)),
      error: (e, _) => Center(child: Text('Error loading history: $e', style: TextStyle(color: Colors.redAccent))),
    );
  }

  Widget _buildPromoCodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Promo Code'.tr(),
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _promoController,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Enter code'.tr(),
                  hintStyle: TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: EventzoneTheme.primaryAction.withOpacity(0.5)),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isCheckingPromo ? null : _applyPromoCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: EventzoneTheme.primaryAction,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isCheckingPromo
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Apply'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (_promoError != null)
          Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Text(
              _promoError!,
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        if (_appliedPromoCode != null && _discountPercentage > 0)
          Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Text(
              '${_discountPercentage}% discount applied!'.tr(),
              style: TextStyle(color: EventzoneTheme.accentSuccess, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
