import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
  List<EventInfo> _filteredEvents = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  double? _myLat;
  double? _myLng;

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
      // Try to get user location for distance calculation
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            final position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 3)),
            );
            _myLat = position.latitude;
            _myLng = position.longitude;
          }
        }
      } catch (_) {}

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
      _applySearchFilter();
    } catch (e) {
      _error = 'Failed to load events';
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredEvents = _allEvents;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredEvents = _allEvents.where((e) {
        return e.name.toLowerCase().contains(query) ||
            (e.description?.toLowerCase().contains(query) ?? false) ||
            (e.locationName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
  }

  // Sort events: upcoming first, by closest date
  List<EventInfo> get _sortedEvents {
    final now = DateTime.now();
    final upcoming = _filteredEvents.where((e) => e.startDate.isAfter(now.subtract(const Duration(hours: 1)))).toList();
    upcoming.sort((a, b) => a.startDate.compareTo(b.startDate));
    return upcoming;
  }

  List<EventInfo> get _featuredEvents {
    final sorted = _sortedEvents;
    if (sorted.isEmpty) return [];
    // Feature events happening within the next 7 days
    final now = DateTime.now();
    final featured = sorted.where((e) => e.startDate.difference(now).inDays <= 7).toList();
    return featured.take(3).toList();
  }

  List<EventInfo> get _regularEvents {
    final featured = _featuredEvents;
    return _sortedEvents.where((e) => !featured.contains(e)).toList();
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
            Tab(text: 'Discover'),
            Tab(text: 'My Events'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.secondaryDark))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 16)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _loadEvents,
                        child: const Text('Retry', style: TextStyle(color: AppTheme.secondaryDark)),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDiscoverTab(),
                    _buildEventList(_myEvents, emptyMessage: 'You have not applied to any events yet.\n\nBrowse events and join the ride!'),
                  ],
                ),
    );
  }

  Widget _buildDiscoverTab() {
    if (_allEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('No events yet. Check back soon!', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadEvents,
              child: const Text('Refresh', style: TextStyle(color: AppTheme.secondaryDark)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: AppTheme.secondaryDark,
      child: CustomScrollView(
        slivers: [
          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (value) => setState(() { _searchQuery = value; _applySearchFilter(); }),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search events, locations...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),

          // Featured events (horizontal carousel)
          if (_featuredEvents.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                    const SizedBox(width: 6),
                    const Text('Happening Soon', style: TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _featuredEvents.length,
                  itemBuilder: (context, index) => _FeaturedEventCard(
                    event: _featuredEvents[index],
                    myLat: _myLat,
                    myLng: _myLng,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],

          // Regular events header
          if (_regularEvents.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.event_available, color: AppTheme.secondaryDark, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'All Events (${_regularEvents.length})',
                      style: const TextStyle(color: AppTheme.secondaryDark, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          // Regular events list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _EventCard(
                event: _regularEvents[index],
                myLat: _myLat,
                myLng: _myLng,
              ),
              childCount: _regularEvents.length,
            ),
          ),
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
        itemBuilder: (context, index) => _EventCard(event: events[index], myLat: _myLat, myLng: _myLng),
      ),
    );
  }
}

// Featured event card - wider, with banner image
class _FeaturedEventCard extends StatelessWidget {
  final EventInfo event;
  final double? myLat;
  final double? myLng;
  const _FeaturedEventCard({required this.event, this.myLat, this.myLng});

  @override
  Widget build(BuildContext context) {
    final timeUntil = _timeUntilEvent(event.startDate);
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/event-detail-screen', arguments: {'eventId': event.id, 'eventName': event.name}),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: timeUntil.isUrgent ? Colors.orange.withValues(alpha: 0.4) : Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner or gradient header
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: event.bannerUrl != null && event.bannerUrl!.isNotEmpty
                    ? Image.network(event.bannerUrl!, fit: BoxFit.cover)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.secondaryDark.withValues(alpha: 0.3), AppTheme.backgroundDark],
                          ),
                        ),
                        child: const Center(child: Icon(Icons.motorcycle, size: 36, color: Colors.white24)),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(event.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(timeUntil.isUrgent ? Icons.access_time : Icons.calendar_today, size: 12, color: timeUntil.isUrgent ? Colors.orange : Colors.white54),
                      const SizedBox(width: 4),
                      Text(timeUntil.label, style: TextStyle(color: timeUntil.isUrgent ? Colors.orange : Colors.white54, fontSize: 12, fontWeight: timeUntil.isUrgent ? FontWeight.w600 : FontWeight.normal)),
                    ],
                  ),
                  if (event.locationName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.white54),
                        const SizedBox(width: 4),
                        Expanded(child: Text(event.locationName!, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                  if (event.donationRequired) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.volunteer_activism, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        if (event.donationTarget != null)
                          Text(event.donationTarget!, style: const TextStyle(color: Colors.green, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventInfo event;
  final double? myLat;
  final double? myLng;
  const _EventCard({required this.event, this.myLat, this.myLng});

  @override
  Widget build(BuildContext context) {
    final timeUntil = _timeUntilEvent(event.startDate);
    final distance = _calculateDistance();
    return Card(
      color: AppTheme.cardDark,
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/event-detail-screen', arguments: {'eventId': event.id, 'eventName': event.name}),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner image if available
            if (event.bannerUrl != null && event.bannerUrl!.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 120,
                child: Image.network(event.bannerUrl!, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(event.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      if (timeUntil.isUrgent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text(timeUntil.label, style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  if (event.description != null) ...[
                    const SizedBox(height: 6),
                    Text(event.description!, style: const TextStyle(color: Colors.white54, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _InfoChip(icon: Icons.calendar_today, text: _formatDate(event.startDate), color: timeUntil.isUrgent ? Colors.orange : Colors.white54),
                      if (event.locationName != null)
                        _InfoChip(icon: Icons.location_on, text: event.locationName!, color: Colors.white54),
                      if (distance != null)
                        _InfoChip(icon: Icons.near_me, text: '${distance.toStringAsFixed(0)} km away', color: AppTheme.secondaryDark),
                      if (event.approvedCount != null && event.approvedCount! > 0)
                        _InfoChip(icon: Icons.group, text: '${event.approvedCount} joined', color: Colors.green),
                      if (event.donationRequired)
                        _InfoChip(icon: Icons.volunteer_activism, text: 'Charity', color: Colors.green),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _calculateDistance() {
    // Distance calculation would require event lat/lng which we don't have in EventInfo
    // Return null for now - can be added when event lat/lng is exposed
    return null;
  }
}

// Time until event helper
class _TimeUntil {
  final String label;
  final bool isUrgent;
  const _TimeUntil({required this.label, this.isUrgent = false});
}

_TimeUntil _timeUntilEvent(DateTime eventDate) {
  final now = DateTime.now();
  final diff = eventDate.difference(now);

  if (diff.isNegative) return const _TimeUntil(label: 'Ended', isUrgent: false);
  if (diff.inHours < 1) return const _TimeUntil(label: 'Starting soon!', isUrgent: true);
  if (diff.inHours < 24) return _TimeUntil(label: 'In ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}', isUrgent: true);
  if (diff.inDays == 0) return const _TimeUntil(label: 'Today!', isUrgent: true);
  if (diff.inDays == 1) return const _TimeUntil(label: 'Tomorrow', isUrgent: true);
  if (diff.inDays <= 7) return _TimeUntil(label: 'In ${diff.inDays} days', isUrgent: true);
  if (diff.inDays <= 30) return _TimeUntil(label: 'In ${diff.inDays} days');
  final months = (diff.inDays / 30).round();
  return _TimeUntil(label: 'In $months month${months == 1 ? '' : 's'}');
}

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final eventDay = DateTime(dt.year, dt.month, dt.day);
  final dayDiff = eventDay.difference(today).inDays;

  if (dayDiff == 0) return 'Today';
  if (dayDiff == 1) return 'Tomorrow';
  if (dayDiff < 7) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[dt.weekday - 1];
  }
  return '${dt.day}/${dt.month}';
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoChip({required this.icon, required this.text, this.color = Colors.white54});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}