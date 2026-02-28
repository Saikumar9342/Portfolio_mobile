import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../config/monetization_config.dart';
import '../theme/app_theme.dart';
import '../widgets/action_dialog.dart';
import '../widgets/primary_button.dart';
import '../services/entitlement_service.dart';

class PaymentScreen extends StatefulWidget {
  final String featureName;

  const PaymentScreen({super.key, required this.featureName});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final EntitlementService _entitlementService = EntitlementService();
  bool _isProcessing = false;

  Future<void> _startPayment({
    required String planLabel,
    required int amountInr,
    required String paymentUrl,
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      if (paymentUrl.trim().isEmpty) {
        await ActionDialog.show(
          context,
          title: "Payment Not Configured",
          message:
              "No checkout URL is configured for $planLabel yet. Please add payment URL in app config.",
          type: ActionDialogType.warning,
          onConfirm: () {},
        );
        return;
      }

      final uri = Uri.parse(paymentUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        await ActionDialog.show(
          context,
          title: "Unable to Open Payment",
          message: "Could not open the payment page. Please try again.",
          type: ActionDialogType.danger,
          onConfirm: () {},
        );
      } else if (mounted) {
        await ActionDialog.show(
          context,
          title: "Complete Payment",
          message:
              "After successful payment of Rs. $amountInr ($planLabel), your premium access will activate automatically once billing updates.",
          onConfirm: () {},
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EntitlementState>(
      future: _entitlementService.getCurrentEntitlement(),
      builder: (context, snapshot) {
        final ent = snapshot.data;
        final isAdmin = ent?.isAdmin == true;
        return Scaffold(
          backgroundColor: AppTheme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              "Upgrade to Premium",
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
                      ? "Admin account detected. All premium features are unlocked for free."
                      : "Feature locked: ${widget.featureName}\nUpgrade to Premium to continue.",
                  style: GoogleFonts.inter(color: AppTheme.textSecondary, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),
              _planCard(
                title: "Premium Monthly",
                price: "Rs. ${MonetizationConfig.premiumMonthlyInr}/month",
                subtitle: "Best for trying premium features",
                badge: null,
                onTap: isAdmin
                    ? null
                    : () => _startPayment(
                          planLabel: "Premium Monthly",
                          amountInr: MonetizationConfig.premiumMonthlyInr,
                          paymentUrl: AppConfig.premiumMonthlyPaymentUrl,
                        ),
              ),
              const SizedBox(height: 14),
              _planCard(
                title: "Premium Yearly",
                price: "Rs. ${MonetizationConfig.premiumYearlyInr}/year",
                subtitle: "Best value plan",
                badge: "SAVE MORE",
                onTap: isAdmin
                    ? null
                    : () => _startPayment(
                          planLabel: "Premium Yearly",
                          amountInr: MonetizationConfig.premiumYearlyInr,
                          paymentUrl: AppConfig.premiumYearlyPaymentUrl,
                        ),
              ),
              const SizedBox(height: 24),
              Text(
                "Premium unlocks custom domain, AI tools, and multi-language automation.",
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: isAdmin ? "BACK" : "I'LL UPGRADE LATER",
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
            text: "PAY NOW",
            icon: Icons.payment_rounded,
            onPressed: onTap ?? () {},
          ),
        ],
      ),
    );
  }
}

