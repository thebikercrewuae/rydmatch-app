import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../presentation/chat_screen/chat_screen.dart';
import '../../presentation/live_ride/live_ride_map_screen.dart';
import '../../services/live_ride_service.dart';
import '../../services/notification_service.dart';

class NotificationBannerOverlay extends StatefulWidget {
  final Widget child;

  const NotificationBannerOverlay({super.key, required this.child});

  @override
  State<NotificationBannerOverlay> createState() =>
      _NotificationBannerOverlayState();
}

class _NotificationBannerOverlayState extends State<NotificationBannerOverlay> {
  StreamSubscription<AppNotification>? _subscription;
  final List<_BannerEntry> _activeBanners = [];

  @override
  void initState() {
    super.initState();
    _subscription = NotificationService.instance.bannerStream.listen(
      _showBanner,
    );
  }

  void _showBanner(AppNotification notification) {
    if (!mounted) return;
    final entry = _BannerEntry(notification: notification);
    setState(() => _activeBanners.add(entry));

    // Auto-dismiss after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _activeBanners.contains(entry)) {
        setState(() {
          _activeBanners.remove(entry);
        });
      }
    });
  }

  void _dismissBanner(_BannerEntry entry) {
    if (mounted) setState(() => _activeBanners.remove(entry));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._activeBanners.asMap().entries.map((e) {
          final index = e.key;
          final entry = e.value;
          return Positioned(
            top: MediaQuery.of(context).padding.top + 8.0 + (index * 88.0),
            left: 12.0,
            right: 12.0,
            child: _NotificationBanner(
              key: ValueKey(entry.notification.id),
              notification: entry.notification,
              onDismiss: () => _dismissBanner(entry),
              onTap: () {
                _dismissBanner(entry);
                NotificationService.instance.markAsRead(entry.notification.id);
                final route = entry.notification.actionRoute;
                final args = entry.notification.actionArguments;

                // Handle live ride notifications
                if (entry.notification.type == NotificationType.rideStarted) {
                  final sessionId = args?['session_id'] as String?;
                  if (sessionId != null && sessionId.isNotEmpty) {
                    LiveRideService.instance.joinRide(sessionId);
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => LiveRideMapScreen(
                          sessionId: sessionId,
                          isCreator: false,
                        ),
                      ),
                    );
                    return;
                  }
                }

                if (route != null && route.isNotEmpty) {
                  if (route == '/chat-screen' && args != null) {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        settings: RouteSettings(
                          name: '/chat-screen',
                          arguments: args,
                        ),
                        builder: (context) => const ChatScreen(),
                      ),
                    );
                  } else {
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed(route, arguments: args);
                  }
                }
              },
            ),
          );
        }),
      ],
    );
  }
}

class _BannerEntry {
  final AppNotification notification;
  _BannerEntry({required this.notification});
}

class _NotificationBanner extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _NotificationBanner({
    super.key,
    required this.notification,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
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

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(widget.notification.type);
    return Dismissible(
      key: ValueKey('dismiss_${widget.notification.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => widget.onDismiss(),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: color.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 12.0,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40.0,
                      height: 40.0,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconForType(widget.notification.type),
                        color: color,
                        size: 20.0,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.notification.title,
                            style: GoogleFonts.inter(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            widget.notification.message,
                            style: GoogleFonts.inter(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w400,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.65),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    // View button
                    GestureDetector(
                      onTap: widget.onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 6.0,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          'View',
                          style: GoogleFonts.inter(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    // Close button
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Icon(
                        Icons.close_rounded,
                        size: 18.0,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
