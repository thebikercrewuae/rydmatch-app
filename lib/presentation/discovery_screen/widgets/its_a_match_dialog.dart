import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class ItsAMatchDialog extends StatefulWidget {
  final String currentUserName;
  final String? currentUserPhoto;
  final String matchedUserName;
  final String? matchedUserPhoto;
  final VoidCallback onSendMessage;
  final VoidCallback onKeepSwiping;

  const ItsAMatchDialog({
    super.key,
    required this.currentUserName,
    this.currentUserPhoto,
    required this.matchedUserName,
    this.matchedUserPhoto,
    required this.onSendMessage,
    required this.onKeepSwiping,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentUserName,
    String? currentUserPhoto,
    required String matchedUserName,
    String? matchedUserPhoto,
    required VoidCallback onSendMessage,
    required VoidCallback onKeepSwiping,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => ItsAMatchDialog(
        currentUserName: currentUserName,
        currentUserPhoto: currentUserPhoto,
        matchedUserName: matchedUserName,
        matchedUserPhoto: matchedUserPhoto,
        onSendMessage: onSendMessage,
        onKeepSwiping: onKeepSwiping,
      ),
    );
  }

  @override
  State<ItsAMatchDialog> createState() => _ItsAMatchDialogState();
}

class _ItsAMatchDialogState extends State<ItsAMatchDialog>
    with TickerProviderStateMixin {
  // Lightning bolt scale animation
  late AnimationController _boltController;
  late Animation<double> _boltScale;

  // Glow intensity animation (burst then settle)
  late AnimationController _glowController;
  late Animation<double> _glowIntensity;

  // Continuous pulse on the bolt
  late AnimationController _pulseController;
  late Animation<double> _pulseOpacity;

  // Energy streak animation
  late AnimationController _streakController;
  late Animation<double> _streakProgress;

  static const Color _blueColor = Color(0xFF1E90FF);
  static const Color _orangeColor = Color(0xFFFF6B1A);

  @override
  void initState() {
    super.initState();

    // Bolt entrance: 0.9 → 1.1 → 1.0 over 400ms
    _boltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _boltScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.9,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.1,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 45,
      ),
    ]).animate(_boltController);

    // Glow burst then settle over 500ms
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
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.45,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_glowController);

    // Continuous subtle pulse on bolt
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Energy streaks from profiles to center
    _streakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _streakProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _streakController, curve: Curves.easeOut),
    );

    // Sequence: streaks → bolt entrance → glow
    _streakController.forward().then((_) {
      _boltController.forward();
      _glowController.forward();
    });
  }

  @override
  void dispose() {
    _boltController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    _streakController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B365D), Color(0xFF2E5FA3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24.0),
        ),
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Motorcycle icon
            Container(
              width: 14.w,
              height: 14.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              child: const Center(
                child: Text('🏍️', style: TextStyle(fontSize: 28)),
              ),
            ),
            SizedBox(height: 1.5.h),
            Text(
              "It's a Match!",
              style: GoogleFonts.dmSans(
                fontSize: 22.0,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 0.5.h),
            Text(
              'You and ${widget.matchedUserName} both swiped right!',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13.0,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            SizedBox(height: 3.h),
            // Profile photos + lightning bolt row
            AnimatedBuilder(
              animation: Listenable.merge([
                _glowIntensity,
                _boltScale,
                _pulseOpacity,
                _streakProgress,
              ]),
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Left profile — blue glow
                    _GlowProfileCircle(
                      imageUrl: widget.currentUserPhoto,
                      name: widget.currentUserName,
                      semanticLabel:
                          '${widget.currentUserName} profile photo in match screen',
                      glowColor: _blueColor,
                      glowIntensity: _glowIntensity.value,
                    ),
                    SizedBox(width: 2.w),
                    // Energy streaks + lightning bolt
                    SizedBox(
                      width: 14.w,
                      height: 14.w,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Blue streak from left
                          if (_streakProgress.value > 0)
                            Positioned(
                              left: 0,
                              child: _EnergyStreak(
                                progress: _streakProgress.value,
                                color: _blueColor,
                                fromLeft: true,
                                width: 7.w,
                              ),
                            ),
                          // Orange streak from right
                          if (_streakProgress.value > 0)
                            Positioned(
                              right: 0,
                              child: _EnergyStreak(
                                progress: _streakProgress.value,
                                color: _orangeColor,
                                fromLeft: false,
                                width: 7.w,
                              ),
                            ),
                          // Lightning bolt with glow
                          Opacity(
                            opacity: _pulseOpacity.value,
                            child: Transform.scale(
                              scale: _boltScale.value,
                              child: _GradientLightningBolt(
                                size: 10.w,
                                glowIntensity: _glowIntensity.value,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 2.w),
                    // Right profile — orange glow
                    _GlowProfileCircle(
                      imageUrl: widget.matchedUserPhoto,
                      name: widget.matchedUserName,
                      semanticLabel:
                          '${widget.matchedUserName} profile photo in match screen',
                      glowColor: _orangeColor,
                      glowIntensity: _glowIntensity.value,
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 3.h),
            // Send a Message button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onSendMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B1A),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 1.6.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Send a Message',
                  style: GoogleFonts.dmSans(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: 1.h),
            // Keep Swiping button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onKeepSwiping,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  padding: EdgeInsets.symmetric(vertical: 1.6.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                ),
                child: Text(
                  'Keep Swiping',
                  style: GoogleFonts.dmSans(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
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
          // Blue glow left
          BoxShadow(
            color: const Color(
              0xFF1E90FF,
            ).withValues(alpha: 0.55 * glowIntensity),
            blurRadius: 18 + (10 * glowIntensity),
            spreadRadius: 2 + (4 * glowIntensity),
            offset: const Offset(-3, 0),
          ),
          // Orange glow right
          BoxShadow(
            color: const Color(
              0xFFFF6B1A,
            ).withValues(alpha: 0.55 * glowIntensity),
            blurRadius: 18 + (10 * glowIntensity),
            spreadRadius: 2 + (4 * glowIntensity),
            offset: const Offset(3, 0),
          ),
          // Center white core glow
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.15 * glowIntensity),
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
    final gradient = LinearGradient(
      colors: const [Color(0xFF1E90FF), Color(0xFFFF6B1A)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    // Lightning bolt path — clean minimal shape
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Bolt points (percentage-based for any size)
    path.moveTo(w * 0.62, h * 0.04); // top-right
    path.lineTo(w * 0.30, h * 0.50); // middle-left
    path.lineTo(w * 0.50, h * 0.50); // middle-center
    path.lineTo(w * 0.38, h * 0.96); // bottom-left
    path.lineTo(w * 0.70, h * 0.46); // middle-right
    path.lineTo(w * 0.50, h * 0.46); // middle-center
    path.close();

    canvas.drawPath(path, paint);

    // Subtle white highlight on top half for depth
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
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
      width: 22.w,
      height: 22.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          // Colored glow
          BoxShadow(
            color: glowColor.withValues(alpha: 0.35 + (0.45 * glowIntensity)),
            blurRadius: 12 + (20 * glowIntensity),
            spreadRadius: 1 + (6 * glowIntensity),
          ),
          // Base shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
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
      color: const Color(0xFF2E5FA3),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
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
      opacity: (1.0 - progress).clamp(0.0, 1.0),
      child: Container(
        width: width * progress,
        height: 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.0),
              color.withValues(alpha: 0.8),
            ],
            begin: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: fromLeft ? Alignment.centerRight : Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(1.0),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
          ],
        ),
      ),
    );
  }
}
