import 'package:supabase_flutter/supabase_flutter.dart';

/// Logs key user events to the analytics_events table in Supabase.
class AnalyticsService {
  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService._();
  AnalyticsService._();

  static const String eventProfileCreated = 'profile_created';
  static const String eventProfileUpdated = 'profile_updated';
  static const String eventSwipeRight = 'swipe_right';
  static const String eventSwipeLeft = 'swipe_left';
  static const String eventSuperLike = 'super_like';
  static const String eventMatchCreated = 'match_created';
  static const String eventMessageSent = 'message_sent';
  static const String eventSosTriggered = 'sos_triggered';
  static const String eventPremiumScreenView = 'premium_screen_view';
  static const String eventPremiumSubscribeStarted =
      'premium_subscribe_started';
  static const String eventPremiumConverted = 'premium_converted';

  Future<void> logEvent(String eventType, {Map<String, dynamic>? data}) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('analytics_events').insert({
        'user_id': user.id,
        'event_type': eventType,
        'event_data': data ?? {},
      });
    } catch (_) {
      // Analytics failures must never affect app functionality
    }
  }

  Future<void> logProfileCreated() async {
    await logEvent(eventProfileCreated);
  }

  Future<void> logProfileUpdated() async {
    await logEvent(eventProfileUpdated);
  }

  Future<void> logSwipe({
    required String direction,
    required String swipedUserId,
    String? swipedUserName,
  }) async {
    final eventType = direction == 'right'
        ? eventSwipeRight
        : direction == 'top'
        ? eventSuperLike
        : eventSwipeLeft;
    await logEvent(
      eventType,
      data: {
        'swiped_user_id': swipedUserId,
        if (swipedUserName != null) 'swiped_user_name': swipedUserName,
      },
    );
  }

  Future<void> logMatchCreated({required String matchedUserId}) async {
    await logEvent(eventMatchCreated, data: {'matched_user_id': matchedUserId});
  }

  Future<void> logMessageSent({String? conversationId}) async {
    await logEvent(
      eventMessageSent,
      data: {if (conversationId != null) 'conversation_id': conversationId},
    );
  }

  Future<void> logSosTriggered({double? latitude, double? longitude}) async {
    await logEvent(
      eventSosTriggered,
      data: {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'triggered_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logPremiumConverted({String? plan}) async {
    await logEvent(
      eventPremiumConverted,
      data: {
        if (plan != null) 'plan': plan,
        'converted_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> logPremiumScreenView() async {
    await logEvent(eventPremiumScreenView);
  }

  Future<void> logPremiumSubscribeStarted({
    required bool betaUnlockEnabled,
    String? price,
    String? currencyCode,
  }) async {
    await logEvent(
      eventPremiumSubscribeStarted,
      data: {
        'beta_unlock_enabled': betaUnlockEnabled,
        if (price != null) 'price': price,
        if (currencyCode != null) 'currency_code': currencyCode,
      },
    );
  }
}
