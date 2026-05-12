import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class MatchSuccessScreen extends StatefulWidget {
  final String currentUserName;
  final String? currentUserPhoto;
  final String matchedUserName;
  final String? matchedUserPhoto;
  final String matchedUserId;
  final VoidCallback onStartChat;
  final VoidCallback onKeepSwiping;

  const MatchSuccessScreen({
    super.key,
    required this.currentUserName,
    this.currentUserPhoto,
    required this.matchedUserName,
    this.matchedUserPhoto,
    required this.matchedUserId,
    required this.onStartChat,
    required this.onKeepSwiping,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentUserName,
    String? currentUserPhoto,
    required String matchedUserName,
    String? matchedUserPhoto,
    required String matchedUserId,
    required VoidCallback onStartChat,
    required VoidCallback onKeepSwiping,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => MatchSuccessScreen(
          currentUserName: currentUserName,
          currentUserPhoto: currentUserPhoto,
          matchedUserName: matchedUserName,
          matchedUserPhoto: matchedUserPhoto,
          matchedUserId: matchedUserId,
          onStartChat: onStartChat,
          onKeepSwiping: onKeepSwiping,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<MatchSuccessScreen> createState() => _MatchSuccessScreenState();
}

class _MatchSuccessScreenState extends State<MatchSuccessScreen>
    with TickerProviderStateMixin {
  static const Color _blue = Color(0xFF1E90FF);
  static const Color _orange = Color(0xFFFF6B1A);

  // Background fade-in
  late AnimationController _bgController;
  late Animation<double> _bgOpacity;

  // Profile slide-in
  late AnimationController _profileController;
  late Animation<double> _leftSlide;
  late Animation<double> _rightSlide;
  late Animation<double> _profileOpacity;

  // Energy streaks
  late AnimationController _streakController;
  late Animation<double> _streakProgress;

  // Lightning bolt entrance
  late AnimationController _boltController;
  late Animation<double> _boltScale;
  late Animation<double> _boltOpacity;

  // Glow burst
  late AnimationController _glowController;
  late Animation<double> _glowIntensity;

  // Profile pulse on impact
  late AnimationController _pulseController;
  late Animation<double> _profileScale;

  // Continuous bolt pulse
  late AnimationController _idlePulseController;
  late Animation<double> _idlePulse;

  // Text + buttons fade-in
  late AnimationController _textController;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  // Particles
  final List<_Particle> _particles = [];
  late AnimationController _particleController;

  bool _hapticDone = false;

  @override
  void initState() {
    super.initState();
    _initParticles();
    _setupAnimations();
    _runSequence();
  }

  void _initParticles() {
    final rng = math.Random();
    for (int i = 0; i < 18; i++) {
      _particles.add(
        _Particle(
          angle: rng.nextDouble() * 2 * math.pi,
          speed: 0.4 + rng.nextDouble() * 0.6,
          size: 1.5 + rng.nextDouble() * 2.5,
          color: rng.nextBool() ? _blue : _orange,
          delay: rng.nextDouble() * 0.3,
        ),
      );
    }
  }

  void _setupAnimations() {
    // Background
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bgOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeOut));

    // Profiles slide in
    _profileController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _leftSlide = Tween<double>(begin: -60.0, end: 0.0).animate(
      CurvedAnimation(parent: _profileController, curve: Curves.easeOutCubic),
    );
    _rightSlide = Tween<double>(begin: 60.0, end: 0.0).animate(
      CurvedAnimation(parent: _profileController, curve: Curves.easeOutCubic),
    );
    _profileOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _profileController, curve: Curves.easeOut),
    );

    // Energy streaks
    _streakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _streakProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _streakController, curve: Curves.easeOut),
    );

    // Bolt entrance
    _boltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _boltScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_boltController);
    _boltOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _boltController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Glow burst
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _glowIntensity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.5,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 65,
      ),
    ]).animate(_glowController);

    // Profile pulse on impact
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _profileScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.06,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_pulseController);

    // Idle bolt pulse
    _idlePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _idlePulse = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _idlePulseController, curve: Curves.easeInOut),
    );

    // Particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Text + buttons
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );
  }

  Future<void> _runSequence() async {
    // Step 1: Background fades in
    _bgController.forward();
    await Future.delayed(const Duration(milliseconds: 100));

    // Step 2: Profiles slide in
    _profileController.forward();
    await Future.delayed(const Duration(milliseconds: 350));

    // Step 3: Energy streaks
    _streakController.forward();
    await Future.delayed(const Duration(milliseconds: 250));

    // Step 4: Bolt appears + glow burst + particle spark
    _boltController.forward();
    _glowController.forward();
    _particleController.forward();
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 5: Profile pulse on impact
    _pulseController.forward();

    // Haptic feedback
    if (!_hapticDone) {
      _hapticDone = true;
      HapticFeedback.mediumImpact();
    }

    await Future.delayed(const Duration(milliseconds: 200));

    // Step 6: Text + buttons fade in
    _textController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _profileController.dispose();
    _streakController.dispose();
    _boltController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    _idlePulseController.dispose();
    _particleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _bgOpacity,
          _profileOpacity,
          _leftSlide,
          _rightSlide,
          _streakProgress,
          _boltScale,
          _boltOpacity,
          _glowIntensity,
          _profileScale,
          _idlePulse,
          _textOpacity,
          _textSlide,
          _particleController,
        ]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Blurred dark background ──────────────────────────────────
              Opacity(
                opacity: _bgOpacity.value,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xE6080E1A),
                        Color(0xE6101828),
                        Color(0xE6080E1A),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // ── Ambient glow blobs ───────────────────────────────────────
              Opacity(
                opacity: _bgOpacity.value * 0.6,
                child: Stack(
                  children: [
                    Positioned(
                      left: -10.w,
                      top: 15.h,
                      child: Container(
                        width: 50.w,
                        height: 50.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _blue.withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -10.w,
                      top: 15.h,
                      child: Container(
                        width: 50.w,
                        height: 50.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _orange.withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Main content ─────────────────────────────────────────────
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 2.h),

                    // ── Profile row ────────────────────────────────────────
                    SizedBox(
                      height: 28.w,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Left profile
                          Positioned(
                            left: 8.w,
                            child: Transform.translate(
                              offset: Offset(_leftSlide.value, 0),
                              child: Opacity(
                                opacity: _profileOpacity.value,
                                child: Transform.scale(
                                  scale: _profileScale.value,
                                  child: _GlowProfileCircle(
                                    imageUrl: widget.currentUserPhoto,
                                    name: widget.currentUserName,
                                    semanticLabel:
                                        '${widget.currentUserName} profile photo',
                                    glowColor: _blue,
                                    glowIntensity: _glowIntensity.value,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Right profile
                          Positioned(
                            right: 8.w,
                            child: Transform.translate(
                              offset: Offset(_rightSlide.value, 0),
                              child: Opacity(
                                opacity: _profileOpacity.value,
                                child: Transform.scale(
                                  scale: _profileScale.value,
                                  child: _GlowProfileCircle(
                                    imageUrl: widget.matchedUserPhoto,
                                    name: widget.matchedUserName,
                                    semanticLabel:
                                        '${widget.matchedUserName} profile photo',
                                    glowColor: _orange,
                                    glowIntensity: _glowIntensity.value,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Center: streaks + bolt + particles
                          Center(
                            child: SizedBox(
                              width: 28.w,
                              height: 28.w,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Blue streak from left
                                  if (_streakProgress.value > 0)
                                    Positioned(
                                      left: 0,
                                      top: 13.w,
                                      child: _EnergyStreak(
                                        progress: _streakProgress.value,
                                        color: _blue,
                                        fromLeft: true,
                                        width: 14.w,
                                      ),
                                    ),
                                  // Orange streak from right
                                  if (_streakProgress.value > 0)
                                    Positioned(
                                      right: 0,
                                      top: 13.w,
                                      child: _EnergyStreak(
                                        progress: _streakProgress.value,
                                        color: _orange,
                                        fromLeft: false,
                                        width: 14.w,
                                      ),
                                    ),

                                  // Particle sparks
                                  if (_particleController.value > 0)
                                    CustomPaint(
                                      size: Size(28.w, 28.w),
                                      painter: _ParticlePainter(
                                        particles: _particles,
                                        progress: _particleController.value,
                                        radius: 10.w,
                                      ),
                                    ),

                                  // Lightning bolt
                                  Opacity(
                                    opacity: _boltOpacity.value,
                                    child: Transform.scale(
                                      scale: _boltScale.value,
                                      child: Opacity(
                                        opacity: _idlePulse.value,
                                        child: _GradientLightningBolt(
                                          size: 14.w,
                                          glowIntensity: _glowIntensity.value,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 4.h),

                    // ── Text + buttons ─────────────────────────────────────
                    FadeTransition(
                      opacity: _textOpacity,
                      child: SlideTransition(
                        position: _textSlide,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: Column(
                            children: [
                              // Headline
                              Text(
                                "It's a match. Let's ride ⚡",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  fontSize: 22.0,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: 1.2.h),
                              // Subtext
                              Text(
                                'Start a conversation and plan your next ride.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.72),
                                  height: 1.5,
                                ),
                              ),
                              SizedBox(height: 4.h),

                              // Primary: Start Chat
                              _GradientButton(
                                label: 'Start Chat',
                                onTap: widget.onStartChat,
                              ),
                              SizedBox(height: 1.5.h),

                              // Secondary: Keep Swiping
                              TextButton(
                                onPressed: widget.onKeepSwiping,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white.withValues(
                                    alpha: 0.65,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6.w,
                                    vertical: 1.2.h,
                                  ),
                                ),
                                child: Text(
                                  'Keep Swiping',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Gradient "Start Chat" Button ─────────────────────────────────────────

class _GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientButton({required this.label, required this.onTap});

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _tapScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.95,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.95,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_tapController);
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tapScale,
      builder: (context, child) =>
          Transform.scale(scale: _tapScale.value, child: child),
      child: GestureDetector(
        onTapDown: (_) => _tapController.forward(),
        onTapUp: (_) {
          _tapController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _tapController.reverse(),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 1.8.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E90FF), Color(0xFFFF6B1A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E90FF).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(-4, 4),
              ),
              BoxShadow(
                color: const Color(0xFFFF6B1A).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: GoogleFonts.dmSans(
                fontSize: 15.0,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Gradient Lightning Bolt ───────────────────────────────────────────────

class _GradientLightningBolt extends StatelessWidget {
  final double size;
  final double glowIntensity;

  const _GradientLightningBolt({
    required this.size,
    required this.glowIntensity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF1E90FF,
            ).withValues(alpha: 0.5 + 0.4 * glowIntensity),
            blurRadius: 16 + 14 * glowIntensity,
            spreadRadius: 2 + 5 * glowIntensity,
            offset: const Offset(-2, 0),
          ),
          BoxShadow(
            color: const Color(
              0xFFFF6B1A,
            ).withValues(alpha: 0.5 + 0.4 * glowIntensity),
            blurRadius: 16 + 14 * glowIntensity,
            spreadRadius: 2 + 5 * glowIntensity,
            offset: const Offset(2, 0),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.12 * glowIntensity),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _LightningBoltPainter(),
      ),
    );
  }
}

class _LightningBoltPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient = const LinearGradient(
      colors: [Color(0xFF1E90FF), Color(0xFFFF6B1A)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.62, h * 0.04);
    path.lineTo(w * 0.30, h * 0.50);
    path.lineTo(w * 0.50, h * 0.50);
    path.lineTo(w * 0.38, h * 0.96);
    path.lineTo(w * 0.70, h * 0.46);
    path.lineTo(w * 0.50, h * 0.46);
    path.close();
    canvas.drawPath(path, paint);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final highlightPath = Path();
    highlightPath.moveTo(w * 0.62, h * 0.04);
    highlightPath.lineTo(w * 0.30, h * 0.50);
    highlightPath.lineTo(w * 0.50, h * 0.50);
    highlightPath.lineTo(w * 0.56, h * 0.04);
    highlightPath.close();
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Profile Circle with Glow ──────────────────────────────────────────────

class _GlowProfileCircle extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String semanticLabel;
  final Color glowColor;
  final double glowIntensity;

  const _GlowProfileCircle({
    required this.imageUrl,
    required this.name,
    required this.semanticLabel,
    required this.glowColor,
    required this.glowIntensity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24.w,
      height: 24.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.3 + 0.5 * glowIntensity),
            blurRadius: 10 + 22 * glowIntensity,
            spreadRadius: 1 + 7 * glowIntensity,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: (imageUrl != null && imageUrl!.isNotEmpty)
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                semanticLabel: semanticLabel,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1B365D),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Energy Streak ─────────────────────────────────────────────────────────

class _EnergyStreak extends StatelessWidget {
  final double progress;
  final Color color;
  final bool fromLeft;
  final double width;

  const _EnergyStreak({
    required this.progress,
    required this.color,
    required this.fromLeft,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: (1.0 - progress * 0.6).clamp(0.0, 1.0),
      child: Container(
        width: width * progress,
        height: 2.5,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.0),
              color.withValues(alpha: 0.9),
            ],
            begin: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: fromLeft ? Alignment.centerRight : Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(2.0),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

// ─── Particle Spark Painter ────────────────────────────────────────────────

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double delay;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.delay,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final double radius;

  const _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      final t = ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final dist = radius * t * p.speed;
      final opacity = (1.0 - t).clamp(0.0, 1.0);

      final dx = math.cos(p.angle) * dist;
      final dy = math.sin(p.angle) * dist;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity * 0.85)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        center + Offset(dx, dy),
        p.size * (1.0 - t * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
