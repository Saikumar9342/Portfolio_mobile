import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'projects_screen.dart';
import 'resume_upload_screen.dart';
import 'design_engine_screen.dart';
import 'content_management_screen.dart';
import 'profile_screen.dart';
import 'inquiries_screen.dart';
import '../services/firestore_service.dart';
import '../widgets/brand_logo.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _service = FirestoreService();
  bool _isScrolled = false;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 50 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 50 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });

    _notificationSubscription = NotificationService.onMessage.listen((message) {
      if (mounted) {
        debugPrint(
            "Message received in foreground: ${message.notification?.title}");
      }
    });
    _service.ensureUserProfile();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _dateString {
    final now = DateTime.now();
    return DateFormat('EEEE, d MMMM').format(now);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Clean Professional Header
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: AppTheme.scaffoldBackgroundColor
                .withValues(alpha: _isScrolled ? 0.9 : 0),
            elevation: 0,
            centerTitle: false,
            title: Row(
              children: [
                const BrandLogo(size: 28),
                const SizedBox(width: 10),
                Text(
                  "Atom",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontSize: 22,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            actions: [
              _HeaderAction(
                icon: Icons.notifications_none_rounded,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const InquiriesScreen())),
                hasBadge: true,
                stream: _service.streamUnreadMessagesCount(),
              ),
              const SizedBox(width: 8),
              _HeaderAction(
                icon: Icons.person_outline_rounded,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
              const SizedBox(width: 16),
            ],
          ),

          // 2. Greeting & Identity
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateString.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary.withValues(alpha: 0.4),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _greeting,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _service.streamCurrentUserProfile(),
                      builder: (context, snapshot) {
                        String name = 'User';
                        if (snapshot.hasData && snapshot.data!.exists) {
                          name = snapshot.data!.data()?['displayName'] ??
                              snapshot.data!.data()?['username'] ??
                              'User';
                        }
                        return Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 36,
                            color: AppTheme.textPrimary,
                            height: 1.1,
                          ),
                        );
                      }),
                ],
              ),
            ),
          ),

          // 3. Status Tile
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _service.streamCurrentUserProfile(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data() ?? {};
                    final url = _service.buildPublicPortfolioUrl(data);

                    String displayUrl =
                        url.replaceFirst(RegExp(r'^https?://'), '');

                    return _ActionPanel(
                      title: "Live Portfolio",
                      subtitle: displayUrl,
                      icon: Icons.language_rounded,
                      color: Colors.greenAccent,
                      onTap: () => _service.launchURL(url),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text("OPEN",
                            style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.greenAccent)),
                      ),
                    );
                  }),
            ),
          ),

          // 4. Analytics Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ANALYTICS",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary.withValues(alpha: 0.35),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: "Projects",
                          stream: _service.streamTotalProjectsCount(),
                          icon: Icons.rocket_launch_rounded,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: "Messages",
                          stream: _service.streamTotalMessagesCount(),
                          icon: Icons.chat_bubble_rounded,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: "Visits",
                          stream: _service.streamTotalVisitsCount(),
                          icon: Icons.remove_red_eye_rounded,
                          color: Colors.purpleAccent,
                          hasChart: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 5. Management Grid
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "QUICK ACTIONS",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary.withValues(alpha: 0.35),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ActionPanel(
                    title: "Projects Hub",
                    subtitle: "Manage your works portfolio",
                    icon: Icons.grid_view_rounded,
                    color: AppTheme.primaryColor,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProjectsScreen())),
                  ),
                  const SizedBox(height: 12),
                  _ActionPanel(
                    title: "Content Editor",
                    subtitle: "Update site text & info",
                    icon: Icons.edit_note_rounded,
                    color: Colors.blueAccent,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ContentManagementScreen())),
                  ),
                  const SizedBox(height: 12),
                  _ActionPanel(
                    title: "Resume & CV",
                    subtitle: "Upload professional documents",
                    icon: Icons.assignment_rounded,
                    color: Colors.orangeAccent,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ResumeUploadScreen())),
                  ),
                  const SizedBox(height: 12),
                  _ActionPanel(
                    title: "Design Engine",
                    subtitle: "Fine-tune your portfolio visual identity",
                    icon: Icons.auto_awesome_rounded,
                    color: AppTheme.primaryColor,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DesignEngineScreen())),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final Stream<int> stream;
  final IconData icon;
  final Color color;
  final bool hasChart;

  const _MetricCard({
    required this.label,
    required this.stream,
    required this.icon,
    required this.color,
    this.hasChart = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (hasChart)
            SizedBox(
              height: 50,
              width: double.infinity,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY: 6,
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 1),
                        FlSpot(1, 1.5),
                        FlSpot(2, 1.2),
                        FlSpot(3, 3),
                        FlSpot(4, 2.8),
                        FlSpot(5, 4.5),
                        FlSpot(6, 4),
                      ],
                      isCurved: true,
                      color: color.withValues(alpha: 0.4),
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Column(
              children: [
                Icon(icon, color: color.withValues(alpha: 0.8), size: 20),
                const SizedBox(height: 12),
                StreamBuilder<int>(
                    stream: stream,
                    builder: (context, snapshot) {
                      int count = snapshot.data ?? 0;
                      return Text(
                        count >= 1000
                            ? "${(count / 1000).toStringAsFixed(1)}k"
                            : count.toString(),
                        style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary),
                      );
                    }),
                Text(label.toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textSecondary.withValues(alpha: 0.3))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ActionPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return _Bouncy(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                    Text(subtitle,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              trailing ??
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white12),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool hasBadge;
  final Stream<int>? stream;

  const _HeaderAction(
      {required this.icon,
      required this.onTap,
      this.hasBadge = false,
      this.stream});

  @override
  Widget build(BuildContext context) {
    return _Bouncy(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            if (hasBadge && stream != null)
              StreamBuilder<int>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == 0) {
                      return const SizedBox.shrink();
                    }
                    int count = snapshot.data!;
                    return Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            count > 99 ? '99+' : count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }),
          ],
        ),
      ),
    );
  }
}

class _Bouncy extends StatefulWidget {
  final Widget child;
  const _Bouncy({required this.child});
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
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        SoundService.playTap();
      },
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
