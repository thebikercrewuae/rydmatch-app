import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/event_service.dart';
import '../../theme/app_theme.dart';

class EventChannelsScreen extends StatefulWidget {
  const EventChannelsScreen({super.key});

  @override
  State<EventChannelsScreen> createState() => _EventChannelsScreenState();
}

class _EventChannelsScreenState extends State<EventChannelsScreen> {
  final EventService _eventService = EventService.instance;

  List<EventChannelInfo> _channels = [];
  bool _loading = true;
  String? _eventId;
  RealtimeChannel? _realtimeChannel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && _eventId == null) {
      _eventId = args['eventId'] as String;
      _loadChannels();
    }
  }

  Future<void> _loadChannels() async {
    if (_eventId == null) return;
    setState(() => _loading = true);
    try {
      _channels = await _eventService.getEventChannels(_eventId!);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Event Channels'),
        backgroundColor: AppTheme.backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.secondaryDark))
          : _channels.isEmpty
              ? const Center(
                  child: Text('No channels available.', style: TextStyle(color: Colors.white54, fontSize: 16)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _channels.length,
                  itemBuilder: (context, index) {
                    final channel = _channels[index];
                    return Card(
                      color: AppTheme.cardDark,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Icon(
                          channel.isRestricted ? Icons.lock_outline : Icons.chat_bubble_outline,
                          color: channel.isRestricted ? Colors.orange : AppTheme.secondaryDark,
                        ),
                        title: Text(channel.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (channel.description != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(channel.description!, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                              ),
                            if (channel.isRestricted)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text('Restricted', style: TextStyle(color: Colors.orange, fontSize: 11)),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/event-chat-screen',
                            arguments: {'channelId': channel.id, 'channelName': channel.name},
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
