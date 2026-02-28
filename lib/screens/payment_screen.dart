import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../config/app_config.dart';
import '../config/monetization_config.dart';
import '../services/billing_verification_service.dart';
import '../services/entitlement_service.dart';
import '../services/razorpay_service.dart';
import '../theme/app_theme.dart';
import '../widgets/action_dialog.dart';
import '../widgets/primary_button.dart';

enum PremiumPlanType { monthly, yearly }

extension PremiumPlanTypeX on PremiumPlanType {
  String get label {
    switch (this) {
      case PremiumPlanType.monthly:
        return 'Premium Monthly';
      case PremiumPlanType.yearly:
        return 'Premium Yearly';
    }
  }

  String get apiValue {
    switch (this) {
      case PremiumPlanType.monthly:
        return 'monthly';
      case PremiumPlanType.yearly:
        return 'yearly';
    }
  }

  int get amountInr {
    switch (this) {
      case PremiumPlanType.monthly:
        return MonetizationConfig.premiumMonthlyInr;
      case PremiumPlanType.yearly:
        return MonetizationConfig.premiumYearlyInr;
    }
  }
}

class PaymentScreen extends StatefulWidget {
  final String featureName;

  const PaymentScreen({super.key, required this.featureName});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final EntitlementService _entitlementService = EntitlementService();
  final BillingVerificationService _billingVerificationService =
      BillingVerificationService();

  bool _isProcessing = false;
  PremiumPlanType? _selectedPlan;

  RazorpayService? _razorpayService;

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService(
      onSuccess: _onPaymentSuccess,
      onFailure: _onPaymentError,
      onExternalWallet: _onExternalWallet,
    );
  }

  @override
  void dispose() {
    _razorpayService?.dispose();
    super.dispose();
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId;
    final selectedPlan = _selectedPlan;

    if (paymentId == null || paymentId.trim().isEmpty || selectedPlan == null) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      await ActionDialog.show(
        context,
        title: 'Verification Pending',
        message:
            'Payment received, but plan verification is incomplete. Please contact support.',
        type: ActionDialogType.warning,
        onConfirm: () {},
      );
      return;
    }

    setState(() => _isProcessing = true);

    final result = await _billingVerificationService.verifyRazorpayPayment(
      paymentId: paymentId,
      planType: selectedPlan.apiValue,
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;
    if (result.success) {
      await ActionDialog.show(
        context,
        title: 'Payment Successful',
        message: result.message,
        type: ActionDialogType.success,
        onConfirm: () {
          Navigator.pop(context);
        },
      );
      return;
    }

    await ActionDialog.show(
      context,
      title: 'Verification Required',
      message: result.message,
      type: ActionDialogType.warning,
      onConfirm: () {},
    );
  }

  Future<void> _onPaymentError(PaymentFailureResponse response) async {
    setState(() => _isProcessing = false);
    if (!mounted) return;
    await ActionDialog.show(
      context,
      title: 'Payment Failed',
      message: response.message ?? 'Payment was interrupted or failed.',
      type: ActionDialogType.danger,
      onConfirm: () {},
    );
  }

  Future<void> _onExternalWallet(ExternalWalletResponse response) async {
    setState(() => _isProcessing = false);
    if (!mounted) return;
    await ActionDialog.show(
      context,
      title: 'External Wallet Selected',
      message:
          'You selected ${response.walletName}. Please complete the payment.',
      onConfirm: () {},
    );
  }

  Future<void> _startPayment(PremiumPlanType plan) async {
    if (_isProcessing) return;
    setState(() {
      _selectedPlan = plan;
      _isProcessing = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'test@example.com';
    final name = user?.displayName ?? 'User';

    if (AppConfig.razorpayApiKey.trim().isEmpty) {
      if (mounted) {
        setState(() => _isProcessing = false);
        await ActionDialog.show(
          context,
          title: 'Payment Config Missing',
          message: 'Razorpay API key is not configured.',
          type: ActionDialogType.danger,
          onConfirm: () {},
        );
      }
      return;
    }

    _razorpayService?.openCheckout(
      amountInr: plan.amountInr,
      name: name,
      description: 'Upgrade to ${plan.label}',
      userEmail: email,
      userContact: '9999999999',
      notes: {
        'user_uid': user?.uid ?? '',
        'plan_type': plan.apiValue,
        'source': 'portfolio_mobile',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EntitlementState>(
      future: _entitlementService.getCurrentEntitlement(),
      builder: (context, snapshot) {
        final ent = snapshot.data;
        final isAdmin = ent?.isAdmin == true;
        final isPremium = ent?.isPremium == true;
        final hasActiveMembership = isAdmin || isPremium;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              hasActiveMembership ? 'Membership' : 'Upgrade to Premium',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppTheme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.inputFillColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  isAdmin
                      ? 'Admin account detected. All premium features are unlocked for free.'
                      : hasActiveMembership
                          ? 'Your Premium membership is active. All premium features are unlocked.'
                          : 'Feature locked: ${widget.featureName}\nUpgrade to Premium to continue.',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (hasActiveMembership) ...[
                _membershipCard(
                  plan: isAdmin
                      ? 'admin'
                      : (ent?.plan.isNotEmpty == true ? ent!.plan : 'premium'),
                  status: isAdmin
                      ? 'active'
                      : (ent?.status.isNotEmpty == true
                          ? ent!.status
                          : 'active'),
                ),
              ] else ...[
                _planCard(
                  title: PremiumPlanType.monthly.label,
                  price: 'Rs. ${MonetizationConfig.premiumMonthlyInr}/month',
                  subtitle: 'Best for trying premium features',
                  badge: null,
                  onTap: () => _startPayment(PremiumPlanType.monthly),
                ),
                const SizedBox(height: 14),
                _planCard(
                  title: PremiumPlanType.yearly.label,
                  price: 'Rs. ${MonetizationConfig.premiumYearlyInr}/year',
                  subtitle: 'Best value plan',
                  badge: 'SAVE MORE',
                  onTap: () => _startPayment(PremiumPlanType.yearly),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Premium unlocks custom domain, AI tools, and multi-language automation.',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: hasActiveMembership
                    ? 'BACK TO FEATURES'
                    : 'I\'LL UPGRADE LATER',
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.pop(context),
                isLoading: _isProcessing,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _membershipCard({
    required String plan,
    required String status,
  }) {
    final normalizedPlan = plan.trim().isEmpty ? 'premium' : plan.trim();
    final normalizedStatus = status.trim().isEmpty ? 'active' : status.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.inputFillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Active Membership',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Plan: ${normalizedPlan.toUpperCase()}',
            style: GoogleFonts.inter(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Status: ${normalizedStatus.toUpperCase()}',
            style: GoogleFonts.inter(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _planCard({
    required String title,
    required String price,
    required String subtitle,
    required VoidCallback? onTap,
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.inputFillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            text: 'PAY NOW',
            icon: Icons.payment_rounded,
            onPressed: onTap ?? () {},
          ),
        ],
      ),
    );
  }
}
