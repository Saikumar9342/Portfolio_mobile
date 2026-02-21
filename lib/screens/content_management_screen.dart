import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_card.dart';
import 'content_editor_screen.dart';
import 'skills_manager_screen.dart';
import 'language_list_screen.dart';

class ContentManagementScreen extends StatelessWidget {
  const ContentManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Animated Background (matching HomeScreen style)
          const _BackgroundGlows(),

          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  "Content Hub",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Manage every detail of your portfolio from one place.",
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),
                      GradientCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _buildItem(
                              context,
                              "Hero Section",
                              "Manage your intro text and hero image display.",
                              Icons.monitor_rounded,
                              () =>
                                  _navToEditor(context, 'Hero Section', 'hero'),
                            ),
                            _buildItem(
                              context,
                              "About & Socials",
                              "Update your bio, profile picture, and social links.",
                              Icons.person_outline_rounded,
                              () => _navToEditor(
                                  context, 'About & Socials', 'about'),
                            ),
                            _buildItem(
                              context,
                              "Work Expertise",
                              "Showcase your services and key achievements.",
                              Icons.lightbulb_outline_rounded,
                              () => _navToEditor(
                                  context, 'Expertise', 'expertise'),
                            ),
                            _buildItem(
                              context,
                              "Tech Stack & Skills",
                              "Organize your skills into categories.",
                              Icons.code_rounded,
                              () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const SkillsManagerScreen())),
                            ),
                            _buildItem(
                              context,
                              "Multi-Language",
                              "Manage translations for your global audience.",
                              Icons.translate_rounded,
                              () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const LanguageListScreen())),
                            ),
                            _buildItem(
                              context,
                              "Contact Details",
                              "Update your email and contact form settings.",
                              Icons.email_outlined,
                              () => _navToEditor(
                                  context, 'Contact Info', 'contact'),
                            ),
                            _buildItem(
                                context,
                                "Navigation Menu",
                                "Configure your website navigation items.",
                                Icons.menu_rounded,
                                () =>
                                    _navToEditor(context, 'Navbar', 'navbar')),
                            _buildItem(
                              context,
                              "SEO & Meta Tags",
                              "Enhance your search visibility and link previews.",
                              Icons.travel_explore_rounded,
                              () =>
                                  _navToEditor(context, 'SEO Settings', 'seo'),
                            ),
                            _buildItem(
                              context,
                              "Projects Page",
                              "Configure the dedicated projects gallery.",
                              Icons.work_outline_rounded,
                              () => _navToEditor(
                                  context, 'Projects Page', 'projects_page'),
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, String title, String subtitle,
      IconData icon, VoidCallback onTap,
      {bool isLast = false}) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 24),
          ),
          title: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary.withValues(alpha: 0.6),
            ),
          ),
          trailing: Icon(Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.2)),
        ),
        if (!isLast)
          Divider(
            color: Colors.white.withValues(alpha: 0.05),
            height: 1,
            indent: 70,
            endIndent: 20,
          ),
      ],
    );
  }

  void _navToEditor(BuildContext context, String title, String docId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContentEditorScreen(docId: docId, title: title),
      ),
    );
  }
}

class _BackgroundGlows extends StatelessWidget {
  const _BackgroundGlows();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blueAccent.withValues(alpha: 0.03),
            ),
          ),
        ),
      ],
    );
  }
}
