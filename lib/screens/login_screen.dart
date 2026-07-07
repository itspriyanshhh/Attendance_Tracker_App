import 'dart:ui';

import 'package:attendance_management/ui/main_nav.dart';
import 'package:attendance_management/services/sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-in canceled by user')),
        );
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception(
          'Google Sign-In failed: Missing accessToken or idToken',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      // Register this device as the active session so other devices are kicked out
      await SyncService.instance.registerSession();
    } catch (e) {
      String errorMessage = 'Sign-in failed: $e';
      if (e is FirebaseAuthException) {
        errorMessage = 'Firebase Auth Error: ${e.code} - ${e.message}';
      } else if (e is PlatformException) {
        errorMessage = 'Platform Error: ${e.code} - ${e.message}';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
      print('Sign-in error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return const MainNav();
        }

        return _LoginBody(onSignIn: () => _signInWithGoogle(context));
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Login Body — Premium animated login experience
// ═══════════════════════════════════════════════════════════════════════════════
class _LoginBody extends StatefulWidget {
  final VoidCallback onSignIn;
  const _LoginBody({required this.onSignIn});

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> with TickerProviderStateMixin {
  late AnimationController _gradientController;
  late AnimationController _contentController;
  late Animation<double> _gradientAnimation;

  // Content stagger animations
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<double> _buttonFade;
  late Animation<Offset> _buttonSlide;
  late Animation<double> _footerFade;

  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();

    // Slow gradient shift
    _gradientController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.easeInOut),
    );

    // Content entrance animations
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.15, 0.5, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.3, 0.65, curve: Curves.easeOut),
      ),
    );
    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.5, 0.85, curve: Curves.easeOut),
      ),
    );
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.5, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _contentController.forward();
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _handleSignIn() {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    widget.onSignIn();
    // Reset after a delay in case sign-in fails/cancels
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _isSigningIn = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            const Color(0xFF0D0B1A),
            const Color(0xFF1A0E2E),
            const Color(0xFF2D1B4E),
          ]
        : [
            const Color(0xFFF0F2FF),
            const Color(0xFFE4E9FF),
            const Color(0xFFD2D9FF),
          ];

    final accentColor = isDark
        ? const Color(0xFF8C9EFF)
        : const Color(0xFF5C6BC0);

    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _gradientAnimation,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
                stops: [
                  0.0,
                  0.4 + (_gradientAnimation.value * 0.15),
                  1.0,
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // ── App Icon with glow ──
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(
                                  isDark ? 0.35 : 0.2,
                                ),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset(
                              'assets/icon/icon.png',
                              width: 110,
                              height: 110,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── App Name ──
                    FadeTransition(
                      opacity: _titleFade,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: Text(
                          'Attendify',
                          style: GoogleFonts.poppins(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -1.5,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Tagline ──
                    FadeTransition(
                      opacity: _subtitleFade,
                      child: Text(
                        'Your smart attendance companion.\nTrack, analyze, and stay on top.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: textColor.withOpacity(0.55),
                          height: 1.6,
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // ── Google Sign-In Button ──
                    FadeTransition(
                      opacity: _buttonFade,
                      child: SlideTransition(
                        position: _buttonSlide,
                        child: _buildGoogleButton(
                          isDark: isDark,
                          accentColor: accentColor,
                          textColor: textColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Footer text ──
                    FadeTransition(
                      opacity: _footerFade,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: textColor.withOpacity(0.3),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoogleButton({
    required bool isDark,
    required Color accentColor,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: _handleSignIn,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withOpacity(_isSigningIn ? 0.06 : 0.1),
                        Colors.white.withOpacity(_isSigningIn ? 0.02 : 0.04),
                      ]
                    : [
                        Colors.white.withOpacity(_isSigningIn ? 0.7 : 0.9),
                        Colors.white.withOpacity(_isSigningIn ? 0.5 : 0.75),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? accentColor.withOpacity(0.2)
                    : Colors.black.withOpacity(0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? accentColor.withOpacity(0.12)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSigningIn) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        textColor.withOpacity(0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Signing in...',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                ] else ...[
                  // Google "G" logo
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Center(
                      child: Text(
                        'G',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [
                                Color(0xFF4285F4),
                                Color(0xFF34A853),
                                Color(0xFFFBBC05),
                                Color(0xFFEA4335),
                              ],
                              stops: [0.0, 0.33, 0.66, 1.0],
                            ).createShader(
                              const Rect.fromLTWH(0, 0, 20, 20),
                            ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor.withOpacity(0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
