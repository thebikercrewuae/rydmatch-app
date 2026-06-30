import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/custom_bottom_bar.dart';
import '../../services/profile_service.dart';
import '../../services/notification_service.dart';
import '../../services/premium_service.dart';
import '../../widgets/notification_banner_overlay.dart';
import '../../theme/app_theme.dart';
import '../discovery_screen/discovery_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final NotificationService _notificationService = NotificationService.instance;

  // Only screens that live inside the IndexedStack (Discover tab)
  final List<Widget> _screens = const [DiscoveryScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationService.addListener(_onNotificationsChanged);
    _notificationService.initialize();
    PremiumService().refresh(reason: 'main_screen_init');
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PremiumService().refresh(reason: 'app_resumed');
    }
  }

  Future<void> _handleProfileTap() async {
    final isComplete = await ProfileService.isProfileComplete();
    if (!mounted) return;
    final route = isComplete ? '/profile-view-screen' : '/profile-setup-screen';
    Navigator.of(context, rootNavigator: true).pushNamed(route).then((_) {
      if (mounted) setState(() => _currentIndex = 0);
    });
    setState(() => _currentIndex = 3);
  }

  void _openNotifications() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamed('/notifications-screen');
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notificationService.unreadCount;

    return Theme(
      data: AppTheme.lightTheme,
      child: PopScope(
        canPop: false,
        child: NotificationBannerOverlay(
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF1B365D),
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1B365D), Color(0xFF2A4A7A)],
                  ),
                ),
              ),
              title: Text(
                'RydMatch',
                style: GoogleFonts.dmSans(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                        ),
                        onPressed: _openNotifications,
                        tooltip: 'Notifications',
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 6.0,
                          right: 6.0,
                          child: IgnorePointer(
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 16.0,
                                minHeight: 16.0,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                                vertical: 1.0,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE85A4F),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            body: ColoredBox(
              color: AppTheme.backgroundLight,
              child: IndexedStack(index: 0, children: _screens),
            ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: CustomBottomBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  if (index == 1) {
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed('/matches-screen').then((_) {
                      if (mounted) setState(() => _currentIndex = 0);
                    });
                    setState(() => _currentIndex = 1);
                    return;
                  }
                  if (index == 2) {
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed('/ride-feed-screen').then((_) {
                      if (mounted) setState(() => _currentIndex = 0);
                    });
                    setState(() => _currentIndex = 2);
                    return;
                  }
                  if (index == 3) {
                    _handleProfileTap();
                    return;
                  }
                  if (index == 4) {
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed('/route-planner-screen').then((_) {
                      if (mounted) setState(() => _currentIndex = 0);
                    });
                    setState(() => _currentIndex = 4);
                    return;
                  }
                  setState(() => _currentIndex = index);
                },
                badgeCounts: const {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}
