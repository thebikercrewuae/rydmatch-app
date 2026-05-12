import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a queued message action to be sent when online.
class QueuedMessage {
  final String localId;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String messageBody;
  final bool isImage;
  final DateTime createdAt;

  QueuedMessage({
    required this.localId,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.messageBody,
    required this.isImage,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'conversationId': conversationId,
    'senderId': senderId,
    'receiverId': receiverId,
    'messageBody': messageBody,
    'isImage': isImage,
    'createdAt': createdAt.toIso8601String(),
  };

  factory QueuedMessage.fromJson(Map<String, dynamic> json) => QueuedMessage(
    localId: json['localId'] as String,
    conversationId: json['conversationId'] as String,
    senderId: json['senderId'] as String,
    receiverId: json['receiverId'] as String,
    messageBody: json['messageBody'] as String,
    isImage: json['isImage'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// Represents a queued rating action to be submitted when online.
class QueuedRating {
  final String localId;
  final String reviewerId;
  final String reviewedId;
  final int stars;
  final Map<String, int> categoryRatings;
  final List<String> safetyTags;
  final String? comment;
  final DateTime createdAt;

  QueuedRating({
    required this.localId,
    required this.reviewerId,
    required this.reviewedId,
    required this.stars,
    required this.categoryRatings,
    required this.safetyTags,
    this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'reviewerId': reviewerId,
    'reviewedId': reviewedId,
    'stars': stars,
    'categoryRatings': categoryRatings,
    'safetyTags': safetyTags,
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
  };

  factory QueuedRating.fromJson(Map<String, dynamic> json) => QueuedRating(
    localId: json['localId'] as String,
    reviewerId: json['reviewerId'] as String,
    reviewedId: json['reviewedId'] as String,
    stars: json['stars'] as int,
    categoryRatings: (json['categoryRatings'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, v as int)),
    safetyTags: List<String>.from(json['safetyTags'] as List? ?? []),
    comment: json['comment'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// Manages offline queuing of messages and ratings using SharedPreferences.
/// Automatically syncs queued actions to Supabase when connectivity is restored.
class OfflineQueueService {
  static OfflineQueueService? _instance;
  static OfflineQueueService get instance =>
      _instance ??= OfflineQueueService._();

  OfflineQueueService._();

  static const String _messagesKey = 'offline_queue_messages';
  static const String _ratingsKey = 'offline_queue_ratings';

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  // Notifier so UI can react to sync events
  final ValueNotifier<int> pendingMessageCount = ValueNotifier(0);
  final ValueNotifier<int> pendingRatingCount = ValueNotifier(0);

  /// Start listening for connectivity changes and sync on restore.
  void startMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        await syncAll();
      }
    });
    _refreshCounts();
  }

  void stopMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  // ─── Message Queue ────────────────────────────────────────────────────────

  Future<List<QueuedMessage>> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_messagesKey) ?? [];
    return raw
        .map((s) {
          try {
            return QueuedMessage.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<QueuedMessage>()
        .toList();
  }

  Future<void> _saveMessages(List<QueuedMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _messagesKey,
      messages.map((m) => jsonEncode(m.toJson())).toList(),
    );
    pendingMessageCount.value = messages.length;
  }

  /// Enqueue a message for later delivery.
  Future<void> enqueueMessage(QueuedMessage message) async {
    final messages = await _loadMessages();
    messages.add(message);
    await _saveMessages(messages);
    debugPrint('[OfflineQueue] Queued message: ${message.localId}');
  }

  // ─── Rating Queue ─────────────────────────────────────────────────────────

  Future<List<QueuedRating>> _loadRatings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_ratingsKey) ?? [];
    return raw
        .map((s) {
          try {
            return QueuedRating.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<QueuedRating>()
        .toList();
  }

  Future<void> _saveRatings(List<QueuedRating> ratings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _ratingsKey,
      ratings.map((r) => jsonEncode(r.toJson())).toList(),
    );
    pendingRatingCount.value = ratings.length;
  }

  /// Enqueue a rating for later submission.
  Future<void> enqueueRating(QueuedRating rating) async {
    final ratings = await _loadRatings();
    ratings.add(rating);
    await _saveRatings(ratings);
    debugPrint('[OfflineQueue] Queued rating: ${rating.localId}');
  }

  // ─── Sync ─────────────────────────────────────────────────────────────────

  /// Sync all queued messages and ratings to Supabase.
  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _syncMessages();
      await _syncRatings();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncMessages() async {
    final messages = await _loadMessages();
    if (messages.isEmpty) return;

    final client = Supabase.instance.client;
    final List<QueuedMessage> failed = [];

    for (final msg in messages) {
      try {
        await client.from('chat_messages').insert({
          'conversation_id': msg.conversationId,
          'sender_id': msg.senderId,
          'recipient_id': msg.receiverId,
          'message_body': msg.messageBody,
          'is_image': msg.isImage,
          'delivery_status': 'sent',
          'created_at': msg.createdAt.toIso8601String(),
        });
        debugPrint('[OfflineQueue] Synced message: ${msg.localId}');
      } catch (e) {
        debugPrint('[OfflineQueue] Failed to sync message ${msg.localId}: $e');
        failed.add(msg);
      }
    }

    await _saveMessages(failed);
  }

  Future<void> _syncRatings() async {
    final ratings = await _loadRatings();
    if (ratings.isEmpty) return;

    final client = Supabase.instance.client;
    final List<QueuedRating> failed = [];

    for (final rating in ratings) {
      try {
        await client.from('ride_ratings').insert({
          'reviewer_id': rating.reviewerId,
          'reviewed_id': rating.reviewedId,
          'stars': rating.stars,
          'category_ratings': rating.categoryRatings,
          'safety_tags': rating.safetyTags,
          'comment': rating.comment,
          'created_at': rating.createdAt.toIso8601String(),
        });
        debugPrint('[OfflineQueue] Synced rating: ${rating.localId}');
      } catch (e) {
        debugPrint(
          '[OfflineQueue] Failed to sync rating ${rating.localId}: $e',
        );
        failed.add(rating);
      }
    }

    await _saveRatings(failed);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _refreshCounts() async {
    final messages = await _loadMessages();
    final ratings = await _loadRatings();
    pendingMessageCount.value = messages.length;
    pendingRatingCount.value = ratings.length;
  }

  /// Check current connectivity status.
  static Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }
}
