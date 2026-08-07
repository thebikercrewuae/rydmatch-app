import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Smart in-app review prompt.
///
/// Instead of nagging on a fixed schedule, this fires at a positive moment
/// (returning user opening the app) and is gated so it never annoys:
///   - skipped for the first 7 days of a user's account,
///   - at most once every 90 days per user (Apple's own guidance),
///   - at most once per app session.
///
/// A short "Enjoying RydMatch?" dialog pre-filters sentiment: happy users
/// are routed to the native store review dialog, while anyone with a
/// complaint is routed to a feedback email so issues reach the founder
/// instead of becoming public 1-star reviews.
class RatingService {
  RatingService._();
  static final RatingService instance = RatingService._();

  static const String _lastPromptKey = 'app_review_last_prompt_at_ms';
  static const Duration _minAccountAge = Duration(days: 7);
  static const Duration _minBetweenPrompts = Duration(days: 90);

  /// Support address for the "could be better" path. Update to the real
  /// support inbox before shipping (e.g. hello@rydmatch.com).
  static const String supportEmail = 'imransait.is@gmail.com';

  bool _promptedThisSession = false;

  /// Call this at a positive moment (e.g. when a returning user lands on
  /// the main screen). The gates ensure we never nag.
  Future<void> maybePromptForReview(BuildContext context) async {
    if (_promptedThisSession) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Account-age gate: don't ask brand-new users.
    final createdStr = user.createdAt;
    if (createdStr.isNotEmpty) {
      final created = DateTime.tryParse(createdStr);
      if (created != null &&
          DateTime.now().difference(created) < _minAccountAge) {
        return;
      }
    }

    // 90-day cap between prompts.
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_lastPromptKey);
    if (lastMs != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (DateTime.now().difference(last) < _minBetweenPrompts) {
        return;
      }
    }

    _promptedThisSession = true;
    await prefs.setInt(_lastPromptKey, DateTime.now().millisecondsSinceEpoch);

    if (!context.mounted) return;
    await _showEnjoymentDialog(context);
  }

  Future<void> _showEnjoymentDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final choice = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Enjoying RydMatch?',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Your feedback helps us make RydMatch better for riders like you.',
          style: GoogleFonts.dmSans(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Could be better', style: GoogleFonts.dmSans()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes!', style: GoogleFonts.dmSans()),
          ),
        ],
      ),
    );

    if (choice == true) {
      await _requestNativeReview();
    } else if (choice == false) {
      await _openFeedbackEmail();
    }
    // choice == null (dismissed) -> no action; the 90-day cap still
    // applies so we don't nag again soon.
  }

  Future<void> _requestNativeReview() async {
    try {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      }
    } catch (e) {
      debugPrint('RatingService: native review unavailable: $e');
    }
  }

  Future<void> _openFeedbackEmail() async {
    try {
      final subject = Uri.encodeComponent('RydMatch feedback');
      final body = Uri.encodeComponent(
        "Hey - thanks for asking. Here's what could be better:\n\n",
      );
      final url = 'mailto:$supportEmail?subject=$subject&body=$body';
      await launchUrl(Uri.parse(url));
    } catch (e) {
      debugPrint('RatingService: feedback email launch failed: $e');
    }
  }
}