import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

/// Overlay widget that plays the match interaction animation:
/// - Left profile emits blue glow
/// - Right profile emits orange glow
/// - Energy streaks move toward center
/// - Lightning bolt appears in center with scale + glow burst
/// - Profiles pulse/lift
class MatchInteractionOverlay extends StatefulWidget {
  final String? leftPhotoUrl;
  final String? rightPhotoUrl;
  final VoidCallback onComplete;

  const MatchInteractionOverlay({
    super.key,
    this.leftPhotoUrl,
    this.rightPhotoUrl,
    required this.onComplete,
  });

  @override
  State<MatchInteractionOverlay> createState() =>
      _MatchInteractionOverlayState();
}

class _MatchInteractionOverlayState extends State<MatchInteractionOverlay>
    with TickerProviderStateMixin {
  // Profile glow + lift
  late AnimationController _profileController;
  late Animation<double> _profileGlow;
  late Animation<double> _profileLift;

  // Energy streaks
  late AnimationController _streakController;
  late Animation<double> _streakProgress;

  // Lightning bolt center burst
  late AnimationController _boltController;
  late Animation<double> _boltScale;
  late Animation<double> _boltGlow;
  late Animation<double> _boltOpacity;

  // Overall fade out
  late AnimationController _fadeController;
  late Animation<double> _fadeOpacity;

  @override
  void initState() {
    super.initState();

    // Profile glow + lift: 0 → peak → settle
    _profileController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _profileGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _profileController, curve: Curves.easeOut),
    );
    _profileLift = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _profileController, curve: Curves.easeOut),
    );

    // Streaks move from edges to center
    _streakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _streakProgress = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _streakController, curve: Curves.easeIn));

    // Lightning bolt burst in center
    _boltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _boltScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_boltController);
    _boltGlow = Tween<double>(
      begin: 0.0,
      end: 40.0,
    ).animate(CurvedAnimation(parent: _boltController, curve: Curves.easeOut));
    _boltOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _boltController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Fade out everything
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Step 1: Profile glow + streaks simultaneously
    await Future.wait([
      _profileController.forward(),
      _streakController.forward(),
    ]);

    // Step 2: Lightning bolt burst
    await _boltController.forward();

    // Brief hold at peak
    await Future.delayed(const Duration(milliseconds: 120));

    // Step 3: Fade out
    await _fadeController.forward();

    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _profileController.dispose();
    _streakController.dispose();
    _boltController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _profileGlow,
        _profileLift,
        _streakProgress,
        _boltScale,
        _boltGlow,
        _boltOpacity,
        _fadeOpacity,
      ]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeOpacity.value,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Left profile glow (blue) ──
                Positioned(
                  left: 8.w,
                  top: 0,
                  bottom: 0,
                  child: Transform.translate(
                    offset: Offset(0, _profileLift.value),
                    child: Container(
                      width: 28.w,
                      height: 28.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF1E90FF,
                            ).withValues(alpha: 0.55 * _profileGlow.value),
                            blurRadius: 40 * _profileGlow.value,
                            spreadRadius: 8 * _profileGlow.value,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: widget.leftPhotoUrl != null
                            ? Image.network(
                                widget.leftPhotoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _placeholderAvatar(const Color(0xFF1E90FF)),
                              )
                            : _placeholderAvatar(const Color(0xFF1E90FF)),
                      ),
                    ),
                  ),
                ),

                // ── Right profile glow (orange) ──
                Positioned(
                  right: 8.w,
                  top: 0,
                  bottom: 0,
                  child: Transform.translate(
                    offset: Offset(0, _profileLift.value),
                    child: Container(
                      width: 28.w,
                      height: 28.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFF6B00,
                            ).withValues(alpha: 0.55 * _profileGlow.value),
                            blurRadius: 40 * _profileGlow.value,
                            spreadRadius: 8 * _profileGlow.value,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: widget.rightPhotoUrl != null
                            ? Image.network(
                                widget.rightPhotoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _placeholderAvatar(const Color(0xFFFF6B00)),
                              )
                            : _placeholderAvatar(const Color(0xFFFF6B00)),
                      ),
                    ),
                  ),
                ),

                // ── Energy streaks (left → center) ──
                Positioned(
                  left: 28.w,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _EnergyStreak(
                      progress: _streakProgress.value,
                      color: const Color(0xFF1E90FF),
                      direction: StreakDirection.right,
                    ),
                  ),
                ),

                // ── Energy streaks (right → center) ──
                Positioned(
                  right: 28.w,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _EnergyStreak(
                      progress: _streakProgress.value,
                      color: const Color(0xFFFF6B00),
                      direction: StreakDirection.left,
                    ),
                  ),
                ),

                // ── Lightning bolt center burst ──
                Center(
                  child: Opacity(
                    opacity: _boltOpacity.value,
                    child: Transform.scale(
                      scale: _boltScale.value,
                      child: Container(
                        width: 18.w,
                        height: 18.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E90FF), Color(0xFFFF6B00)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF1E90FF,
                              ).withValues(alpha: 0.6),
                              blurRadius: _boltGlow.value,
                              spreadRadius: _boltGlow.value * 0.2,
                              offset: const Offset(-4, 0),
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFFFF6B00,
                              ).withValues(alpha: 0.6),
                              blurRadius: _boltGlow.value,
                              spreadRadius: _boltGlow.value * 0.2,
                              offset: const Offset(4, 0),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.bolt_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── "It's a Match!" label ──
                Positioned(
                  bottom: 8.h,
                  child: Opacity(
                    opacity: _boltOpacity.value,
                    child: Transform.scale(
                      scale: _boltScale.value.clamp(0.0, 1.0),
                      child: Text(
                        "It's a Match! ⚡",
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: const Color(
                                0xFF1E90FF,
                              ).withValues(alpha: 0.8),
                              blurRadius: 16,
                            ),
                            Shadow(
                              color: const Color(
                                0xFFFF6B00,
                              ).withValues(alpha: 0.6),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placeholderAvatar(Color color) {
    return Container(
      color: color.withValues(alpha: 0.2),
      child: Icon(Icons.person_rounded, color: color, size: 32),
    );
  }
}

enum StreakDirection { left, right }

class _EnergyStreak extends StatelessWidget {
  final double progress;
  final Color color;
  final StreakDirection direction;

  const _EnergyStreak({
    required this.progress,
    required this.color,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();

    final double width = 20.w * progress;
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Container(
        width: width,
        height: 2.5,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2.0),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.0),
              color.withValues(alpha: 0.85),
            ],
            begin: direction == StreakDirection.right
                ? Alignment.centerLeft
                : Alignment.centerRight,
            end: direction == StreakDirection.right
                ? Alignment.centerRight
                : Alignment.centerLeft,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
