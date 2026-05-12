import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/ride_feed_service.dart';
import './widgets/image_upload_widget.dart';
import './widgets/bike_selector_widget.dart';
import './widgets/route_selector_widget.dart';
import '../../widgets/app_logo_widget.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _photoUrlController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();

  String? _selectedRoute;
  String? _selectedBike;
  String _distanceUnit = 'km';
  bool _isMetric = true;
  bool _isPosting = false;
  bool _showSuccess = false;

  bool _instagramConnected = false;
  bool _tiktokConnected = false;
  bool _youtubeConnected = false;

  List<String> _savedRoutes = [];
  List<String> _garageBikes = [];
  bool _isLoadingData = true;

  static const Color _orange = Color(0xFFE85A4F);
  static const Color _deepBlue = Color(0xFF1B365D);

  static const String _instagramConnectedKey = 'social_instagram_connected';
  static const String _tiktokConnectedKey = 'social_tiktok_connected';
  static const String _youtubeConnectedKey = 'social_youtube_connected';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _photoUrlController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final settingsMetric = prefs.getBool('unit_system_metric');
      final profileUnit = prefs.getString('profile_speed_unit');
      _isMetric = settingsMetric ?? (profileUnit == 'metric');
      _distanceUnit = _isMetric ? 'km' : 'mi';

      _instagramConnected = prefs.getBool(_instagramConnectedKey) ?? false;
      _tiktokConnected = prefs.getBool(_tiktokConnectedKey) ?? false;
      _youtubeConnected = prefs.getBool(_youtubeConnectedKey) ?? false;
    } catch (_) {}

    final routes = await RideFeedService.instance.fetchSavedRouteNames();
    final bikes = await RideFeedService.instance.fetchGarageBikeNames();

    if (mounted) {
      setState(() {
        _savedRoutes = routes;
        _garageBikes = bikes;
        if (bikes.isNotEmpty) _selectedBike = bikes.first;
        _isLoadingData = false;
      });
    }
  }

  bool get _canPost {
    final hasCaption = _captionController.text.trim().isNotEmpty;
    final hasPhoto = _photoUrlController.text.trim().isNotEmpty;
    return (hasCaption || hasPhoto) && !_isPosting;
  }

  Future<void> _handlePost() async {
    if (!_canPost) return;

    setState(() => _isPosting = true);

    final distanceText = _distanceController.text.trim();
    final distance = double.tryParse(distanceText) ?? 0.0;

    final post = await RideFeedService.instance.createPost(
      caption: _captionController.text.trim().isEmpty
          ? null
          : _captionController.text.trim(),
      photoUrl: _photoUrlController.text.trim().isEmpty
          ? null
          : _photoUrlController.text.trim(),
      routeName: _selectedRoute,
      distance: distance,
      distanceUnit: _distanceUnit,
      bikeName: _selectedBike,
    );

    if (!mounted) return;

    if (post != null) {
      setState(() {
        _isPosting = false;
        _showSuccess = true;
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() => _isPosting = false);
    }
  }

  String _buildShareText({String? platform, String? destination}) {
    final caption = _captionController.text.trim();
    final distance = _distanceController.text.trim();
    final route = _selectedRoute;
    final bike = _selectedBike;

    final parts = <String>[];
    if (caption.isNotEmpty) parts.add(caption);
    if (distance.isNotEmpty) parts.add('Distance: $distance $_distanceUnit');
    if (route != null && route.isNotEmpty) parts.add('Route: $route');
    if (bike != null && bike.isNotEmpty) parts.add('Bike: $bike');

    if (platform != null && destination != null) {
      parts.add('Shared to $platform $destination from RydMatch');
    }

    parts.add('#RydMatch #RideLife #Motorcycles');
    return parts.join('\n');
  }

  Future<void> _setSocialConnected(String platform, bool connected) async {
    final prefs = await SharedPreferences.getInstance();

    if (platform == 'Instagram') {
      await prefs.setBool(_instagramConnectedKey, connected);
      if (mounted) setState(() => _instagramConnected = connected);
    }

    if (platform == 'TikTok') {
      await prefs.setBool(_tiktokConnectedKey, connected);
      if (mounted) setState(() => _tiktokConnected = connected);
    }

    if (platform == 'youtube') {
      await prefs.setBool(_youtubeConnectedKey, connected);
      if (mounted) setState(() => _youtubeConnected = connected);
    }
  }

  bool _isSocialConnected(String platform) {
    switch (platform) {
      case 'Instagram':
        return _instagramConnected;
      case 'TikTok':
        return _tiktokConnected;
      case 'youtube':
        return _youtubeConnected;
      default:
        return false;
    }
  }

  void _handleSocialTap(String platform) {
    if (!_isSocialConnected(platform)) {
      _showConnectSocialSheet(platform);
      return;
    }

    if (platform == 'Instagram') {
      _showDestinationSheet(
        platform: 'Instagram',
        feedLabel: 'Post to Feed',
        storyLabel: 'Post to Story',
      );
      return;
    }

    if (platform == 'TikTok') {
      _showDestinationSheet(
        platform: 'TikTok',
        feedLabel: 'Post to Feed',
        storyLabel: 'Post to Story',
      );
      return;
    }

    _showDestinationSheet(
  platform: 'YouTube',
  feedLabel: 'Post to Channel',
  storyLabel: 'Post as Short',
  );
}

  void _showConnectSocialSheet(String platform) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22.0)),
        ),
        padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 11.w,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            SizedBox(height: 2.h),
            Icon(
              platform == 'Instagram'
                  ? Icons.camera_alt_rounded
                  : platform == 'TikTok'
                  ? Icons.music_note_rounded
                  : Icons.chat_bubble_rounded,
              color: _deepBlue,
              size: 36,
            ),
            SizedBox(height: 1.5.h),
            Text(
              'Connect $platform',
              style: GoogleFonts.dmSans(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Connect your account so RydMatch can prepare your ride post for $platform. You will still confirm the final post inside $platform.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            SizedBox(height: 2.5.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _setSocialConnected(platform, true);

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$platform connected'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  _handleSocialTap(platform);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _deepBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 1.6.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                ),
                child: Text(
                  'Connect $platform',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: 1.h),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Not now',
                style: GoogleFonts.dmSans(
                  fontSize: 12.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDestinationSheet({
    required String platform,
    required String feedLabel,
    required String storyLabel,
  }) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22.0)),
        ),
        padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 3.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 11.w,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            SizedBox(height: 1.5.h),
            Row(
              children: [
                Expanded(
                  child: Text(
                    platform,
                    style: GoogleFonts.dmSans(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _setSocialConnected(platform, false);
                  },
                  icon: const Icon(Icons.link_off_rounded, size: 16),
                  label: const Text('Disconnect'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),
            _destinationTile(
              theme: theme,
              icon: Icons.grid_on_rounded,
              title: feedLabel,
              subtitle: 'Share this ride as a regular $platform post.',
              onTap: () {
                Navigator.of(ctx).pop();
                _shareToPlatform(platform: platform, destination: 'Feed');
              },
            ),
            SizedBox(height: 1.h),
            _destinationTile(
              theme: theme,
              icon: Icons.auto_awesome_rounded,
              title: storyLabel,
              subtitle: 'Prepare this ride for a temporary $platform story.',
              onTap: () {
                Navigator.of(ctx).pop();
                _shareToPlatform(platform: platform, destination: 'Story');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _destinationTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.0),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _deepBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Icon(icon, color: _deepBlue, size: 21),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 10.5.sp,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareToPlatform({
    required String platform,
    required String destination,
  }) async {
    final text = _buildShareText(platform: platform, destination: destination);
    final subject = 'My Ride on RydMatch';

    if (platform == 'Instagram') {
      final instagramUrl = destination == 'Story'
          ? Uri.parse('instagram-stories://share')
          : Uri.parse('instagram://app');

      if (await canLaunchUrl(instagramUrl)) {
        await launchUrl(instagramUrl, mode: LaunchMode.externalApplication);
      }

      await SharePlus.instance.share(
        ShareParams(text: text, subject: subject),
      );
      return;
    }

    if (platform == 'TikTok') {
      final tikTokUrl = Uri.parse('snssdk1233://');

      if (await canLaunchUrl(tikTokUrl)) {
        await launchUrl(tikTokUrl, mode: LaunchMode.externalApplication);
      } else {
        final webUrl = Uri.parse('https://www.tiktok.com');
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      }

      await SharePlus.instance.share(
        ShareParams(text: text, subject: subject),
      );
      return;
    }

    if (platform == 'YouTube') {
  final youtubeUrl = Uri.parse('youtube://');

  if (await canLaunchUrl(youtubeUrl)) {
    await launchUrl(youtubeUrl, mode: LaunchMode.externalApplication);
  } else {
    final webUrl = Uri.parse('https://www.youtube.com/upload');
    if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  await SharePlus.instance.share(
    ShareParams(text: text, subject: subject),
  );
}
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _deepBlue,
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B365D), Color(0xFF2A4A7A)],
            ),
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
        title: Row(
          children: [
            AppLogoMark(size: 26),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'Share Your Ride',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 3.w),
            child: TextButton(
              onPressed: _canPost ? _handlePost : null,
              style: TextButton.styleFrom(
                backgroundColor: _canPost
                    ? _orange
                    : Colors.white.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.0),
                ),
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Post',
                      style: GoogleFonts.dmSans(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: _showSuccess
          ? _buildSuccessState()
          : _isLoadingData
          ? Center(child: CircularProgressIndicator(color: _orange))
          : _buildForm(theme),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20.w,
            height: 20.w,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 48,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Ride Shared!',
            style: GoogleFonts.dmSans(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Your ride has been posted to the feed.',
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImageUploadWidget(
            imageUrl: _photoUrlController.text.trim().isEmpty
                ? null
                : _photoUrlController.text.trim(),
            onTap: _showPhotoUrlDialog,
          ),
          SizedBox(height: 2.h),

          _buildSectionLabel(theme, 'Caption'),
          SizedBox(height: 0.8.h),
          TextField(
            controller: _captionController,
            maxLength: 300,
            maxLines: 3,
            style: GoogleFonts.dmSans(fontSize: 13.sp),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'How was your ride?',
              hintStyle: GoogleFonts.dmSans(
                fontSize: 12.sp,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 3.w,
                vertical: 1.5.h,
              ),
            ),
          ),
          SizedBox(height: 1.5.h),

          _buildSectionLabel(theme, 'Route'),
          SizedBox(height: 0.8.h),
          RouteSelectorWidget(
            routes: _savedRoutes,
            selectedRoute: _selectedRoute,
            onChanged: (v) => setState(() => _selectedRoute = v),
          ),
          SizedBox(height: 1.5.h),

          _buildSectionLabel(theme, 'Distance Covered'),
          SizedBox(height: 0.8.h),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _distanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.dmSans(fontSize: 13.sp),
                  decoration: InputDecoration(
                    hintText: '0.0',
                    hintStyle: GoogleFonts.dmSans(
                      fontSize: 12.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 1.5.h,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [_unitButton(theme, 'km'), _unitButton(theme, 'mi')],
                ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),

          _buildSectionLabel(theme, 'Bike Used'),
          SizedBox(height: 0.8.h),
          BikeSelectorWidget(
            bikes: _garageBikes,
            selectedBike: _selectedBike,
            onChanged: (v) => setState(() => _selectedBike = v),
          ),
          SizedBox(height: 2.5.h),

          _buildSectionLabel(theme, 'Share to Social Media'),
          SizedBox(height: 1.h),
          _buildSocialShareSection(theme),
          SizedBox(height: 2.5.h),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canPost ? _handlePost : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                disabledBackgroundColor: theme.colorScheme.outline.withValues(
                  alpha: 0.2,
                ),
                padding: EdgeInsets.symmetric(vertical: 1.8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Share Post',
                      style: GoogleFonts.dmSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 3.h),
        ],
      ),
    );
  }

  Widget _buildSocialShareSection(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSocialButton(
              label: 'Instagram',
              connected: _instagramConnected,
              icon: Icons.camera_alt_rounded,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF833AB4),
                  Color(0xFFE1306C),
                  Color(0xFFFD1D1D),
                  Color(0xFFF77737),
                ],
              ),
              onTap: () => _handleSocialTap('Instagram'),
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: _buildSocialButton(
              label: 'TikTok',
              connected: _tiktokConnected,
              icon: Icons.music_note_rounded,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF010101), Color(0xFF69C9D0)],
              ),
              onTap: () => _handleSocialTap('TikTok'),
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: _buildSocialButton(
              label: 'YouTube',
              connected: _youtubeConnected,
              icon: Icons.play_arrow_rounded,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF0000), Color(0xFFB00000)],
                ),
                onTap: () => _handleSocialTap('YouTube'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required bool connected,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
    Color labelColor = Colors.white,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 1.5.h),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 22),
                SizedBox(height: 0.5.h),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 0.2.h),
                Text(
                  connected ? 'Connected' : 'Connect',
                  style: GoogleFonts.dmSans(
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w600,
                    color: labelColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          if (connected)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(ThemeData theme, String label) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _unitButton(ThemeData theme, String unit) {
    final isSelected = _distanceUnit == unit;

    return GestureDetector(
      onTap: () => setState(() => _distanceUnit = unit),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
        decoration: BoxDecoration(
          color: isSelected ? _deepBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Text(
          unit,
          style: GoogleFonts.dmSans(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _showPhotoUrlDialog() {
    final controller = TextEditingController(text: _photoUrlController.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Photo URL',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'https://...',
            hintStyle: GoogleFonts.dmSans(fontSize: 12.sp),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _photoUrlController.text = controller.text.trim());
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _orange),
            child: const Text(
              'Set Photo',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
