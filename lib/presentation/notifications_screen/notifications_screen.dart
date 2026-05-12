import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/notification_service.dart';
import '../live_ride/live_ride_map_screen.dart';
import '../ride_groups_screen/ride_groups_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.newMatch:
        return Icons.favorite_rounded;
      case NotificationType.newMessage:
        return Icons.chat_bubble_rounded;
      case NotificationType.rideGroupInvite:
        return Icons.group_rounded;
      case NotificationType.rideStarted:
        return Icons.motorcycle_rounded;
      case NotificationType.urgentAlert:
        return Icons.warning_amber_rounded;
    }
  }

  Color _colorForType(NotificationType type) {
    switch (type) {
      case NotificationType.newMatch:
        return const Color(0xFFE85A4F);
      case NotificationType.newMessage:
        return const Color(0xFF1B365D);
      case NotificationType.rideGroupInvite:
        return const Color(0xFF2D5A27);
      case NotificationType.rideStarted:
        return const Color(0xFF2E7D32);
      case NotificationType.urgentAlert:
        return const Color(0xFFB7791F);
    }
  }

  String _labelForType(NotificationType type) {
    switch (type) {
      case NotificationType.newMatch:
        return 'New Match';
      case NotificationType.newMessage:
        return 'Message';
      case NotificationType.rideGroupInvite:
        return 'Ride Invite';
      case NotificationType.rideStarted:
        return 'Live Ride';
      case NotificationType.urgentAlert:
        return 'Urgent';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _onTap(AppNotification notification) {
    _service.markAsRead(notification.id);

    if (notification.type == NotificationType.rideGroupInvite) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => const RideGroupsScreen()),
      );
      return;
    }

    if (notification.type == NotificationType.rideStarted) {
      final args = notification.actionArguments;
      final sessionId = args?['session_id'] as String?;
      if (sessionId != null && sessionId.isNotEmpty) {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) =>
                LiveRideMapScreen(sessionId: sessionId, isCreator: false),
          ),
        );
        return;
      }
    }

    final route = notification.actionRoute;
    if (route != null && route.isNotEmpty) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamed(route, arguments: notification.actionArguments);
    }
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Clear all notifications?',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will permanently remove all notifications from your list.',
          style: GoogleFonts.dmSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.dmSans()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Clear all', style: GoogleFonts.dmSans()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.clearAllNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _service.notifications;
    final unread = _service.unreadCount;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B365D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.dmSans(
            fontSize: 18.0,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          if (notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onSelected: (value) async {
                if (value == 'mark_read') {
                  await _service.markAllAsRead();
                  return;
                }

                if (value == 'clear_all') {
                  await _confirmClearAll();
                }
              },
              itemBuilder: (_) => [
                if (unread > 0)
                  const PopupMenuItem(
                    value: 'mark_read',
                    child: Text('Mark all read'),
                  ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Text('Clear all'),
                ),
              ],
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => Divider(
                height: 1.0,
                indent: 72.0,
                color: Theme.of(context).dividerColor,
              ),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return _NotificationTile(
                  notification: n,
                  color: _colorForType(n.type),
                  icon: _iconForType(n.type),
                  label: _labelForType(n.type),
                  timeAgo: _timeAgo(n.createdAt),
                  onTap: () => _onTap(n),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72.0,
            height: 72.0,
            decoration: BoxDecoration(
              color: const Color(0xFF1B365D).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 36.0,
              color: Color(0xFF1B365D),
            ),
          ),
          const SizedBox(height: 16.0),
          Text(
            'No notifications yet',
            style: GoogleFonts.inter(
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            'Matches, messages, and ride invites\nwill appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.0,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final Color color;
  final IconData icon;
  final String label;
  final String timeAgo;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.color,
    required this.icon,
    required this.label,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread ? color.withValues(alpha: 0.04) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 44.0,
                  height: 44.0,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22.0),
                ),
                if (isUnread)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 10.0,
                      height: 10.0,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeAgo,
                        style: GoogleFonts.inter(
                          fontSize: 11.0,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    notification.title,
                    style: GoogleFonts.inter(
                      fontSize: 14.0,
                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    notification.message,
                    style: GoogleFonts.inter(
                      fontSize: 13.0,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
