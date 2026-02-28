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
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  debugPrint("--- APP STARTING ---");

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    debugPrint("--- FIREBASE INITIALIZED ---");

    // Enable True Offline Support
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 50 * 1024 * 1024, // 50MB
    );

    // Initialize Analytics and Crashlytics
    await FirebaseAnalytics.instance.logAppOpen();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

    // Initialize Notifications
    final notificationService = NotificationService();
    await notificationService.initialize();
    debugPrint("--- NOTIFICATIONS INITIALIZED ---");

    await FirebaseAuth.instance.setLanguageCode('en');
  } catch (e, stack) {
    debugPrint("--- INIT ERROR: $e");
    debugPrint(stack.toString());
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
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
      },
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
  bool _onboardingComplete = false;
  String? _lastUid;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
      });
    }
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

        final user = snapshot.data;
        if (user == null) {
          _lastUid = null;
          return const LoginScreen();
        }

        // If user changed, re-check onboarding status for this account
        if (_lastUid != user.uid) {
          _lastUid = user.uid;
          _onboardingComplete = false; // Reset until proven otherwise
          _checkOnboarding();
        }

        // 1. If we already know onboarding is complete from local storage
        if (_onboardingComplete) {
          return const HomeScreen();
        }

        // 2. If not complete in local storage, check Firestore to see if this is a returning user
        // who just reinstalled the app or cleared data.
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, docSnapshot) {
            if (docSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppTheme.scaffoldBackgroundColor,
                body: Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              );
            }

            final exists = docSnapshot.hasData && docSnapshot.data!.exists;

            if (exists) {
              // RETURNING USER: Doc exists in Firestore, so they've been here before.
              // We skip onboarding but must update local storage so we don't check again.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _skipOnboardingForExisting();
              });
              return const HomeScreen();
            } else {
              // NEW USER: No doc in Firestore.
              return const OnboardingScreen();
            }
          },
        );
      },
    );
  }

  Future<void> _skipOnboardingForExisting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    // Note: We DON'T set tutorial_complete here for existing users if we want them to have the option
    // But per previous requirement, we did. Let's keep it but allow explicit re-enable.
    await prefs.setBool('tutorial_complete', true);
    if (mounted && !_onboardingComplete) {
      setState(() {
        _onboardingComplete = true;
      });
    }
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
                            const Opacity(
                              opacity: 0.1,
                              child: BrandLogo(size: 150),
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
