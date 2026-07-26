import 'package:flutter/material.dart';

class PioneerMemberBadge extends StatelessWidget {
  const PioneerMemberBadge({
    super.key,
    required this.number,
    this.compact = false,
  });

  final int number;
  final bool compact;

  static const Color navy = Color(0xFF173A63);
  static const Color gold = Color(0xFFF2B544);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pioneer Member number $number',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: gold, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: compact ? 13 : 16,
              color: gold,
            ),
            const SizedBox(width: 4),
            Text(
              compact ? 'Pioneer #$number' : 'Pioneer Member #$number',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PioneerAvatarFrame extends StatelessWidget {
  const PioneerAvatarFrame({
    super.key,
    required this.child,
    required this.isPioneer,
    this.padding = 4,
    this.shape = BoxShape.circle,
    this.borderRadius,
  });

  final Widget child;
  final bool isPioneer;
  final double padding;
  final BoxShape shape;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!isPioneer) return child;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? borderRadius : null,
        border: Border.all(
          color: PioneerMemberBadge.gold,
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x553A78B5),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}
