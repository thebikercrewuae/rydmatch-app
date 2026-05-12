import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class SosButtonWidget extends StatelessWidget {
  final bool isCountingDown;
  final int countdownValue;
  final VoidCallback onPressed;
  final VoidCallback onCancel;

  const SosButtonWidget({
    super.key,
    required this.isCountingDown,
    required this.countdownValue,
    required this.onPressed,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCountingDown) ..._buildCountdown() else _buildSosButton(),
        if (isCountingDown) ..._buildCancelSection(),
      ],
    );
  }

  List<Widget> _buildCountdown() {
    return [
      Text(
        'Sending SOS in...',
        style: GoogleFonts.dmSans(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
      SizedBox(height: 2.h),
      Container(
        width: 35.w,
        height: 35.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE53935),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53935).withValues(alpha: 0.6),
              blurRadius: 30,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$countdownValue',
            style: GoogleFonts.dmSans(
              fontSize: 28.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildSosButton() {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 35.w,
        height: 35.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFFFF5252), Color(0xFFB71C1C)],
            center: Alignment(-0.3, -0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53935).withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 3,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sos_rounded, color: Colors.white, size: 36),
            SizedBox(height: 0.5.h),
            Text(
              'SOS',
              style: GoogleFonts.dmSans(
                fontSize: 16.sp,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCancelSection() {
    return [
      SizedBox(height: 3.h),
      GestureDetector(
        onTap: onCancel,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.5.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30.0),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Text(
            'CANCEL',
            style: GoogleFonts.dmSans(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    ];
  }
}
