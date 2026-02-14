import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../widgets/action_dialog.dart';
import '../services/seed_data.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isNameEditing = false;
  late StreamSubscription<User?> _userSubscription;

  @override
  void initState() {
    super.initState();
    _initializeUser();

    // Listen to user changes to update UI if auth state refreshes
    _userSubscription = FirebaseAuth.instance.userChanges().listen((user) {
      if (mounted && !_isNameEditing) {
        setState(() {
          // Update only if the field is empty to prevent overwriting user input
          if (_nameController.text.isEmpty) {
            _nameController.text =
                (user?.displayName != null && user!.displayName!.isNotEmpty)
                    ? user.displayName!
                    : 'Saikumar';
          }
          _emailController.text = user?.email ?? 'saikumar@example.com';
        });
      }
    });
  }

  void _initializeUser() {
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text =
        (user?.displayName != null && user!.displayName!.isNotEmpty)
            ? user.displayName!
            : 'Saikumar';
    _emailController.text = user?.email ?? 'saikumar@example.com';
  }

  @override
  void dispose() {
    _userSubscription.cancel();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Name cannot be empty'),
            backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await user.updateDisplayName(_nameController.text.trim());
      await user.reload();

      if (mounted) {
        setState(() => _isNameEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _seedDatabase() async {
    ActionDialog.show(
      context,
      title: "Reset Database?",
      message:
          "This will restore all portfolio data to defaults. All your custom changes will be lost.",
      confirmLabel: "RESET NOW",
      type: ActionDialogType.warning,
      onConfirm: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Resetting database...'),
              backgroundColor: AppTheme.surfaceColor),
        );

        await DataSeeder().seedAllData();

        if (!mounted) return;
        ActionDialog.show(
          context,
          title: "Database Reset",
          message:
              "Your portfolio database has been restored to default settings successfully.",
          onConfirm: () {},
        );
      },
      onCancel: () {},
    );
  }

  Future<void> _handleLogout() async {
    ActionDialog.show(
      context,
      title: "Sign Out?",
      message: "Are you sure you want to sign out?",
      confirmLabel: "SIGN OUT",
      type: ActionDialogType.warning,
      onConfirm: () async {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      onCancel: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "My Profile",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Avatar & Header
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
                          color: const Color(0xFFC6A969).withValues(alpha: 0.3),
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

            // Profile Fields
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
                    // Cancelling edit: Revert to original
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

            // App Settings
            _buildSectionHeader("APP SETTINGS"),
            const SizedBox(height: 16),
            _buildActionCard(
              title: "Reset Database",
              subtitle: "Restore all data to default mock data",
              icon: Icons.refresh_rounded,
              color: Colors.orange,
              onTap: _seedDatabase,
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              title: "Sign Out",
              subtitle: "Log out of your account",
              icon: Icons.logout_rounded,
              color: AppTheme.errorColor,
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.transparent
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isEditing = true,
    VoidCallback? onEditPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEditing
                  ? AppTheme.primaryColor.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: TextField(
            controller: controller,
            enabled: true, // Always true to allow suffix icon interaction
            readOnly: !isEditing, // Control editing here
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon,
                  color: isEditing
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary.withValues(alpha: 0.5)),
              suffixIcon: onEditPressed != null
                  ? IconButton(
                      icon: Icon(
                        isEditing ? Icons.close_rounded : Icons.edit_rounded,
                        color: isEditing
                            ? AppTheme.textSecondary
                            : AppTheme.primaryColor,
                        size: 20,
                      ),
                      onPressed: onEditPressed,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
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
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
