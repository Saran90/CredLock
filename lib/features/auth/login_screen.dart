import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/key_derivation_service.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _handleSignIn() async {
    setState(() => _loading = true);
    try {
      final account = await AuthService.instance.signIn();
      if (account == null) {
        setState(() => _loading = false);
        return;
      }
      await KeyDerivationService.instance.initForAccount(account.id);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Decorative orange glow — top right corner, away from the button
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.35),
                    AppColors.primaryDark.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  radius: 0.75,
                ),
              ),
            ),
          ),

          // Subtle glow bottom-left, far from the button area
          Positioned(
            bottom: -60,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryDark.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SizedBox(
              height: size.height,
              child: Column(
                children: [
                  // ── Top: logo + branding ──────────────────────────────────
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo circle
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Colors.black,
                            size: 46,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // App name
                        Text(
                          'credlock',
                          style: AppTextStyles.displayLarge.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Tagline
                        Text(
                          'Your passwords, secured.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Bottom: sign-in button on a dark card ─────────────────
                  Container(
                    margin: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign in to continue',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'Use your Google account to access your vault',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24),

                        // Button or spinner
                        if (_loading)
                          const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        else
                          _SignInWithGoogleButton(onPressed: _handleSignIn),
                      ],
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

/// White "Sign in with Google" button with the Google logo colours.
class _SignInWithGoogleButton extends StatelessWidget {
  const _SignInWithGoogleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF3C4043),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFDADCE0)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google "G" logo using the four brand colours
            _GoogleGLogo(),
            const SizedBox(width: 12),
            const Text(
              'Sign in with Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3C4043),
                letterSpacing: 0.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four-colour Google "G" rendered with a CustomPainter.
class _GoogleGLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(20, 20), painter: _GoogleGPainter());
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Blue arc (top-right → bottom-right)
    _drawArc(canvas, cx, cy, r, -0.25, 1.0, const Color(0xFF4285F4));
    // Red arc (top-left → top-right)
    _drawArc(canvas, cx, cy, r, 0.75, 0.5, const Color(0xFFEA4335));
    // Yellow arc (bottom-left → top-left)
    _drawArc(canvas, cx, cy, r, 1.25, 0.5, const Color(0xFFFBBC05));
    // Green arc (bottom-right → bottom-left)
    _drawArc(canvas, cx, cy, r, 1.75, 0.5, const Color(0xFF34A853));

    // White centre circle (cutout)
    canvas.drawCircle(Offset(cx, cy), r * 0.55, Paint()..color = Colors.white);

    // Horizontal bar of the "G"
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = r * 0.38
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy), Offset(cx + r * 0.9, cy), barPaint);
  }

  void _drawArc(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    double startTurns,
    double sweepTurns,
    Color color,
  ) {
    const pi2 = 6.2831853;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(cx, cy)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startTurns * pi2,
        sweepTurns * pi2,
        false,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
