import 'package:flutter/material.dart';
import '../../../services/haptic_service.dart';

class StarRatingWidget extends StatefulWidget {
  final int rating;
  final double starSize;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<int> onRatingChanged;

  const StarRatingWidget({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.starSize = 40.0,
    this.activeColor = const Color(0xFFFF8C00),
    this.inactiveColor = const Color(0xFFE0E0E0),
  });

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      5,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      ),
    );
    _scaleAnimations = _controllers
        .map(
          (c) => Tween<double>(
            begin: 1.0,
            end: 1.3,
          ).animate(CurvedAnimation(parent: c, curve: Curves.elasticOut)),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTap(int index) {
    HapticService.instance.light();
    _controllers[index].forward().then((_) => _controllers[index].reverse());
    widget.onRatingChanged(index + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < widget.rating;
        return GestureDetector(
          onTap: () => _onTap(i),
          child: AnimatedBuilder(
            animation: _scaleAnimations[i],
            builder: (context, child) => Transform.scale(
              scale: _scaleAnimations[i].value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: widget.starSize,
                  color: filled ? widget.activeColor : widget.inactiveColor,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
