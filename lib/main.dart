import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_logo.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("--- APP STARTING ---");

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    print("--- FIREBASE INITIALIZED ---");

    // Initialize Notifications
    final notificationService = NotificationService();
    await notificationService.initialize();
    print("--- NOTIFICATIONS INITIALIZED ---");

    await FirebaseAuth.instance.setLanguageCode('en');
  } catch (e, stack) {
    print("--- INIT ERROR: $e");
    print(stack);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atom Portfolio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _AuthWrapper(),
    );
  }
}

class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper();

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const Scaffold(
        backgroundColor: AppTheme.scaffoldBackgroundColor,
        body: SplashScreen(),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }
        if (snapshot.data == null) {
          return const LoginScreen();
        }
        return const HomeScreen();
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fillAnimation;
  late Animation<double> _glintAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.1), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));

    _floatAnimation = Tween<double>(begin: 0, end: -10.0).animate(
        CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.6, 1.0, curve: Curves.easeInOut)));

    _rotationAnimation = Tween<double>(begin: 0.3, end: 0.0).animate(
        CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)));

    // 1. Liquid Filling (Bottom to Top)
    _fillAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.1, 0.7, curve: Curves.easeInOut)));

    // 2. Final Diamond Glint
    _glintAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
        CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.7, 1.0, curve: Curves.linear)));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, _floatAnimation.value),
                    child: Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(_rotationAnimation.value),
                      alignment: Alignment.center,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Shadow / Background Silhouette
                            Opacity(
                              opacity: 0.1,
                              child: const BrandLogo(size: 150),
                            ),

                            // Liquid Filling Reveal
                            ClipPath(
                              clipper: LiquidClipper(_fillAnimation.value),
                              child: const BrandLogo(size: 150),
                            ),

                            // The Final Crystal Glint
                            if (_glintAnimation.value > -1.0)
                              ShaderMask(
                                shaderCallback: (rect) {
                                  return LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    stops: [
                                      (_glintAnimation.value - 0.2)
                                          .clamp(0.0, 1.0),
                                      _glintAnimation.value.clamp(0.0, 1.0),
                                      (_glintAnimation.value + 0.2)
                                          .clamp(0.0, 1.0),
                                    ],
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.8),
                                      Colors.transparent,
                                    ],
                                  ).createShader(rect);
                                },
                                blendMode: BlendMode.srcIn,
                                child: const BrandLogo(size: 150),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Powered by Anthrix
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Column(
                children: [
                  Text(
                    "POWERED BY",
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white12,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "ANTHRIX",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white54,
                      letterSpacing: 10,
                    ),
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

class LiquidClipper extends CustomClipper<Path> {
  final double progress;
  LiquidClipper(this.progress);

  @override
  Path getClip(Size size) {
    final path = Path();
    final y = size.height * (1.0 - progress);
    path.moveTo(0, y);
    path.lineTo(size.width, y);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(LiquidClipper oldClipper) =>
      oldClipper.progress != progress;
}
