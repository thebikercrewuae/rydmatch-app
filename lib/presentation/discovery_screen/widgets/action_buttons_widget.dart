import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../services/haptic_service.dart';

class ActionButtonsWidget extends StatefulWidget {
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback onSuperLike;
  final VoidCallback? onUndo;
  final bool canUndo;

  const ActionButtonsWidget({
    super.key,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.onSuperLike,
    this.onUndo,
    this.canUndo = false,
  });

  @override
  State<ActionButtonsWidget> createState() => _ActionButtonsWidgetState();
}

class _ActionButtonsWidgetState extends State<ActionButtonsWidget>
    with TickerProviderStateMixin {
  // Idle pulse animation for lightning button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Tap scale animation for lightning button
  late AnimationController _tapController;
  late Animation<double> _tapScaleAnimation;
  late Animation<double> _glowAnimation;

  // Star shimmer animation
  late AnimationController _starController;
  late Animation<double> _starGlowAnimation;

  @override
  void initState() {
    super.initState();

    // Idle pulse: subtle breathing effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Tap animation: 0.9 → 1.1 → 1.0
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _tapScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.9,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.1,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 35,
      ),
    ]).animate(_tapController);
    _glowAnimation = Tween<double>(
      begin: 14.0,
      end: 32.0,
    ).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeOut));

    // Star subtle glow pulse
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _starGlowAnimation = Tween<double>(begin: 5.0, end: 14.0).animate(
      CurvedAnimation(parent: _starController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tapController.dispose();
    _starController.dispose();
    super.dispose();
  }

  void _onLightningTap() {
    HapticService.instance.medium();
    _tapController.forward(from: 0.0);
    widget.onSwipeRight();
  }

  void _onRejectTap() {
    HapticService.instance.light();
    widget.onSwipeLeft();
  }

  void _onStarTap() {
    HapticService.instance.medium();
    widget.onSuperLike();
  }

  void _onRewindTap() {
    if (!widget.canUndo) return;
    HapticService.instance.light();
    widget.onUndo?.call();
  }

  @override
  Widget build(BuildContext context) {
    const Color gradientLeft = Color(0xFF1E90FF);
    const Color gradientRight = Color(0xFFFF6B00);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: gradientLeft.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(-8, 4),
          ),
          BoxShadow(
            color: gradientRight.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(8, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Rewind (utility, smallest, muted) ──
          GestureDetector(
            onTap: _onRewindTap,
            child: Container(
              width: 11.w,
              height: 11.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.canUndo
                    ? const Color(0xFF1E2A3A)
                    : const Color(0xFF181820),
                border: Border.all(
                  color: widget.canUndo
                      ? const Color(0xFF5A7A9A).withValues(alpha: 0.65)
                      : const Color(0xFF3A3A4A).withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.undo_rounded,
                  color: widget.canUndo
                      ? const Color(0xFF7AABCF)
                      : const Color(0xFF4A5A6A),
                  size: 17,
                ),
              ),
            ),
          ),

          SizedBox(width: 4.w),

          // ── Reject (X, outline, soft red tint) ──
          GestureDetector(
            onTap: _onRejectTap,
            child: Container(
              width: 15.w,
              height: 15.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(
                  color: const Color(0xFFE05555).withValues(alpha: 0.5),
                  width: 2.0,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.close_rounded,
                  color: const Color(0xFFE05555).withValues(alpha: 0.8),
                  size: 26,
                ),
              ),
            ),
          ),

          SizedBox(width: 5.w),

          // ── Lightning bolt (primary, center, largest) ──
          AnimatedBuilder(
            animation: Listenable.merge([
              _pulseAnimation,
              _tapScaleAnimation,
              _glowAnimation,
            ]),
            builder: (context, child) {
              final bool isTapping = _tapController.isAnimating;
              final double scale = isTapping
                  ? _tapScaleAnimation.value
                  : _pulseAnimation.value;
              final double glowBlur = isTapping ? _glowAnimation.value : 16.0;
              final double glowSpread = isTapping ? 5.0 : 1.5;
              final double glowAlpha = isTapping ? 0.65 : 0.38;

              return GestureDetector(
                onTap: _onLightningTap,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 20.w,
                    height: 20.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [gradientLeft, gradientRight],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gradientLeft.withValues(alpha: glowAlpha),
                          blurRadius: glowBlur,
                          spreadRadius: glowSpread,
                          offset: const Offset(-3, 0),
                        ),
                        BoxShadow(
                          color: gradientRight.withValues(alpha: glowAlpha),
                          blurRadius: glowBlur,
                          spreadRadius: glowSpread,
                          offset: const Offset(3, 0),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          SizedBox(width: 5.w),

          // ── Star (premium, orange accent, subtle glow) ──
          AnimatedBuilder(
            animation: _starGlowAnimation,
            builder: (context, child) {
              return GestureDetector(
                onTap: _onStarTap,
                child: Container(
                  width: 15.w,
                  height: 15.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E1A0A),
                    border: Border.all(
                      color: const Color(0xFFFF8C00).withValues(alpha: 0.55),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8C00).withValues(alpha: 0.28),
                        blurRadius: _starGlowAnimation.value,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFF8C00),
                      size: 26,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
