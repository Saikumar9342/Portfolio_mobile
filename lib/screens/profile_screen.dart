import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/action_dialog.dart';
import 'domain_settings_screen.dart';
import '../services/firestore_service.dart';
import 'payment_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isNameEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text =
          (user.displayName != null && user.displayName!.isNotEmpty)
              ? user.displayName!
              : 'Saikumar';
      _emailController.text = user.email ?? '';
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(_nameController.text);

        // Also sync to Firestore
        await FirestoreService().ensureUserProfile();

        if (mounted) {
          setState(() => _isNameEditing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile updated successfully!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update profile: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await ActionDialog.show(
      context,
      title: "Sign Out",
      message: "Are you sure you want to sign out?",
      confirmLabel: "SIGN OUT",
      type: ActionDialogType.danger,
      onConfirm: () {},
    );

    if (confirm == true) {
      try {
        await GoogleSignIn().signOut();
        await FirebaseAuth.instance.signOut();

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('onboarding_complete');
        await prefs.remove('tutorial_complete');
      } catch (e) {
        debugPrint("Error during sign out: $e");
        await FirebaseAuth.instance.signOut();
      }
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _clearDatabase() async {
    final confirm = await ActionDialog.show(
      context,
      title: "Clear Portfolio Data",
      message:
          "WARNING: This will permanently DELETE all your portfolio content, projects, and customizations. This action cannot be undone. Are you sure?",
      confirmLabel: "DELETE EVERYTHING",
      type: ActionDialogType.danger,
      onConfirm: () {},
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await FirestoreService().clearPortfolioData();

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('onboarding_complete');
        await prefs.remove('tutorial_complete');

        if (mounted) {
          ActionDialog.show(
            context,
            title: "Portfolio Cleared",
            message:
                "All portfolio data has been deleted. You can now use Resume Upload to create a fresh portfolio.",
            type: ActionDialogType.success,
            onConfirm: () {},
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to clear data: $e")),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: const SizedBox.shrink(),
            centerTitle: false,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFC6A969), Color(0xFFE5D5A8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC6A969)
                                  .withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            (_nameController.text.isNotEmpty
                                    ? _nameController.text[0]
                                    : 'S')
                                .toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?.email ?? 'Signed in',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                _buildSectionHeader("PERSONAL INFO"),
                const SizedBox(height: 16),
                _buildTextField(
                  label: "Display Name",
                  controller: _nameController,
                  icon: Icons.person_outline_rounded,
                  isEditing: _isNameEditing,
                  onEditPressed: () {
                    setState(() {
                      if (_isNameEditing) {
                        final user = FirebaseAuth.instance.currentUser;
                        _nameController.text = (user?.displayName != null &&
                                user!.displayName!.isNotEmpty)
                            ? user.displayName!
                            : 'Saikumar';
                      }
                      _isNameEditing = !_isNameEditing;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: "Email Address",
                  controller: _emailController,
                  icon: Icons.email_outlined,
                  isEditing: false,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      disabledBackgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "SAVE CHANGES",
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader("APP SETTINGS"),
                const SizedBox(height: 16),
                _buildActionCard(
                  title: "Domain Settings",
                  subtitle: "Configure public link and custom domain",
                  icon: Icons.language_rounded,
                  color: AppTheme.primaryColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DomainSettingsScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  title: "Upgrade to Premium",
                  subtitle: "Unlock AI tools, custom domain and translations",
                  icon: Icons.workspace_premium_rounded,
                  color: AppTheme.primaryColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PaymentScreen(
                        featureName: "Premium Features",
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  title: "Reset Database",
                  subtitle: "Permanently delete all data to start fresh",
                  icon: Icons.delete_forever_rounded,
                  color: AppTheme.errorColor,
                  onTap: _clearDatabase,
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  title: "Sign Out",
                  subtitle: "Log out of your account",
                  icon: Icons.logout_rounded,
                  color: AppTheme.errorColor,
                  onTap: _handleLogout,
                ),
                const SizedBox(height: 32),
                _buildSectionHeader("LEGAL"),
                const SizedBox(height: 16),
                _buildActionCard(
                  title: "Privacy Policy",
                  subtitle: "Read our privacy policy",
                  icon: Icons.privacy_tip_rounded,
                  color: AppTheme.textSecondary,
                  onTap: () =>
                      _launchUrl('https://atom.anithix.com/privacy-policy'),
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  title: "Terms of Service",
                  subtitle: "Read our terms of service",
                  icon: Icons.description_rounded,
                  color: AppTheme.textSecondary,
                  onTap: () =>
                      _launchUrl('https://atom.anithix.com/terms-of-service'),
                ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary.withValues(alpha: 0.5),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isEditing,
    VoidCallback? onEditPressed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.inputFillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEditing ? AppTheme.primaryColor : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    letterSpacing: 1.2,
                  ),
                ),
                TextField(
                  controller: controller,
                  enabled: isEditing,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          if (onEditPressed != null)
            IconButton(
              icon: Icon(
                isEditing ? Icons.close_rounded : Icons.edit_rounded,
                color: isEditing ? AppTheme.errorColor : AppTheme.primaryColor,
                size: 20,
              ),
              onPressed: onEditPressed,
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
