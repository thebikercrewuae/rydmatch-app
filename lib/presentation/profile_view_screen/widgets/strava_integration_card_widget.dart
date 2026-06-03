import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../services/strava_service.dart';

class StravaIntegrationCardWidget extends StatefulWidget {
  final bool isPremium;

  const StravaIntegrationCardWidget({super.key, required this.isPremium});

  @override
  State<StravaIntegrationCardWidget> createState() =>
      _StravaIntegrationCardWidgetState();
}

class _StravaIntegrationCardWidgetState
    extends State<StravaIntegrationCardWidget> {
  final StravaService _stravaService = StravaService.instance;

  @override
  void initState() {
    super.initState();
    _stravaService.addListener(_onStravaChanged);
    _stravaService.refreshStatus();
  }

  @override
  void dispose() {
    _stravaService.removeListener(_onStravaChanged);
    super.dispose();
  }

  void _onStravaChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const stravaOrange = Color(0xFFFC4C02);
    final isConnected = _stravaService.isConnected;
    final isLoading = _stravaService.isLoading;
    final athleteName = _stravaService.athleteName;

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: stravaOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: stravaOrange.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: stravaOrange,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isConnected ? Icons.check_rounded : Icons.directions_bike,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Strava Cycling',
                      style: GoogleFonts.dmSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 0.4.h),
                    Text(
                      _subtitleText(isConnected, athleteName),
                      style: GoogleFonts.dmSans(
                        fontSize: 11.sp,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.isPremium)
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFFB347),
                  size: 24,
                ),
            ],
          ),
          if (_stravaService.lastError != null) ...[
            SizedBox(height: 1.2.h),
            Text(
              _stravaService.lastError!,
              style: GoogleFonts.dmSans(
                fontSize: 10.sp,
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          SizedBox(height: 2.h),
          if (isConnected)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : _refreshStrava,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text(
                      'Refresh',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : _disconnectStrava,
                    icon: const Icon(Icons.link_off_rounded, size: 18),
                    label: Text(
                      'Disconnect',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : widget.isPremium
                    ? _connectStrava
                    : () => Navigator.pushNamed(
                        context,
                        '/premium-subscription-screen',
                      ),
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        widget.isPremium
                            ? Icons.link_rounded
                            : Icons.lock_rounded,
                        size: 18,
                      ),
                label: Text(
                  widget.isPremium ? 'Connect Strava' : 'Unlock with Premium',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isPremium
                      ? stravaOrange
                      : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 1.5.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _subtitleText(bool isConnected, String? athleteName) {
    if (!widget.isPremium) return 'Premium cyclists can connect Strava.';
    if (isConnected && athleteName != null && athleteName.isNotEmpty) {
      return 'Connected as $athleteName.';
    }
    if (isConnected) return 'Strava is connected.';
    return 'Connect your rides and cycling stats.';
  }

  Future<void> _connectStrava() async {
    final opened = await _stravaService.connect();
    if (!opened && mounted) {
      _showSnackBar(_stravaService.lastError ?? 'Could not open Strava.');
    }
  }

  Future<void> _refreshStrava() async {
    final ok = await _stravaService.refreshAthlete();
    if (!mounted) return;
    _showSnackBar(ok ? 'Strava refreshed.' : 'Could not refresh Strava.');
  }

  Future<void> _disconnectStrava() async {
    final ok = await _stravaService.disconnect();
    if (!mounted) return;
    _showSnackBar(ok ? 'Strava disconnected.' : 'Could not disconnect Strava.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
