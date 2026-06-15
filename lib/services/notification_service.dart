import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'diagnostics_service.dart';

enum NotificationType {
  newMatch,
  newMessage,
  rideGroupInvite,
  rideStarted,
  emergencySos,
  urgentAlert;

  static NotificationType fromString(String value) {
    switch (value) {
      case 'new_match':
        return NotificationType.newMatch;
      case 'new_message':
        return NotificationType.newMessage;
      case 'ride_group_invite':
        return NotificationType.rideGroupInvite;
      case 'ride_started':
        return NotificationType.rideStarted;
      case 'emergency_sos':
        return NotificationType.emergencySos;
      case 'urgent_alert':
        return NotificationType.urgentAlert;
      default:
        return NotificationType.urgentAlert;
    }
  }

  String toDbString() {
    switch (this) {
      case NotificationType.newMatch:
        return 'new_match';
      case NotificationType.newMessage:
        return 'new_message';
      case NotificationType.rideGroupInvite:
        return 'ride_group_invite';
      case NotificationType.rideStarted:
        return 'ride_started';
      case NotificationType.emergencySos:
        return 'emergency_sos';
      case NotificationType.urgentAlert:
        return 'urgent_alert';
    }
  }
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final bool isRead;

  /// The raw action route/url from the DB (e.g. "/chat-screen?otherUserId=abc&otherUserName=John")
  final String? actionUrl;

  /// Parsed Flutter route derived from actionUrl (e.g. "/chat-screen")
  final String? actionRoute;

  /// Parsed query parameters from actionUrl as route arguments
  final Map<String, dynamic>? actionArguments;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.actionUrl,
    this.actionRoute,
    this.actionArguments,
    required this.createdAt,
  });

  /// Parse action route/url (e.g. "/chat-screen?otherUserId=abc&otherUserName=John")
  /// into a route string and arguments map.
  static ({String? route, Map<String, dynamic>? args}) _parseActionUrl(
    String? url,
  ) {
    if (url == null || url.isEmpty) return (route: null, args: null);
    try {
      // Handle both absolute URLs and relative paths
      final uri = Uri.tryParse(url);
      if (uri == null) return (route: null, args: null);

      // Extract the path as the Flutter route
      final route = uri.path.isNotEmpty ? uri.path : url;

      // Convert query parameters to a Map<String, dynamic>
      final args = uri.queryParameters.isNotEmpty
          ? Map<String, dynamic>.from(uri.queryParameters)
          : null;

      return (route: route, args: args);
    } catch (_) {
      return (route: url, args: null);
    }
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawAction =
        json['action_route'] as String? ?? json['action_url'] as String?;
    final parsed = _parseActionUrl(rawAction);
    final type = NotificationType.fromString(
      json['notification_type'] as String,
    );

    // For new_message notifications, build chat route from reference_id
    String? actionRoute = parsed.route;
    Map<String, dynamic>? actionArguments = parsed.args;
    final rawArgs = json['action_arguments'];
    if (rawArgs is Map<String, dynamic>) {
      actionArguments = {...?actionArguments, ...rawArgs};
    } else if (rawArgs is Map) {
      actionArguments = {
        ...?actionArguments,
        ...Map<String, dynamic>.from(rawArgs),
      };
    }

    if (type == NotificationType.newMessage) {
      final referenceId = json['reference_id'] as String?;
      if (referenceId != null && referenceId.isNotEmpty) {
        actionRoute = '/chat-screen';
        actionArguments = {'otherUserId': referenceId, 'otherUserName': ''};
      }
    }

    // Handle live ride started notifications
    if (type == NotificationType.rideStarted) {
      if (actionArguments != null) {
        actionRoute = '/live-ride';
        actionArguments = {
          'session_id': actionArguments['session_id'] as String? ?? '',
          'ride_group_id': actionArguments['ride_group_id'] as String? ?? '',
        };
      }
    }

    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: type,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      actionUrl: rawAction,
      actionRoute: actionRoute,
      actionArguments: actionArguments,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl,
      actionRoute: actionRoute,
      actionArguments: actionArguments,
      createdAt: createdAt,
    );
  }
}

class NotificationService extends ChangeNotifier {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();

  NotificationService._();

  final SupabaseClient _client = Supabase.instance.client;

  final List<AppNotification> _notifications = [];
  final StreamController<AppNotification> _bannerController =
      StreamController<AppNotification>.broadcast();

  RealtimeChannel? _channel;
  bool _isInitialized = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Stream<AppNotification> get bannerStream => _bannerController.stream;

  Future<void> initialize() async {
    final user = _client.auth.currentUser;
    if (user == null || _isInitialized) return;

    _isInitialized = true;
    await _loadNotifications();
    _subscribeToRealtime(user.id);
  }

  Future<void> _loadNotifications() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      _notifications.clear();
      for (final row in response as List) {
        _notifications.add(
          AppNotification.fromJson(row as Map<String, dynamic>),
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationService: failed to load notifications: $e');
      await DiagnosticsService.instance.logError(
        feature: 'notifications',
        action: 'load_notifications',
        error: e,
        severity: 'warning',
        context: {'limit': 50},
      );
    }
  }

  void _subscribeToRealtime(String userId) {
    _channel?.unsubscribe();
    _channel = _client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            try {
              final notification = AppNotification.fromJson(payload.newRecord);
              _notifications.insert(0, notification);
              notifyListeners();

              // Show banners for messages, live rides, and emergency alerts.
              if (!notification.isRead &&
                  (notification.type == NotificationType.newMessage ||
                      notification.type == NotificationType.rideStarted ||
                      notification.type == NotificationType.emergencySos)) {
                _bannerController.add(notification);
              }
            } catch (e) {
              debugPrint('NotificationService: realtime parse error: $e');
              unawaited(
                DiagnosticsService.instance.logError(
                  feature: 'notifications',
                  action: 'realtime_parse',
                  error: e,
                  severity: 'warning',
                  context: {
                    'record_keys': payload.newRecord.keys.toList(),
                    'notification_type': payload.newRecord['notification_type'],
                  },
                ),
              );
            }
          },
        )
        .subscribe();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NotificationService: markAsRead error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'notifications',
        action: 'mark_as_read',
        error: e,
        severity: 'warning',
        context: {'notification_id': notificationId},
      );
    }
  }

  /// Mark all unread new_message notifications for the current user as read.
  /// Called when the user opens a chat screen.
  Future<void> markNewMessageNotificationsAsRead() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('notification_type', 'new_message')
          .eq('is_read', false);

      for (int i = 0; i < _notifications.length; i++) {
        if (_notifications[i].type == NotificationType.newMessage &&
            !_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint(
        'NotificationService: markNewMessageNotificationsAsRead error: $e',
      );
      await DiagnosticsService.instance.logError(
        feature: 'notifications',
        action: 'mark_new_message_notifications_as_read',
        error: e,
        severity: 'warning',
      );
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);

      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationService: markAllAsRead error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'notifications',
        action: 'mark_all_as_read',
        error: e,
        severity: 'warning',
      );
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client.from('notifications').delete().eq('user_id', user.id);

      _notifications.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationService: clearAllNotifications error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'notifications',
        action: 'clear_all_notifications',
        error: e,
        severity: 'warning',
      );
    }
  }

  void reset() {
    _channel?.unsubscribe();
    _channel = null;
    _isInitialized = false;
    _notifications.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _bannerController.close();
    super.dispose();
  }
}
