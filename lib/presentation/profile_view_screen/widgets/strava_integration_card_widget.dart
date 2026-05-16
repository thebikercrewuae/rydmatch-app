import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

class StravaIntegrationCardWidget extends StatelessWidget {
  final bool isPremium;

  static const String _clientId = String.fromEnvironment('STRAVA_CLIENT_ID');
  static const String _redirectUri =
      String.fromEnvironment('STRAVA_REDIRECT_URI');

  const StravaIntegrationCardWidget({super.key, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const stravaOrange = Color(0xFFFC4C02);

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
                child: const Icon(
                  Icons.directions_bike_rounded,
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
                      isPremium
                          ? 'Connect your rides and cycling stats.'
                          : 'Premium cyclists can connect Strava.',
                      style: GoogleFonts.dmSans(
                        fontSize: 11.sp,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isPremium)
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFFB347),
                  size: 24,
                ),
            ],
          ),
          SizedBox(height: 2.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isPremium
                  ? () => _connectStrava(context)
                  : () => Navigator.pushNamed(
                        context,
                        '/premium-subscription-screen',
                      ),
              icon: Icon(
                isPremium ? Icons.link_rounded : Icons.lock_rounded,
                size: 18,
              ),
              label: Text(
                isPremium ? 'Connect Strava' : 'Unlock with Premium',
                style: GoogleFonts.dmSans(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isPremium ? stravaOrange : theme.colorScheme.primary,
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

  Future<void> _connectStrava(BuildContext context) async {
    if (_clientId.isEmpty || _redirectUri.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Strava setup needs STRAVA_CLIENT_ID and redirect URI.'),
        ),
      );
      return;
    }

    final authUri = Uri.https('www.strava.com', '/oauth/mobile/authorize', {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'approval_prompt': 'auto',
      'scope': 'read,activity:read',
    });

    final opened = await launchUrl(
      authUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Strava.')),
      );
    }
  }
}
