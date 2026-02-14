import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  static const String _googleServerClientId =
      '16450323072-5u4bqmvvnkpf5bnds15lr7i4es6ko9dj.apps.googleusercontent.com';
  bool _isLoading = false;
  String? _error;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
    serverClientId: _googleServerClientId,
  );

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _bgAnimationController;
  late Animation<double> _bgMoveAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _bgMoveAnimation = Tween<double>(begin: -0.2, end: 0.2).animate(
      CurvedAnimation(parent: _bgAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signIn().timeout(const Duration(seconds: 30));
      if (googleUser == null) {
        if (!context.mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication.timeout(const Duration(seconds: 30));

      if (googleAuth.idToken == null) {
        throw PlatformException(
          code: 'google_sign_in_no_id_token',
          message:
              'Google sign-in did not return an ID token. Check Firebase Android SHA-1/SHA-256 and OAuth client setup.',
        );
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Google sign-in configuration error (${e.code}). Please verify Play Services and Firebase SHA setup.';
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? 'Failed to sign in with Google.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unexpected error: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Biometrics not available on this device."),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access portfolio',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        _signInWithGoogle();
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Authentication error: ${e.message}"),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Unexpected error during biometric authentication: $e"),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // 1. Cinematic Animated Background Blobs
          AnimatedBuilder(
            animation: _bgMoveAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: size.height * (0.1 + _bgMoveAnimation.value),
                    right: -size.width * 0.2,
                    child: _buildBlob(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      size: 450,
                    ),
                  ),
                  Positioned(
                    bottom: size.height * (0.05 - _bgMoveAnimation.value),
                    left: -size.width * 0.3,
                    child: _buildBlob(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      size: 500,
                    ),
                  ),
                  Positioned(
                    top: size.height * (0.6 + _bgMoveAnimation.value),
                    right: size.width * 0.1,
                    child: _buildBlob(
                      color: Colors.white.withValues(alpha: 0.03),
                      size: 300,
                    ),
                  ),
                ],
              );
            },
          ),

          // 2. Mesh-like Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.backgroundColor.withValues(alpha: 0.8),
                  Colors.transparent,
                  AppTheme.backgroundColor.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),

          // 3. Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Entrance Animation for Logo and Title
                  TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 2),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        _buildBrandIcon(),
                        const SizedBox(height: 48),
                        Text(
                          "ATOM",
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Portfolio Builder",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.6),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Login Actions Box
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _error!,
                              style: GoogleFonts.inter(
                                color: AppTheme.errorColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                                strokeWidth: 3,
                              ),
                            ),
                          )
                        else
                          _buildGoogleButton(),

                        const SizedBox(height: 24),

                        // Biometric Section
                        GestureDetector(
                          onTap: _authenticateWithBiometrics,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 1,
                                color: Colors.white10,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  "QUICK LOCK",
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    letterSpacing: 3,
                                    color: Colors.white24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                width: 40,
                                height: 1,
                                color: Colors.white10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: GestureDetector(
                            onTap: _authenticateWithBiometrics,
                            child: ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.05),
                                  border: Border.all(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.fingerprint_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Footer
                  Text(
                    "SECURE ENCRYPTION ENABLED",
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: Colors.white12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 0.8],
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildBrandIcon() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Glow
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 40,
                  spreadRadius: 10,
                )
              ],
            ),
          ),
          // Shared Logo Widget
          const BrandLogo(size: 80),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _signInWithGoogle,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF5F5F7), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Custom Google "G" Logo
              SizedBox(
                width: 24,
                height: 24,
                child: Stack(
                  children: [
                    Text(
                      "G",
                      style: GoogleFonts.roboto(
                        color: const Color(0xFF4285F4),
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                "Sign in with Google",
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
