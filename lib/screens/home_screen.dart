import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_card.dart';
import 'content_editor_screen.dart';
import 'projects_screen.dart';
import 'skills_manager_screen.dart';
import 'resume_upload_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Show title once we've scrolled past the "Greeting" area roughly
    if (_scrollController.offset > 80 && !_showTitle) {
      setState(() => _showTitle = true);
    } else if (_scrollController.offset <= 80 && _showTitle) {
      setState(() => _showTitle = false);
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  String get _dateString {
    final now = DateTime.now();
    return DateFormat('EEEE, d MMMM').format(now);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. Ambient Background Glows
          Positioned(
            bottom: 100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color.fromARGB(255, 223, 217, 203)
                    .withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 224, 214, 191)
                        .withValues(alpha: 0.15),
                    blurRadius: 120,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withValues(alpha: 0.08),
                    blurRadius: 100,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          // 2. Main Scrollable Content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppTheme.scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showTitle ? 1.0 : 0.0,
                  child: Text(
                    'Dashboard',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                centerTitle: false,
                // Actions removed as requested
              ),

              // Greeting Section (Scrolls away)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dateString.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary.withValues(alpha: 0.7),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _greeting,
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      StreamBuilder<User?>(
                          stream: FirebaseAuth.instance.userChanges(),
                          builder: (context, snapshot) {
                            final name = (snapshot.data?.displayName != null &&
                                    snapshot.data!.displayName!.isNotEmpty)
                                ? snapshot.data!.displayName!
                                : 'Saikumar';
                            return Text(
                              name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 34,
                                color: AppTheme.textPrimary,
                                height: 1.0,
                              ),
                            );
                          }),
                    ],
                  ),
                ),
              ),

              // Quick Actions Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _StaggeredAnimate(
                    delay: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "QUICK ACTIONS",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.5),
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
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _Bouncy(
                                child: _QuickActionCard(
                                  title: "Projects",
                                  icon: Icons.work_outline_rounded,
                                  color: const Color(0xFFC6A969),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const ProjectsScreen()),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Bouncy(
                                child: _QuickActionCard(
                                  title: "Resume",
                                  icon: Icons.upload_file_rounded,
                                  color: Colors.blueAccent,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ResumeUploadScreen()),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Bouncy(
                                child: _QuickActionCard(
                                  title: "Profile",
                                  icon: Icons.person_rounded,
                                  color: Colors.purpleAccent,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const ProfileScreen()),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // Content Management Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _StaggeredAnimate(
                    delay: 1,
                    child: Row(
                      children: [
                        Text(
                          "CONTENT MANAGEMENT",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.5),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Container(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.05))),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Content Items Grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _buildAnimatedContentItem(
                        0,
                        "Hero Section",
                        Icons.monitor_rounded,
                        () => _navToEditor(context, 'Hero Section', 'hero')),
                    _buildAnimatedContentItem(
                        1,
                        "About & Socials",
                        Icons.person_outline_rounded,
                        () =>
                            _navToEditor(context, 'About & Socials', 'about')),
                    _buildAnimatedContentItem(
                        2,
                        "Expertise",
                        Icons.lightbulb_outline_rounded,
                        () => _navToEditor(context, 'Expertise', 'expertise')),
                    _buildAnimatedContentItem(
                        3,
                        "Skills",
                        Icons.code_rounded,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SkillsManagerScreen()))),
                    _buildAnimatedContentItem(
                        4,
                        "Contact Info",
                        Icons.email_outlined,
                        () => _navToEditor(context, 'Contact Info', 'contact')),
                    _buildAnimatedContentItem(5, "Navbar", Icons.menu_rounded,
                        () => _navToEditor(context, 'Navbar', 'navbar')),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedContentItem(
      int index, String title, IconData icon, VoidCallback onTap) {
    return _StaggeredAnimate(
      delay: index + 2,
      child: _Bouncy(
        child: _ContentItem(
          title: title,
          icon: icon,
          onTap: onTap,
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 0,
                  )
                ]),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.1,
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
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: AppTheme.textSecondary.withValues(alpha: 0.8), size: 36),
          const SizedBox(height: 16),
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

// Simple Fade-In-Up Animation Wrapper
class _StaggeredAnimate extends StatefulWidget {
  final Widget child;
  final int delay;

  const _StaggeredAnimate({required this.child, required this.delay});

  @override
  State<_StaggeredAnimate> createState() => _StaggeredAnimateState();
}

class _StaggeredAnimateState extends State<_StaggeredAnimate>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _offset = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Stagger start based on index
    Future.delayed(Duration(milliseconds: widget.delay * 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}

// Bouncy Wrapper for Touch Feedback
class _Bouncy extends StatefulWidget {
  final Widget child;

  const _Bouncy({
    required this.child,
  });

  @override
  State<_Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<_Bouncy> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
