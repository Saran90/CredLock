import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Glow pulse behind logo
  late final AnimationController _glowController;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;

  // Rotating arc ring
  late final AnimationController _ringController;
  late final Animation<double> _ringRotation;
  late final Animation<double> _ringScale;

  // Logo pop-in
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // Lock shackle draw animation
  late final AnimationController _lockController;
  late final Animation<double> _lockProgress;

  // App name letter-by-letter reveal
  late final AnimationController _textController;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  // Tagline fade + slide up
  late final AnimationController _taglineController;
  late final Animation<double> _taglineOpacity;
  late final Animation<Offset> _taglineSlide;

  // Bottom shimmer bar
  late final AnimationController _shimmerController;

  // Exit fade
  late final AnimationController _exitController;
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    // Glow pulse — repeating breathe
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glowScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowOpacity = Tween<double>(begin: 0.0, end: 0.35).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Arc ring spin
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _ringRotation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _ringController, curve: Curves.easeOut));
    _ringScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    // Logo pop
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Lock draw
    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _lockProgress = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _lockController, curve: Curves.easeOut));

    // App name
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    // Tagline
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeIn),
    );
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _taglineController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Shimmer sweep
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Exit
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeIn));
  }

  Future<void> _startSequence() async {
    // 1. Glow starts pulsing immediately (repeating)
    _glowController.repeat(reverse: true);

    // 2. Ring spins in
    await Future.delayed(const Duration(milliseconds: 100));
    _ringController.forward();

    // 3. Logo pops in after ring starts
    await Future.delayed(const Duration(milliseconds: 400));
    _logoController.forward();

    // 4. Lock draw
    await Future.delayed(const Duration(milliseconds: 300));
    _lockController.forward();

    // 5. App name slides up
    await Future.delayed(const Duration(milliseconds: 300));
    _textController.forward();

    // 6. Tagline
    await Future.delayed(const Duration(milliseconds: 300));
    _taglineController.forward();

    // 7. Shimmer sweep
    await Future.delayed(const Duration(milliseconds: 200));
    _shimmerController.forward();

    // 8. Hold, then exit
    await Future.delayed(const Duration(milliseconds: 1200));
    _glowController.stop();
    await _exitController.forward();

    if (mounted) {
      final destination = AuthService.instance.isSignedIn
          ? const HomeScreen()
          : const LoginScreen();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => destination,
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _ringController.dispose();
    _logoController.dispose();
    _lockController.dispose();
    _textController.dispose();
    _taglineController.dispose();
    _shimmerController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _exitOpacity,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // ── Ambient orange blobs ──────────────────────────────────────
            _AmbientBlob(
              alignment: const Alignment(0.6, -0.7),
              color: AppColors.primaryDark.withValues(alpha: 0.18),
              size: size.width * 0.7,
            ),
            _AmbientBlob(
              alignment: const Alignment(-0.7, 0.8),
              color: AppColors.primary.withValues(alpha: 0.12),
              size: size.width * 0.6,
            ),

            // ── Particle dots ─────────────────────────────────────────────
            ...List.generate(
              12,
              (i) => _ParticleDot(index: i, screenSize: size),
            ),

            // ── Main content ──────────────────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo stack: glow + ring + icon
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow blob
                        AnimatedBuilder(
                          animation: _glowController,
                          builder: (_, _) => Transform.scale(
                            scale: _glowScale.value,
                            child: Opacity(
                              opacity: _glowOpacity.value,
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primaryDark.withValues(
                                        alpha: 0.0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Rotating arc ring
                        AnimatedBuilder(
                          animation: _ringController,
                          builder: (_, _) => Transform.scale(
                            scale: _ringScale.value,
                            child: Transform.rotate(
                              angle: _ringRotation.value,
                              child: CustomPaint(
                                size: const Size(140, 140),
                                painter: _ArcRingPainter(),
                              ),
                            ),
                          ),
                        ),

                        // Logo circle with lock icon
                        AnimatedBuilder(
                          animation: _logoController,
                          builder: (_, _) => Transform.scale(
                            scale: _logoScale.value,
                            child: Opacity(
                              opacity: _logoOpacity.value,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: const BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: AnimatedBuilder(
                                  animation: _lockController,
                                  builder: (_, _) => CustomPaint(
                                    painter: _LockIconPainter(
                                      progress: _lockProgress.value,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // App name with shimmer
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _textController,
                      _shimmerController,
                    ]),
                    builder: (_, _) => FadeTransition(
                      opacity: _textOpacity,
                      child: SlideTransition(
                        position: _textSlide,
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            final shimmerPos = _shimmerController.value;
                            return LinearGradient(
                              colors: const [
                                AppColors.primary,
                                AppColors.primaryLight,
                                Colors.white,
                                AppColors.primaryLight,
                                AppColors.primary,
                              ],
                              stops: [
                                (shimmerPos - 0.4).clamp(0.0, 1.0),
                                (shimmerPos - 0.15).clamp(0.0, 1.0),
                                shimmerPos.clamp(0.0, 1.0),
                                (shimmerPos + 0.15).clamp(0.0, 1.0),
                                (shimmerPos + 0.4).clamp(0.0, 1.0),
                              ],
                            ).createShader(bounds);
                          },
                          child: const Text(
                            'credlock',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Tagline
                  FadeTransition(
                    opacity: _taglineOpacity,
                    child: SlideTransition(
                      position: _taglineSlide,
                      child: const Text(
                        'Your secrets, locked tight.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom loading bar ────────────────────────────────────────
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 80),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _shimmerController.value,
                          backgroundColor: AppColors.surface,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                          minHeight: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Securing your vault...',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ambient background blob ───────────────────────────────────────────────────

class _AmbientBlob extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final double size;

  const _AmbientBlob({
    required this.alignment,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

// ── Floating particle dot ─────────────────────────────────────────────────────

class _ParticleDot extends StatefulWidget {
  final int index;
  final Size screenSize;

  const _ParticleDot({required this.index, required this.screenSize});

  @override
  State<_ParticleDot> createState() => _ParticleDotState();
}

class _ParticleDotState extends State<_ParticleDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final double _x;
  late final double _y;
  late final double _dotSize;
  late final double _delay;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.index * 37 + 13);
    _x = rng.nextDouble() * widget.screenSize.width;
    _y = rng.nextDouble() * widget.screenSize.height;
    _dotSize = rng.nextDouble() * 3 + 1.5;
    _delay = rng.nextDouble() * 1000;

    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1600 + (rng.nextInt(800))),
    );

    Future.delayed(Duration(milliseconds: _delay.toInt()), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _x,
      top: _y,
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 0.0,
          end: 0.6,
        ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
        child: Container(
          width: _dotSize,
          height: _dotSize,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ── Arc ring painter ──────────────────────────────────────────────────────────

class _ArcRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Outer dashed arc segments
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const segments = 8;
    const gapFraction = 0.18;
    const segmentAngle = (2 * math.pi) / segments;
    const drawAngle = segmentAngle * (1 - gapFraction);

    for (int i = 0; i < segments; i++) {
      final startAngle = i * segmentAngle;
      final t = i / segments;
      arcPaint.color = Color.lerp(
        AppColors.primaryLight,
        AppColors.primaryDark,
        t,
      )!.withValues(alpha: 0.7);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        drawAngle,
        false,
        arcPaint,
      );
    }

    // Inner thin ring
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.primary.withValues(alpha: 0.2);
    canvas.drawCircle(center, radius - 10, innerPaint);

    // Dot accents at segment joints
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < segments; i++) {
      final angle = i * segmentAngle;
      final dx = center.dx + radius * math.cos(angle);
      final dy = center.dy + radius * math.sin(angle);
      dotPaint.color = AppColors.primaryLight.withValues(alpha: 0.9);
      canvas.drawCircle(Offset(dx, dy), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Lock icon painter (draws progressively) ───────────────────────────────────

class _LockIconPainter extends CustomPainter {
  final double progress;

  const _LockIconPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Body rect (draws first 60% of progress)
    if (progress > 0) {
      final bodyProgress = (progress / 0.6).clamp(0.0, 1.0);
      final bodyRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + 6),
          width: 26,
          height: 20 * bodyProgress,
        ),
        const Radius.circular(4),
      );
      final bodyFill = Paint()
        ..color = Colors.black.withValues(alpha: 0.7 * bodyProgress)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(bodyRect, bodyFill);
      canvas.drawRRect(
        bodyRect,
        paint..color = Colors.black.withValues(alpha: 0.85 * bodyProgress),
      );
    }

    // Shackle arc (draws last 40% of progress)
    if (progress > 0.6) {
      final shackleProgress = ((progress - 0.6) / 0.4).clamp(0.0, 1.0);
      final shacklePaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      final shackleRect = Rect.fromCenter(
        center: Offset(cx, cy - 2),
        width: 18,
        height: 16,
      );
      canvas.drawArc(
        shackleRect,
        math.pi,
        math.pi * shackleProgress,
        false,
        shacklePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LockIconPainter old) =>
      old.progress != progress;
}
