import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/action_dialog.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class DomainSettingsScreen extends StatefulWidget {
  const DomainSettingsScreen({super.key});

  @override
  State<DomainSettingsScreen> createState() => _DomainSettingsScreenState();
}

class _DomainSettingsScreenState extends State<DomainSettingsScreen> {
  final FirestoreService _service = FirestoreService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _domainController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  bool _isSavingUsername = false;
  bool _isSavingDomain = false;
  bool _isSavingBaseUrl = false;
  bool _isResetting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _domainController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Copied to clipboard")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Domain Settings",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _service.streamCurrentUserProfile(),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          final data = snapshot.data!.data() ?? <String, dynamic>{};
          final username = (data['username'] as String?) ?? '';
          final customDomain = (data['customDomain'] as String?) ?? '';
          final baseUrl =
              (data['publicBaseUrl'] as String?) ?? "https://atom.anithix.com";

          if (_usernameController.text.isEmpty && username.isNotEmpty) {
            _usernameController.text = username;
          }
          if (_domainController.text.isEmpty && customDomain.isNotEmpty) {
            _domainController.text = customDomain;
          }
          if (_baseUrlController.text.isEmpty) {
            _baseUrlController.text = baseUrl;
          }

          final publicLink = _service.buildPublicPortfolioUrl(data);
          final customLink =
              customDomain.isNotEmpty ? 'https://$customDomain' : '';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _sectionTitle("Public Portfolio URL"),
              const SizedBox(height: 12),
              _linkCard(
                title: "Free Portfolio Link",
                value: publicLink,
                subtitle:
                    "This link is generated instantly. Share it anywhere to show your portfolio under the anithix brand.",
              ),
              const SizedBox(height: 16),
              _sectionTitle("Public Base URL"),
              const SizedBox(height: 12),
              CustomTextField(
                label: "BASE URL",
                controller: _baseUrlController,
                hint: "https://atom.anithix.com",
                prefixIcon: Icons.public_rounded,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                text: "SAVE BASE URL",
                icon: Icons.save_rounded,
                onPressed: _isSavingBaseUrl
                    ? () {}
                    : () async {
                        final value = _baseUrlController.text.trim();
                        if (value.isEmpty) return;

                        final confirm = await ActionDialog.show(
                          context,
                          title: "Update Base URL",
                          message:
                              "Changing the Base URL will affect all your public portfolio links. Continue?",
                          confirmLabel: "UPDATE",
                          type: ActionDialogType.warning,
                          onConfirm: () {},
                        );
                        if (confirm != true) return;

                        setState(() => _isSavingBaseUrl = true);
                        try {
                          await _service.setPublicBaseUrl(value);
                          if (!mounted) return;
                          ActionDialog.show(
                            this.context,
                            title: "Saved",
                            message: "Base URL updated successfully.",
                            onConfirm: () {},
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ActionDialog.show(
                            this.context,
                            title: "Update Failed",
                            message: e.toString(),
                            type: ActionDialogType.danger,
                            onConfirm: () {},
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _isSavingBaseUrl = false);
                          }
                        }
                      },
                isLoading: _isSavingBaseUrl,
              ),
              const SizedBox(height: 28),
              _sectionTitle("Username (Free Link)"),
              const SizedBox(height: 12),
              CustomTextField(
                label: "USERNAME",
                controller: _usernameController,
                hint: "john-doe",
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                text: "SAVE USERNAME",
                icon: Icons.alternate_email_rounded,
                onPressed: _isSavingUsername
                    ? () {}
                    : () async {
                        final value = _usernameController.text.trim();
                        if (value.isEmpty) return;

                        final confirm = await ActionDialog.show(
                          context,
                          title: "Update Username",
                          message:
                              "Changing your username will update your public portfolio link. Continue?",
                          confirmLabel: "UPDATE",
                          type: ActionDialogType.warning,
                          onConfirm: () {},
                        );
                        if (confirm != true) return;

                        setState(() => _isSavingUsername = true);
                        try {
                          await _service.setUsername(value);
                          if (!mounted) return;
                          ActionDialog.show(
                            this.context,
                            title: "Saved",
                            message: "Username updated successfully.",
                            onConfirm: () {},
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ActionDialog.show(
                            this.context,
                            title: "Username Error",
                            message: e.toString(),
                            type: ActionDialogType.danger,
                            onConfirm: () {},
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _isSavingUsername = false);
                          }
                        }
                      },
                isLoading: _isSavingUsername,
              ),
              const SizedBox(height: 12),
              _infoBox(
                  "Free users can customize their URL path (e.g., anithix.com/u/yourname). Changing this will immediately update your public link."),
              const SizedBox(height: 28),
              _sectionTitle("Custom Domain (Premium-ready)"),
              _infoBox(
                  "Premium users can connect their own branded domain (e.g., yourname.com). This requires external DNS configuration."),
              const SizedBox(height: 12),
              CustomTextField(
                label: "CUSTOM DOMAIN",
                controller: _domainController,
                hint: "yourname.com",
                prefixIcon: Icons.language_rounded,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                text: customDomain.isEmpty ? "CONNECT DOMAIN" : "UPDATE DOMAIN",
                icon: Icons.link_rounded,
                onPressed: _isSavingDomain
                    ? () {}
                    : () async {
                        final value = _domainController.text.trim();
                        if (value.isEmpty) return;

                        final confirm = await ActionDialog.show(
                          context,
                          title: "Connect Custom Domain",
                          message:
                              "Are you sure you want to connect '$value' to your portfolio?",
                          confirmLabel: "CONNECT",
                          type: ActionDialogType.warning,
                          onConfirm: () {},
                        );
                        if (confirm != true) return;

                        setState(() => _isSavingDomain = true);
                        try {
                          await _service.setCustomDomain(value);
                          if (!mounted) return;
                          ActionDialog.show(
                            this.context,
                            title: "Domain Connected",
                            message:
                                "Domain mapping is saved. Add DNS records in your registrar so traffic reaches this app.",
                            onConfirm: () {},
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ActionDialog.show(
                            this.context,
                            title: "Domain Error",
                            message: e.toString(),
                            type: ActionDialogType.danger,
                            onConfirm: () {},
                          );
                        } finally {
                          if (mounted) {
                            setState(() => _isSavingDomain = false);
                          }
                        }
                      },
                isLoading: _isSavingDomain,
              ),
              if (customDomain.isNotEmpty) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await ActionDialog.show(
                      this.context,
                      title: "Remove Domain",
                      message: "Disconnect $customDomain from this portfolio?",
                      confirmLabel: "REMOVE",
                      type: ActionDialogType.warning,
                      onConfirm: () {},
                    );
                    if (confirm != true) return;

                    setState(() => _isSavingDomain = true);
                    try {
                      await _service.removeCustomDomain();
                    } finally {
                      if (mounted) {
                        setState(() => _isSavingDomain = false);
                      }
                    }
                  },
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text("REMOVE DOMAIN"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: BorderSide(
                        color: AppTheme.errorColor.withValues(alpha: 0.5)),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Container(
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
                        const Icon(Icons.info_outline_rounded,
                            color: AppTheme.primaryColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Premium Domain Setup Instructions",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _dnsStep("1. Update DNS at your Registrar",
                        "Log into GoDaddy/Namecheap and point your domain to our servers."),
                    _dnsStep("2. Add A-Record",
                        "Type: A, Name: @, Value: 75.2.60.5"),
                    _dnsStep("3. Add CNAME-Record",
                        "Type: CNAME, Name: www, Value: anithix.com"),
                    _dnsStep("4. Validation",
                        "After saving, it may take up to 24 hours for DNS to propagate worldwide."),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (customLink.isNotEmpty)
                _linkCard(
                  title: "Custom Domain Link",
                  value: customLink,
                  subtitle: "Use this as your premium public URL.",
                ),
              const SizedBox(height: 32),
              const Divider(color: Colors.white10),
              const SizedBox(height: 32),
              _sectionTitle("Danger Zone"),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isResetting
                    ? null
                    : () async {
                        final confirm = await ActionDialog.show(
                          context,
                          title: "Reset All Settings",
                          message:
                              "This will clear your username, custom domain, and revert the base URL to default. Continue?",
                          confirmLabel: "RESET NOW",
                          type: ActionDialogType.danger,
                          onConfirm: () {},
                        );
                        if (confirm != true) return;

                        setState(() => _isResetting = true);
                        try {
                          await _service.resetUrlSettings();
                          _usernameController.clear();
                          _domainController.clear();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Settings reset to default")),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ActionDialog.show(
                              context,
                              title: "Reset Failed",
                              message: e.toString(),
                              type: ActionDialogType.danger,
                              onConfirm: () {},
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isResetting = false);
                          }
                        }
                      },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("RESET ALL URL SETTINGS"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: BorderSide(
                      color: AppTheme.errorColor.withValues(alpha: 0.5)),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 13,
        color: AppTheme.textSecondary.withValues(alpha: 0.7),
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _linkCard({
    required String title,
    required String value,
    required String subtitle,
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
          Text(
            title,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            value,
            style: GoogleFonts.inter(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyToClipboard(value),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text("COPY"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _service.launchURL(value),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text("OPEN"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppTheme.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _dnsStep(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
