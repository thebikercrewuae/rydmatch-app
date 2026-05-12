import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../../services/referral_service.dart';

class ReferralStatsCardWidget extends StatefulWidget {
  const ReferralStatsCardWidget({super.key});

  @override
  State<ReferralStatsCardWidget> createState() =>
      _ReferralStatsCardWidgetState();
}

class _ReferralStatsCardWidgetState extends State<ReferralStatsCardWidget> {
  bool _isLoading = true;
  ReferralStats? _stats;
  int _activeTrials = 0;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await ReferralService().fetchReferralStats();
      int activeTrials = 0;
      if (stats != null) {
        final referred = await ReferralService().fetchReferredUsers();
        activeTrials = referred.where((r) => r['status'] == 'active').length;
      }
      if (mounted) {
        setState(() {
          _stats = stats;
          _activeTrials = activeTrials;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 2.h),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFFB347),
            strokeWidth: 2,
          ),
        ),
      );
    }

    final totalReferrals = _stats?.totalReferrals ?? 0;
    final earnedDays = _stats?.trialDaysEarned ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B365D), Color(0xFF243B6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: const Color(0xFFFFB347).withAlpha(102),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(38),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 1.h),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB347).withAlpha(38),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: const Icon(
                    Icons.people_alt_rounded,
                    color: Color(0xFFFFB347),
                    size: 18,
                  ),
                ),
                SizedBox(width: 2.w),
                Text(
                  'Referral Stats',
                  style: GoogleFonts.dmSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withAlpha(26), height: 1, thickness: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
            child: Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.group_add_rounded,
                    iconColor: const Color(0xFF4FC3F7),
                    value: '$totalReferrals',
                    label: 'Total\nReferrals',
                  ),
                ),
                _VerticalDivider(),
                Expanded(
                  child: _StatItem(
                    icon: Icons.rocket_launch_rounded,
                    iconColor: const Color(0xFF81C784),
                    value: '$_activeTrials',
                    label: 'Active\nTrials',
                  ),
                ),
                _VerticalDivider(),
                Expanded(
                  child: _StatItem(
                    icon: Icons.workspace_premium_rounded,
                    iconColor: const Color(0xFFFFB347),
                    value: '${earnedDays}d',
                    label: 'Premium\nDays Earned',
                  ),
                ),
              ],
            ),
          ),
          if (totalReferrals == 0)
            Padding(
              padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.5.h),
              child: Text(
                'Share your referral code to earn free Premium days!',
                style: GoogleFonts.dmSans(
                  fontSize: 11.sp,
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 20),
        SizedBox(height: 0.5.h),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 0.3.h),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10.sp,
            color: Colors.white60,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 50,
      color: Colors.white.withAlpha(31),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
    );
  }
}
