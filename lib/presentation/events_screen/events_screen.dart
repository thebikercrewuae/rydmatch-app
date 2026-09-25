import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/event_service.dart';
import '../../theme/app_theme.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with SingleTickerProviderStateMixin {
  final EventService _eventService = EventService.instance;
  late TabController _tabController;
  List<EventInfo> _allEvents = [];
  List<EventInfo> _myEvents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() { _loading = true; _error = null; });
    try {
      _allEvents = await _eventService.getOpenEvents();
      _myEvents = [];
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        for (final event in _allEvents) {
          final app = await _eventService.getMyApplication(event.id);
          if (app != null) {
            _myEvents.add(event);
          }
        }
      }
    } catch (e) {
      _error = 'Failed to load events';
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: AppTheme.backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.secondaryDark,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppTheme.secondaryDark,
          tabs: const [
            Tab(text: 'All Events'),
            Tab(text: 'My Events'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.secondaryDark))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white54)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEventList(_allEvents),
                    _buildEventList(_myEvents, emptyMessage: 'You have not applied to any events yet.'),
                  ],
                ),
    );
  }

  Widget _buildEventList(List<EventInfo> events, {String? emptyMessage}) {
    if (events.isEmpty) {
      return Center(
        child: Text(
          emptyMessage ?? 'No events yet. Check back soon!',
          style: const TextStyle(color: Colors.white54, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: AppTheme.secondaryDark,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return _EventCard(event: event);
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventInfo event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final dateStr = [event.startDate.day, event.startDate.month, event.startDate.year].join('/');
    return Card(
      color: AppTheme.cardDark,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/event-detail-screen',
            arguments: {'eventId': event.id, 'eventName': event.name},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.name,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: event.status == 'open'
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      event.status,
                      style: TextStyle(
                        color: event.status == 'open' ? Colors.green : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (event.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  event.description!,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                children: [
                  if (event.locationName != null)
                    _InfoChip(icon: Icons.location_on, text: event.locationName!),
                    _InfoChip(icon: Icons.calendar_today, text: [dateStr, ' at ', _formatEventTime(event.startDate)].join()),
                  if (event.maxRiders != null)
                    _InfoChip(icon: Icons.motorcycle, text: [event.maxRiders, ' riders'].join()),
                  if (event.donationRequired)
                    const _InfoChip(icon: Icons.volunteer_activism, text: 'Donation'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatEventTime(DateTime dt) {
  final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return [[hour.toString(), minute].join(':'), ' ', ampm].join();
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}