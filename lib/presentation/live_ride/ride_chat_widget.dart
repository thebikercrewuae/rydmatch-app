import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RideChatWidget extends StatefulWidget {
  final String sessionId;
  final VoidCallback onClose;

  const RideChatWidget({
    super.key,
    required this.sessionId,
    required this.onClose,
  });

  @override
  State<RideChatWidget> createState() => _RideChatWidgetState();
}

class _RideChatWidgetState extends State<RideChatWidget> {
  final List<Map<String, dynamic>> _messages = [];
  final Map<String, String> _userNameCache = {};
  final Set<String> _knownMessageIds = {};

  late TextEditingController _messageController;
  late ScrollController _scrollController;

  RealtimeChannel? _chatChannel;
  bool _isSending = false;

  final _supabase = Supabase.instance.client;

  final List<String> _quickMessages = [
    'On my way!',
    'Pulling over',
    'Need gas',
    'Slow down',
    'Speed up',
    'Taking a break',
    'Watch out!',
    'Nice ride!',
  ];

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _loadMessages();
    _subscribeToMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _supabase
          .from('live_ride_messages')
          .select('id, user_id, message, created_at')
          .eq('session_id', widget.sessionId)
          .order('created_at', ascending: false)
          .limit(100);

      final loadedMessages = List<Map<String, dynamic>>.from(data);

      for (final message in loadedMessages) {
        final messageId = message['id']?.toString();
        if (messageId != null) _knownMessageIds.add(messageId);

        final userId = message['user_id'] as String?;
        if (userId != null && !_userNameCache.containsKey(userId)) {
          await _fetchAndCacheUserName(userId);
        }
      }

      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(loadedMessages);
        });
      }
    } catch (e) {
      debugPrint('RideChatWidget._loadMessages error: $e');
    }
  }

  Future<void> _fetchAndCacheUserName(String userId) async {
    final currentUserId = _supabase.auth.currentUser?.id;

    if (userId == currentUserId) {
      _userNameCache[userId] = 'You';
      return;
    }

    try {
      final data = await _supabase
          .from('user_profiles')
          .select('full_name, email')
          .eq('id', userId)
          .maybeSingle();

      final fullName = data?['full_name'] as String?;
      final email = data?['email'] as String?;

      if (fullName != null && fullName.trim().isNotEmpty) {
        _userNameCache[userId] = fullName.trim();
        return;
      }

      if (email != null && email.trim().isNotEmpty) {
        _userNameCache[userId] = email.split('@').first;
        return;
      }

      _userNameCache[userId] = 'Rider';
    } catch (e) {
      debugPrint('RideChatWidget._fetchAndCacheUserName error: $e');
      _userNameCache[userId] = 'Rider';
    }
  }

  String _displayNameFor(String? userId) {
    if (userId == null) return 'Rider';
    if (userId == _supabase.auth.currentUser?.id) return 'You';
    return _userNameCache[userId] ?? 'Rider';
  }

  void _subscribeToMessages() {
    _chatChannel?.unsubscribe();

    _chatChannel = _supabase
        .channel('ride_chat_${widget.sessionId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_ride_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: widget.sessionId,
          ),
          callback: (payload) async {
            final newMessage = Map<String, dynamic>.from(payload.newRecord);
            final messageId = newMessage['id']?.toString();

            if (messageId != null && _knownMessageIds.contains(messageId)) {
              return;
            }
            if (messageId != null) _knownMessageIds.add(messageId);

            final userId = newMessage['user_id'] as String?;
            if (userId != null && !_userNameCache.containsKey(userId)) {
              await _fetchAndCacheUserName(userId);
            }

            if (mounted) {
              setState(() {
                _messages.insert(0, newMessage);
              });
              _scrollToLatest();
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _fetchAndCacheUserName(userId);

      await _supabase.from('live_ride_messages').insert({
        'session_id': widget.sessionId,
        'user_id': userId,
        'message': text,
      });

      _messageController.clear();
    } catch (e) {
      debugPrint('RideChatWidget._sendMessage error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatTime(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _chatChannel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _supabase.auth.currentUser?.id;
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final panelHeight = math.min(
      480.0,
      math.max(390.0, media.size.height * 0.52),
    );

    return Container(
      width: double.infinity,
      height: panelHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withAlpha(242),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF2563EB).withAlpha(77),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(77),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Ride Chat',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withAlpha(26), height: 1),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Send a quick update to your group.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withAlpha(178),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final userId = message['user_id'] as String?;
                      final isOwn = userId != null && userId == currentUserId;
                      final displayName = _displayNameFor(userId);
                      final messageText = message['message'] as String? ?? '';
                      final createdAt = message['created_at'] as String?;
                      final timeStr = _formatTime(createdAt);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: isOwn
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: screenWidth * 0.75,
                              ),
                              child: Column(
                                crossAxisAlignment: isOwn
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isOwn
                                          ? const Color(0xFF93C5FD)
                                          : Colors.white54,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isOwn
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF2A2A3E),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      messageText,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    timeStr,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF111827).withAlpha(238),
              border: Border(
                top: BorderSide(color: Colors.white.withAlpha(20), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick replies',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: Colors.white.withAlpha(204),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickMessages.map((chip) {
                    return Material(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          _messageController.text = chip;
                          _sendMessage();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          child: Text(
                            chip,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFF0D0D1A),
            padding: EdgeInsets.fromLTRB(
              8,
              8,
              8,
              math.max(8.0, media.viewPadding.bottom),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withAlpha(20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      hintText: 'Message your group...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.send_rounded),
                  color: const Color(0xFF2563EB),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
