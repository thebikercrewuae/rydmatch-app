import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../services/analytics_service.dart';
import '../../services/haptic_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/skeleton_loader_widget.dart';
import '../../widgets/toast_widget.dart';
import './widgets/chat_bubble_widget.dart';
import './widgets/chat_empty_state_widget.dart';
import './widgets/chat_header_widget.dart';
import './widgets/chat_input_widget.dart';
import './widgets/message_options_sheet_widget.dart';
import './widgets/suggest_ride_modal_widget.dart';
import './widgets/typing_indicator_widget.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final bool _isTyping = false;
  bool _showSuggestRide = false;
  bool _isRefreshing = false;
  bool _isLoading = true;
  RealtimeChannel? _statusSubscription;
  RealtimeChannel? _newMessageSubscription;

  // Fallback rider data — overridden by route arguments
  final Map<String, dynamic> _rider = {
    'name': 'Rider',
    'image': 'https://images.unsplash.com/photo-1732154478254-f94aebec9501',
    'bikeModel': '',
    'isOnline': true,
  };

  final List<Map<String, dynamic>> _messages = [];

  /// Resolve the display name from route args — reads 'otherUserName' first
  /// (passed by matches screen), then falls back to 'full_name' / 'name'.
  String _resolveRiderName(Map<String, dynamic> riderData) {
    final otherUserName = riderData['otherUserName'] as String?;
    if (otherUserName != null && otherUserName.isNotEmpty) return otherUserName;
    final fullName = riderData['full_name'] as String?;
    if (fullName != null && fullName.isNotEmpty) return fullName;
    final name = riderData['name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    return 'Rider';
  }

  String _getConversationId() {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return '';
    final args = ModalRoute.of(context)?.settings.arguments;
    final riderData = args is Map<String, dynamic> ? args : _rider;
    final otherUserId = riderData['otherUserId'] as String?;
    if (otherUserId == null) return '';
    final ids = [currentUser.id, otherUserId]..sort();
    return ids.join('_');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      _scrollToBottom();
      _handlePrefillMessage();
      _subscribeToNewMessages();
      _subscribeToStatusUpdates();
      _markMessagesAsRead();
    });
  }

  /// If a prefillMessage was passed via route arguments, populate the input
  /// field and send it automatically so the route details land in the chat.
  void _handlePrefillMessage() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final prefill = args['prefillMessage'] as String?;
      if (prefill != null && prefill.isNotEmpty) {
        _messageController.text = prefill;
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _sendMessage();
        });
      }
    }
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final args = ModalRoute.of(context)?.settings.arguments;
      final riderData = args is Map<String, dynamic> ? args : _rider;
      final otherUserId = riderData['otherUserId'] as String?;

      // Fetch other user's name if missing (e.g. from notification View button)
      final otherUserName = riderData['otherUserName'] as String? ?? '';
      if (otherUserId != null && otherUserName.isEmpty) {
        try {
          final profile = await supabase
              .from('user_profiles')
              .select('full_name')
              .eq('id', otherUserId)
              .maybeSingle();
          if (profile != null && mounted) {
            setState(() {
              _rider['name'] = profile['full_name'] as String? ?? 'Rider';
            });
          }
        } catch (_) {
          // Non-blocking profile fetch error
        }
      }

      if (otherUserId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final ids = [currentUser.id, otherUserId]..sort();
      final conversationId = ids.join('_');

      if (mounted) setState(() => _isLoading = true);

      try {
        final simpleResult = await supabase
            .from('chat_messages')
            .select('id, sender_id, recipient_id, message_body, created_at')
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: true)
            .limit(200);

        final simpleData = List<Map<String, dynamic>>.from(simpleResult);

        // Map messages
        final messages = simpleData.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          final isSender = row['sender_id'] == currentUser.id;
          final createdAt = row['created_at'] != null
              ? DateTime.tryParse(row['created_at'] as String)
              : null;
          final time = createdAt != null ? _formatTime(createdAt) : '';
          return <String, dynamic>{
            'id': i + 1,
            'dbId': row['id'],
            'message': row['message_body'] as String? ?? '',
            'isSender': isSender,
            'timestamp': time,
            'status': 'sent',
            'isImage': false,
            'isRead': false,
          };
        }).toList();

        if (mounted) {
          setState(() {
            _messages
              ..clear()
              ..addAll(messages);
            _isLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
        ? 12
        : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Mark all unread messages sent by the other user as read.
  /// Also marks any related new_message notifications as read.
  Future<void> _markMessagesAsRead() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final args = ModalRoute.of(context)?.settings.arguments;
      final riderData = args is Map<String, dynamic> ? args : _rider;
      final otherUserId = riderData['otherUserId'] as String?;
      if (otherUserId == null) return;

      final ids = [currentUser.id, otherUserId]..sort();
      final conversationId = ids.join('_');

      // Update unread messages where current user is the recipient
      await supabase
          .from('chat_messages')
          .update({
            'delivery_status': 'read',
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .eq('recipient_id', currentUser.id)
          .filter('read_at', 'is', 'null');

      // Mark any unread new_message notifications for this user as read
      try {
        await NotificationService.instance.markNewMessageNotificationsAsRead();
      } catch (_) {
        // Non-blocking notification update error
      }
    } catch (_) {
      // Non-blocking mark-as-read error
    }
  }

  /// Subscribe to real-time INSERT events on chat_messages filtered by
  /// conversation_id. On any new insert, append the message from the payload.
  void _subscribeToNewMessages() {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final args = ModalRoute.of(context)?.settings.arguments;
      final riderData = args is Map<String, dynamic> ? args : _rider;
      final otherUserId = riderData['otherUserId'] as String?;
      if (otherUserId == null) return;

      final ids = [currentUser.id, otherUserId]..sort();
      final conversationId = ids.join('_');

      _newMessageSubscription = supabase
          .channel('chat_new_messages_$conversationId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (payload) {
              if (!mounted) return;
              final row = payload.newRecord;

              // For messages from the other user, append directly from the payload
              // For own messages, they are already added optimistically — skip duplicate
              if (row['sender_id'] == currentUser.id) return;

              final createdAt = row['created_at'] != null
                  ? DateTime.tryParse(row['created_at'] as String)
                  : null;
              final time = createdAt != null ? _formatTime(createdAt) : '';

              final newMsg = <String, dynamic>{
                'id': _messages.length + 1,
                'dbId': row['id'],
                'message': row['message_body'] as String? ?? '',
                'isSender': false,
                'timestamp': time,
                'status': row['delivery_status'] as String? ?? 'sent',
                'isImage': row['is_image'] as bool? ?? false,
                'isRead': false,
              };

              setState(() {
                _messages.add(newMsg);
              });

              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollToBottom(),
              );
              // Mark this new incoming message as read immediately
              _markMessagesAsRead();
            },
          )
          .subscribe();
    } catch (_) {
      // Non-blocking subscription error
    }
  }

  /// Subscribe to real-time status updates from Supabase.
  void _subscribeToStatusUpdates() {
    try {
      final supabase = Supabase.instance.client;
      final conversationId = _getConversationId();
      if (conversationId.isEmpty) return;

      _statusSubscription = supabase
          .channel('chat_message_status_$conversationId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (payload) {
              if (!mounted) return;
              final updated = payload.newRecord;
              final sid = updated['twilio_message_sid'] as String?;
              final newStatus = updated['delivery_status'] as String?;
              if (sid == null || newStatus == null) return;

              setState(() {
                for (final msg in _messages) {
                  if (msg['twilio_sid'] == sid) {
                    msg['status'] = newStatus;
                    break;
                  }
                }
              });

              // Show error toast only on delivery failure
              if (newStatus == 'failed') {
                AppToast.show(
                  context,
                  message: 'Message failed to send. Please try again.',
                  type: ToastType.error,
                );
              }
            },
          )
          .subscribe();
    } catch (_) {
      // Supabase not configured — status updates will not be real-time
    }
  }

  @override
  void dispose() {
    _newMessageSubscription?.unsubscribe();
    _statusSubscription?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    HapticService.instance.light();

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    final args = ModalRoute.of(context)?.settings.arguments;
    final riderData = args is Map<String, dynamic> ? args : _rider;
    final otherUserId = riderData['otherUserId'] as String?;

    // Optimistic UI update
    final newMsg = {
      'id': _messages.length + 1,
      'message': text,
      'isSender': true,
      'timestamp': _getCurrentTime(),
      'status': 'sent',
      'isImage': false,
    };
    setState(() {
      _messages.add(newMsg);
      _messageController.clear();
      _showSuggestRide = false;
    });

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    // Persist to Supabase via INSERT into chat_messages
    if (currentUser != null && otherUserId != null) {
      final ids = [currentUser.id, otherUserId]..sort();
      final conversationId = ids.join('_');

      () async {
        try {
          await supabase.from('chat_messages').insert({
            'conversation_id': conversationId,
            'sender_id': currentUser.id,
            'recipient_id': otherUserId,
            'message_body': text,
            'delivery_status': 'sent',
          });
          // Log message send analytics
          await AnalyticsService.instance.logMessageSent(
            conversationId: conversationId,
          );
        } catch (e) {
          if (mounted) {
            setState(() {
              final idx = _messages.indexWhere((m) => m['id'] == newMsg['id']);
              if (idx != -1) _messages[idx]['status'] = 'failed';
            });
            final errorMessage = e is PostgrestException
                ? 'Failed to send: ${e.message}${e.details != null ? '\nDetails: ${e.details}' : ''}${e.hint != null ? '\nHint: ${e.hint}' : ''}'
                : 'Failed to send: $e';
            AppToast.show(
              context,
              message: errorMessage,
              type: ToastType.error,
            );
          }
        }
      }();
    }
  }

  void _sendRideSuggestion(Map<String, String> data) {
    final msg =
        '🏍️ Ride Suggestion\n📍 Route: ${data['route']}\n📌 Meet: ${data['meet']}\n📅 ${data['date']} at ${data['time']}';

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    final args = ModalRoute.of(context)?.settings.arguments;
    final riderData = args is Map<String, dynamic> ? args : _rider;
    final otherUserId = riderData['otherUserId'] as String?;

    // Optimistic UI update
    setState(() {
      _messages.add({
        'id': _messages.length + 1,
        'message': msg,
        'isSender': true,
        'timestamp': _getCurrentTime(),
        'status': 'sent',
        'isImage': false,
      });
      _showSuggestRide = false;
    });
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    // Persist ride suggestion to Supabase
    if (currentUser != null && otherUserId != null) {
      final ids = [currentUser.id, otherUserId]..sort();
      final conversationId = ids.join('_');

      () async {
        try {
          await supabase.from('chat_messages').insert({
            'conversation_id': conversationId,
            'sender_id': currentUser.id,
            'recipient_id': otherUserId,
            'message_body': msg,
            'delivery_status': 'sent',
          });
        } catch (_) {
          if (mounted) {
            AppToast.show(
              context,
              message: 'Failed to send ride suggestion. Please try again.',
              type: ToastType.error,
            );
          }
        }
      }();
    }
  }

  void _deleteMessage(int id) {
    setState(() => _messages.removeWhere((m) => m['id'] == id));
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12
        ? now.hour - 12
        : now.hour == 0
        ? 12
        : now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadMessages();
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MessageOptionsSheetWidget(
        message: msg['message'] as String,
        onCopy: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Message copied',
                style: GoogleFonts.dmSans(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF1B365D),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onDelete: () => _deleteMessage(msg['id'] as int),
        onReport: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Message reported. Thank you.',
                style: GoogleFonts.dmSans(color: Colors.white),
              ),
              backgroundColor: const Color(0xFFB7791F),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _showImageFullscreen(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenImageView(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Allow arguments to override rider data
    final args = ModalRoute.of(context)?.settings.arguments;
    final riderData = args is Map<String, dynamic> ? args : _rider;

    // Resolve name
    final riderName = _resolveRiderName(riderData);
    // Resolve avatar
    final riderImage =
        riderData['otherUserAvatar'] as String? ??
        riderData['avatar_url'] as String? ??
        riderData['image'] as String? ??
        _rider['image'] as String;
    final bikeModel =
        riderData['bikeModel'] as String? ??
        (() {
          final bt = riderData['bike_types'];
          if (bt is List && bt.isNotEmpty) return bt.first.toString();
          return '';
        })();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(7.h),
        child: SafeArea(
          bottom: false,
          child: ChatHeaderWidget(
            riderName: riderName,
            riderImage: riderImage,
            bikeModel: bikeModel,
            isOnline: riderData['isOnline'] as bool? ?? true,
            onBackTap: () => Navigator.pop(context),
            onProfileTap: () {},
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? _buildChatSkeleton()
                : _messages.isEmpty
                ? SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 4.h),
                        ChatEmptyStateWidget(riderName: riderName),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: const Color(0xFFE85A4F),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isTyping && index == _messages.length) {
                          return TypingIndicatorWidget(riderName: riderName);
                        }
                        final msg = _messages[index];
                        return GestureDetector(
                          onTap: msg['isImage'] == true
                              ? () => _showImageFullscreen(
                                  msg['message'] as String,
                                )
                              : null,
                          child: ChatBubbleWidget(
                            message: msg['message'] as String,
                            timestamp: msg['timestamp'] as String,
                            isSender: msg['isSender'] as bool,
                            deliveryStatus: msg['status'] as String?,
                            isImage: msg['isImage'] as bool? ?? false,
                            imageUrl: msg['isImage'] == true
                                ? msg['message'] as String
                                : null,
                            onLongPress: () => _showMessageOptions(msg),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (_showSuggestRide)
            SuggestRideModalWidget(
              riderName: riderName,
              onClose: () => setState(() => _showSuggestRide = false),
              onSend: _sendRideSuggestion,
            ),
          ChatInputWidget(
            controller: _messageController,
            onSend: _sendMessage,
            onChanged: (_) {},
            onAttachPhoto: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Photo sharing coming soon',
                    style: GoogleFonts.dmSans(color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF1B365D),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            onShareLocation: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Location sharing coming soon',
                    style: GoogleFonts.dmSans(color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF2D5A27),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            onSuggestRide: () {
              setState(() => _showSuggestRide = !_showSuggestRide);
            },
            onPlanRoute: () {
              Navigator.pushNamed(context, '/route-planner-screen');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatSkeleton() {
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 1.5.h),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        ChatBubbleSkeleton(isSender: false),
        ChatBubbleSkeleton(isSender: true),
        ChatBubbleSkeleton(isSender: false),
        ChatBubbleSkeleton(isSender: true),
        ChatBubbleSkeleton(isSender: false),
        ChatBubbleSkeleton(isSender: true),
        ChatBubbleSkeleton(isSender: false),
      ],
    );
  }
}

class _FullscreenImageView extends StatelessWidget {
  final String imageUrl;

  const _FullscreenImageView({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            semanticLabel: 'Full screen ride photo shared in chat',
            errorBuilder: (_, __, ___) =>
                Icon(AppIcons.help, color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }
}
