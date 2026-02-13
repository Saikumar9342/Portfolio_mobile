import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_card.dart';
import 'content_editor_screen.dart';
import 'projects_screen.dart';
import 'resume_upload_screen.dart';
import '../services/seed_data.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              'Dashboard',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            centerTitle: false,
            backgroundColor: AppTheme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                onPressed: () => _seedDatabase(context),
                tooltip: 'Reset Database',
              ),
            ],
          ),
          // Quick Actions Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text(
                "Quick Actions",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),

          // Quick Action Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      title: "Manage\nProjects",
                      icon: Icons.work_outline,
                      color: const Color(0xFFC6A969),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProjectsScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _QuickActionCard(
                      title: "Upload\nResume",
                      icon: Icons.description_outlined,
                      color: Colors.blueAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ResumeUploadScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // Content Management Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                "Content Management",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),

          // Content Items Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _ContentItem(
                  title: "Hero Section",
                  icon: Icons.monitor,
                  onTap: () => _navToEditor(context, 'Hero Section', 'hero'),
                ),
                _ContentItem(
                  title: "About & Socials",
                  icon: Icons.person_outline,
                  onTap: () =>
                      _navToEditor(context, 'About & Socials', 'about'),
                ),
                _ContentItem(
                  title: "Expertise",
                  icon: Icons.lightbulb_outline,
                  onTap: () => _navToEditor(context, 'Expertise', 'expertise'),
                ),
                _ContentItem(
                  title: "Skills",
                  icon: Icons.code,
                  onTap: () => _navToEditor(context, 'Skills', 'skills'),
                ),
                _ContentItem(
                  title: "Contact Info",
                  icon: Icons.email_outlined,
                  onTap: () => _navToEditor(context, 'Contact Info', 'contact'),
                ),
                _ContentItem(
                  title: "Navbar",
                  icon: Icons.menu,
                  onTap: () => _navToEditor(context, 'Navbar', 'navbar'),
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(
              child: SizedBox(height: 100)), // Bottom padding
        ],
      ),
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

  Future<void> _seedDatabase(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Resetting database...'),
          backgroundColor: AppTheme.surfaceColor),
    );
    await DataSeeder().seedAllData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database reset complete!'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    }
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ContentItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
