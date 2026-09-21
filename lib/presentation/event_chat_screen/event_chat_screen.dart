import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/event_service.dart';
import '../../theme/app_theme.dart';

class EventChatScreen extends StatefulWidget {
  const EventChatScreen({super.key});

  @override
  State<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends State<EventChatScreen> {
  final EventService _eventService = EventService.instance;
  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<EventMessageInfo> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _channelId;
  String? _channelName;
  String _currentUserId = '';
  RealtimeChannel? _realtimeChannel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && _channelId == null) {
      _channelId = args['channelId'] as String;
      _channelName = args['channelName'] as String?;
      _currentUserId = _client.auth.currentUser?.id ?? '';
      _loadMessages();
      _subscribeToMessages();
    }
  }

  Future<void> _loadMessages() async {
    if (_channelId == null) return;
    setState(() => _loading = true);
    try {
      _messages = await _eventService.getChannelMessages(_channelId!);
    } catch (_) {}
    setState(() => _loading = false);
    _scrollToBottom();
  }

  void _subscribeToMessages() {
    if (_channelId == null) return;
    _realtimeChannel = _client
        .channel('event_chat:channelId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_channel_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'channel_id',
            value: _channelId!,
          ),
          callback: (payload) {
            try {
              final m = payload.newRecord;
              final msg = EventMessageInfo(
                id: m['id'] as String,
                channelId: m['channel_id'] as String,
                senderId: m['sender_id'] as String,
                body: m['body'] as String?,
                createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
              );
              setState(() {
                _messages.insert(0, msg);
              });
            } catch (_) {}
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _channelId == null) return;

    setState(() => _sending = true);
    _messageController.clear();

    final success = await _eventService.sendChannelMessage(_channelId!, body);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message'), backgroundColor: Colors.red),
      );
    }
    setState(() => _sending = false);
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(_channelName ?? 'Channel', style: const TextStyle(fontSize: 16)),
        backgroundColor: AppTheme.backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.secondaryDark))
                : _messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet. Start the conversation!', style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId == _currentUserId;
                          return _MessageBubble(
                            body: msg.body ?? '',
                            isMe: isMe,
                            time: _formatTime(msg.createdAt),
                          );
                        },
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppTheme.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending ? null : _sendMessage,
            icon: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.secondaryDark, strokeWidth: 2))
                : const Icon(Icons.send, color: AppTheme.secondaryDark),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final sb = StringBuffer();
    sb.write(hour);
    sb.write(':');
    sb.write(minute);
    sb.write(' ');
    sb.write(ampm);
    return sb.toString();
  }
}

class _MessageBubble extends StatelessWidget {
  final String body;
  final bool isMe;
  final String time;

  const _MessageBubble({required this.body, required this.isMe, required this.time});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.secondaryDark.withValues(alpha: 0.2) : AppTheme.cardDark,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 4),
            Text(time, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
