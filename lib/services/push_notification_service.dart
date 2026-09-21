import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize local notifications for Android
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permission (iOS shows prompt, Android 13+ shows prompt)
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get FCM token and save to database
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_saveTokenToDatabase);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background/terminated message tap
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessageTap(initialMessage);
      }

      // Handle background message tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);

      _initialized = true;
      debugPrint('PushNotificationService: initialized successfully');
    } catch (e) {
      debugPrint('PushNotificationService: init error: $e');
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client.from('user_profiles').update({
        'fcm_token': token,
      }).eq('id', userId);
      debugPrint('PushNotificationService: FCM token saved');
    } catch (e) {
      debugPrint('PushNotificationService: save token error: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // Show local notification when app is in foreground
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'rydmatch_notifications',
          'RydMatch Notifications',
          channelDescription: 'Match, message, and ride invitations',
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['route'] as String?,
    );
  }

  void _handleBackgroundMessageTap(RemoteMessage message) {
    // Navigate to relevant screen based on data payload
    final route = message.data['route'] as String?;
    if (route != null) {
      debugPrint('PushNotificationService: tapped notification, route=$route');
      // Navigation will be handled by the app's navigation system
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      debugPrint('PushNotificationService: local notification tapped, payload=$payload');
    }
  }

  Future<void> deleteToken() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client.from('user_profiles').update({
        'fcm_token': null,
      }).eq('id', userId);
      await _messaging.deleteToken();
      debugPrint('PushNotificationService: token deleted');
    } catch (e) {
      debugPrint('PushNotificationService: delete token error: $e');
    }
  }
}

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('PushNotificationService: background message: ${message.messageId}');
}
