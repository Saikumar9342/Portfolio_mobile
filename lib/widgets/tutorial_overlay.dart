import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final Map<String, GlobalKey> targets;
  final String currentScreen;

  const TutorialOverlay({
    super.key,
    required this.onDismiss,
    required this.targets,
    this.currentScreen = 'home',
  });

  @override
  TutorialOverlayState createState() => TutorialOverlayState();
}

class TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _fadeController;
  late AnimationController _pulseController;

  // Define steps for each screen
  late List<TutorialStepData> _steps;
  bool _isAppreciating = false;
  String _appreciationText = "";

  final List<String> _appreciations = [
    "FANTASTIC!",
    "SPOT ON!",
    "EXCELLENT!",
    "GREAT JOB!",
    "YOU'RE A PRO!",
    "AWESOME!",
  ];

  void _initSteps() {
    if (widget.currentScreen == 'projects') {
      _steps = [
        TutorialStepData(
          id: 'add_project',
          title: "ADD NEW WORK",
          description:
              "Tap the '+' icon at the top right to showcase a new achievement.",
          icon: Icons.add_circle_outline,
          requireAction: true,
        ),
      ];
    } else if (widget.currentScreen == 'resume') {
      _steps = [
        TutorialStepData(
          id: 'upload_area',
          title: "DRAG & DROP PDF",
          description:
              "Upload your latest resume here. Our AI will automatically extract and format it for your web portfolio.",
          icon: Icons.cloud_upload_outlined,
          requireAction: true,
        ),
      ];
    } else {
      // Home Screen (Default)
      _steps = [
        TutorialStepData(
          id: 'resume',
          title: "1. UPLOAD YOUR RESUME",
          description:
              "Start here to populate your site instantly with your career data.",
          icon: Icons.assignment_ind_rounded,
          requireAction: true,
        ),
        TutorialStepData(
          id: 'projects',
          title: "2. ADD YOUR PROJECTS",
          description:
              "Showcase your best work with high-quality images and tech tags.",
          icon: Icons.rocket_launch_rounded,
          requireAction: true,
        ),
        TutorialStepData(
          id: 'design',
          title: "3. TAILOR THE DESIGN",
          description:
              "Refine every detail of your portfolio's appearance and cinematic feel.",
          icon: Icons.auto_awesome_rounded,
          requireAction: true,
        ),
      ];
    }
  }

  void completeStep(String id) async {
    if (_isAppreciating || _steps.isEmpty || _currentStep >= _steps.length) {
      return;
    }
    if (_steps[_currentStep].id != id) return;

    // Map specific actions to global task keys
    String taskKey = id;
    if (id == 'upload_area') taskKey = 'resume';
    if (id == 'add_project') taskKey = 'projects';

    // Increment task counter in SharedPreferences using unique keys
    final prefs = await SharedPreferences.getInstance();
    final List<String> completedKeys =
        prefs.getStringList('tutorial_completed_task_keys') ?? [];

    if (!completedKeys.contains(taskKey)) {
      completedKeys.add(taskKey);
      await prefs.setStringList('tutorial_completed_task_keys', completedKeys);
      await prefs.setInt('tutorial_tasks_completed', completedKeys.length);
    }

    setState(() {
      _isAppreciating = true;
      _appreciationText = (_appreciations..shuffle()).first;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isAppreciating = false;
        });
        _next();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initSteps();
    _loadProgress();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> completedKeys =
        prefs.getStringList('tutorial_completed_task_keys') ?? [];

    if (mounted && widget.currentScreen == 'home') {
      int step = 0;
      if (completedKeys.contains('resume')) step = 1;
      if (completedKeys.contains('projects')) step = 2;
      if (completedKeys.contains('design')) step = 3;

      setState(() {
        _currentStep = step;
      });

      // If all home steps are done but it still showed, dismiss it
      if (_currentStep >= _steps.length) {
        widget.onDismiss();
      }
    }
  }

  Rect? _getTargetRect() {
    if (_steps.isEmpty || _currentStep >= _steps.length) return null;
    final key = widget.targets[_steps[_currentStep].id];
    if (key == null) return null;

    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final offset = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      offset.dx,
      offset.dy,
      renderBox.size.width,
      renderBox.size.height,
    );
  }

  void _next() {
    if (_currentStep < _steps.length - 1) {
      _fadeController.reverse().then((_) {
        setState(() => _currentStep++);
        _fadeController.forward();
      });
    } else {
      // Loop or keep active
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) return const SizedBox.shrink();

    final rect = _getTargetRect();
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Strict Blocker: Blocks everything except the hole
          if (rect != null)
            ClipPath(
              clipper: _InvertedRectClipper(rect),
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.8),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
              ),
            ),

          // 2. Animated Outline
          if (rect != null)
            Positioned(
              left: rect.left - 4,
              top: rect.top - 4,
              child: FadeTransition(
                opacity: _pulseController,
                child: Container(
                  width: rect.width + 8,
                  height: rect.height + 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. Instruction Card
          AnimatedBuilder(
            animation: _fadeController,
            builder: (context, child) {
              double top;
              if (rect != null) {
                bool isTopHalf = rect.top < size.height / 2;
                top = isTopHalf ? rect.bottom + 40 : rect.top - 200;
              } else {
                top = size.height / 2 - 100;
              }

              return Positioned(
                top: top,
                left: 24,
                right: 24,
                child: Opacity(
                  opacity: _fadeController.value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - _fadeController.value)),
                    child: child,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_steps[_currentStep].icon,
                          color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _steps[_currentStep].title,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onDismiss,
                        icon: const Icon(Icons.close,
                            color: Colors.white24, size: 20),
                        tooltip: "Stop Tutorial",
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isAppreciating)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                AppTheme.successColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars_rounded,
                              color: AppTheme.successColor, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            _appreciationText,
                            style: GoogleFonts.outfit(
                              color: AppTheme.successColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      _steps[_currentStep].description,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_steps.length > 1)
                        Text(
                          "${_currentStep + 1} / ${_steps.length}",
                          style: GoogleFonts.inter(
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Row(
                        children: [
                          if (_steps.length > 1 &&
                              !_steps[_currentStep].requireAction &&
                              !_isAppreciating)
                            ElevatedButton(
                              onPressed: _next,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                minimumSize: const Size(100, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _currentStep == _steps.length - 1
                                    ? "GOT IT"
                                    : "NEXT",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: widget.onDismiss,
                            child: Text(
                              "STOP TUTORIAL",
                              style: GoogleFonts.outfit(
                                color: AppTheme.errorColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialStepData {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool requireAction;

  TutorialStepData({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.requireAction = false,
  });
}

class _InvertedRectClipper extends CustomClipper<Path> {
  final Rect rect;

  _InvertedRectClipper(this.rect);

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
          RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(24)))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(_InvertedRectClipper oldClipper) => rect != oldClipper.rect;
}
