import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import '../../routes/app_routes.dart';
import '../../widgets/app_logo_widget.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _illustrationController;
  late Animation<double> _illustrationScale;

  static const String _onboardingKey = 'onboarding_seen';

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      title: 'Discover Riders Near You',
      subtitle:
          'Browse rider profiles filtered by bike type, skill level, and riding style. Find your perfect road companion within miles.',
      gradient: [Color(0xFF1B365D), Color(0xFF2A5298)],
      accentColor: Color(0xFF4A90D9),
      icon: Icons.explore_rounded,
      illustrationWidgets: _DiscoveryIllustration(),
    ),
    _OnboardingPage(
      title: 'Match on the Road',
      subtitle:
          'Swipe right on riders who share your pace and passion. When it\'s mutual, the road opens up — start chatting and plan your first ride.',
      gradient: [Color(0xFF8B1A1A), Color(0xFFE85A4F)],
      accentColor: Color(0xFFFF8A80),
      icon: Icons.favorite_rounded,
      illustrationWidgets: _MatchingIllustration(),
    ),
    _OnboardingPage(
      title: 'Join Ride Groups',
      subtitle:
          'Create or join group rides with verified riders. Set routes, share waypoints, and ride together with real-time coordination.',
      gradient: [Color(0xFF1A4A2E), Color(0xFF2D7A4F)],
      accentColor: Color(0xFF66BB6A),
      icon: Icons.group_rounded,
      illustrationWidgets: _RideGroupsIllustration(),
    ),
    _OnboardingPage(
      title: 'Ride with Confidence',
      subtitle:
          'Emergency SOS, live location sharing, and trusted contact alerts keep you safe on every journey. Your safety is our priority.',
      gradient: [Color(0xFF4A3000), Color(0xFFB7791F)],
      accentColor: Color(0xFFFFCA28),
      icon: Icons.shield_rounded,
      illustrationWidgets: _SafetyIllustration(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _illustrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _illustrationScale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _illustrationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _illustrationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _illustrationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _illustrationController.reset();
    _illustrationController.forward();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.registration);
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: page.gradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with skip
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Full logo mark in top bar
                    BrandLogoFull(width: 32.w),
                    // Skip button
                    if (_currentPage < _pages.length - 1)
                      TextButton(
                        onPressed: _completeOnboarding,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.75),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.dmSans(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 60),
                  ],
                ),
              ),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPageContent(index);
                  },
                ),
              ),

              // Bottom section: dots + button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _currentPage ? 24.0 : 8.0,
                          height: 8.0,
                          decoration: BoxDecoration(
                            color: i == _currentPage
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 2.5.h),

                    // CTA button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: page.gradient.last,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.0),
                          ),
                        ),
                        child: Text(
                          _currentPage < _pages.length - 1
                              ? 'Next'
                              : 'Get Started',
                          style: GoogleFonts.dmSans(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 1.5.h),
                    // Legal links
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/terms'),
                          child: Text(
                            'Terms of Service',
                            style: GoogleFonts.dmSans(
                              fontSize: 10.sp,
                              color: Colors.white.withValues(alpha: 0.5),
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '·',
                            style: GoogleFonts.dmSans(
                              fontSize: 10.sp,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/privacy'),
                          child: Text(
                            'Privacy Policy',
                            style: GoogleFonts.dmSans(
                              fontSize: 10.sp,
                              color: Colors.white.withValues(alpha: 0.5),
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent(int index) {
    final page = _pages[index];
    final isActive = index == _currentPage;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          AnimatedBuilder(
            animation: _illustrationController,
            builder: (context, child) {
              return Transform.scale(
                scale: isActive ? _illustrationScale.value : 1.0,
                child: child,
              );
            },
            child: RepaintBoundary(
              child: Container(
                width: 70.w,
                height: 30.h,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(28.0),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26.0),
                  child: page.illustrationWidgets,
                ),
              ),
            ),
          ),

          SizedBox(height: 4.h),

          // Feature badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(page.icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  _featureBadgeLabel(index),
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),

          SizedBox(height: 1.5.h),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _featureBadgeLabel(int index) {
    const labels = ['Discovery', 'Matching', 'Ride Groups', 'Safety'];
    return labels[index];
  }
}

class _OnboardingPage {
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final Color accentColor;
  final IconData icon;
  final Widget illustrationWidgets;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.accentColor,
    required this.icon,
    required this.illustrationWidgets,
  });
}

// ─── Illustration Widgets ────────────────────────────────────────────────────

class _DiscoveryIllustration extends StatelessWidget {
  const _DiscoveryIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background map-like grid
        CustomPaint(
          size: const Size(double.infinity, double.infinity),
          painter: _GridPainter(color: Colors.white.withValues(alpha: 0.08)),
        ),
        // Rider cards floating
        Positioned(
          top: 20,
          left: 20,
          child: _MiniRiderCard(
            imageUrl:
                'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=80&h=80&fit=crop',
            name: 'Alex',
            distance: '2.1 mi',
            color: const Color(0xFF4A90D9),
            semanticLabel: 'Motorcyclist Alex, 2.1 miles away',
          ),
        ),
        Positioned(
          bottom: 25,
          right: 18,
          child: _MiniRiderCard(
            imageUrl:
                'https://images.pexels.com/photos/1043474/pexels-photo-1043474.jpeg?w=80&h=80&fit=crop',
            name: 'Sam',
            distance: '3.8 mi',
            color: const Color(0xFF2A5298),
            semanticLabel: 'Motorcyclist Sam, 3.8 miles away',
          ),
        ),
        // Center pin
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.explore_rounded,
            color: Color(0xFF1B365D),
            size: 28,
          ),
        ),
        // Pulse rings
        _PulseRing(size: 80, opacity: 0.15),
        _PulseRing(size: 110, opacity: 0.08),
      ],
    );
  }
}

class _MatchingIllustration extends StatelessWidget {
  const _MatchingIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Left profile
        Positioned(
          left: 16,
          child: _ProfileCircle(
            imageUrl:
                'https://images.pixabay.com/photo/2016/11/29/13/14/attractive-1869761_640.jpg',
            size: 72,
            semanticLabel: 'Female rider profile photo',
          ),
        ),
        // Right profile
        Positioned(
          right: 16,
          child: _ProfileCircle(
            imageUrl:
                'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80&h=80&fit=crop',
            size: 72,
            semanticLabel: 'Male rider profile photo',
          ),
        ),
        // Heart in center
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE85A4F), Color(0xFFFF8A80)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE85A4F).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        // Compatibility bar at bottom
        Positioned(
          bottom: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  '94% Compatible',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RideGroupsIllustration extends StatelessWidget {
  const _RideGroupsIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Route line
        CustomPaint(
          size: const Size(double.infinity, double.infinity),
          painter: _RoutePainter(color: Colors.white.withValues(alpha: 0.25)),
        ),
        // Group avatars in formation
        Positioned(
          top: 30,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SmallAvatar(
                imageUrl:
                    'https://images.pexels.com/photos/220453/pexels-photo-220453.jpeg?w=50&h=50&fit=crop',
                semanticLabel: 'Group rider 1',
              ),
              const SizedBox(width: 8),
              _SmallAvatar(
                imageUrl:
                    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=50&h=50&fit=crop',
                semanticLabel: 'Group rider 2',
              ),
              const SizedBox(width: 8),
              _SmallAvatar(
                imageUrl:
                    'https://images.pixabay.com/photo/2017/08/01/01/33/beautiful-2563491_640.jpg',
                semanticLabel: 'Group rider 3',
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                child: Center(
                  child: Text(
                    '+5',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Group name badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_rounded, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                'Sunday Crew',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '8 riders · 42 mi route',
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        // Waypoint dots
        Positioned(
          bottom: 22,
          left: 30,
          child: _WaypointDot(color: const Color(0xFF66BB6A)),
        ),
        Positioned(
          bottom: 22,
          right: 30,
          child: _WaypointDot(color: Colors.white),
        ),
      ],
    );
  }
}

class _SafetyIllustration extends StatelessWidget {
  const _SafetyIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Shield background glow
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFCA28).withValues(alpha: 0.15),
          ),
        ),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFCA28).withValues(alpha: 0.2),
          ),
        ),
        // Shield icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFCA28), Color(0xFFFFB300)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFCA28).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Color(0xFF4A3000),
            size: 34,
          ),
        ),
        // Feature chips
        Positioned(
          top: 18,
          right: 14,
          child: _SafetyChip(label: 'SOS Alert', icon: Icons.sos_rounded),
        ),
        Positioned(
          bottom: 18,
          left: 14,
          child: _SafetyChip(
            label: 'Live Location',
            icon: Icons.location_on_rounded,
          ),
        ),
        Positioned(
          bottom: 18,
          right: 14,
          child: _SafetyChip(
            label: 'Trusted Contacts',
            icon: Icons.contacts_rounded,
          ),
        ),
      ],
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

class _MiniRiderCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String distance;
  final Color color;
  final String semanticLabel;

  const _MiniRiderCard({
    required this.imageUrl,
    required this.name,
    required this.distance,
    required this.color,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.network(
              imageUrl,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              semanticLabel: semanticLabel,
              errorBuilder: (_, __, ___) => Container(
                width: 32,
                height: 32,
                color: color.withValues(alpha: 0.3),
                child: const Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                distance,
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileCircle extends StatelessWidget {
  final String imageUrl;
  final double size;
  final String semanticLabel;

  const _ProfileCircle({
    required this.imageUrl,
    required this.size,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          semanticLabel: semanticLabel,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.white.withValues(alpha: 0.2),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  final String imageUrl;
  final String semanticLabel;

  const _SmallAvatar({required this.imageUrl, required this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          semanticLabel: semanticLabel,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.white.withValues(alpha: 0.2),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _SafetyChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SafetyChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaypointDot extends StatelessWidget {
  final Color color;
  const _WaypointDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
        ],
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final double size;
  final double opacity;
  const _PulseRing({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }
}

// ─── Custom Painters ─────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

class _RoutePainter extends CustomPainter {
  final Color color;
  _RoutePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.8)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.2,
        size.width * 0.7,
        size.height * 0.8,
        size.width * 0.9,
        size.height * 0.2,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) => false;
}
