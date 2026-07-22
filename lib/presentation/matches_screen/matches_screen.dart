import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sizer/sizer.dart';

import '../../services/swipe_service.dart';
import '../../services/diagnostics_service.dart';
import '../../widgets/app_icons.dart';
import '../chat_screen/chat_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _searchQuery = '';
  bool _isSearchVisible = false;
  int _selectedTabIndex = 0;

  final List<Map<String, dynamic>> _allMatches = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _tabs = ['All', 'Rider', 'Coffee', 'Trackday', 'Touring'];

  List<Map<String, dynamic>> get _filteredMatches {
    List<Map<String, dynamic>> list = List.from(_allMatches);

    if (_selectedTabIndex != 0) {
      final tab = _tabs[_selectedTabIndex].toLowerCase();
      list = list.where((m) {
        final bikeTypes = m['bike_types'];
        if (bikeTypes is List && bikeTypes.isNotEmpty) {
          return bikeTypes.any((b) => b.toString().toLowerCase().contains(tab));
        }
        return false;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((m) {
        final name = ((m['full_name'] as String?) ?? '').toLowerCase();
        final email = ((m['email'] as String?) ?? '').toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }

    return list;
  }

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final matches = await SwipeService.instance.getMatches();

      if (!mounted) return;

      setState(() {
        _allMatches
          ..clear()
          ..addAll(matches);
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('MatchesScreen._loadMatches error: $e\n$stack');
      await DiagnosticsService.instance.logError(
        feature: 'matches',
        action: 'load_matches_screen',
        error: e,
        stackTrace: stack,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _onRefresh() => _loadMatches();

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  void _navigateToProfile(Map<String, dynamic> match) {
    final otherUserId = match['id'] as String?;
    final otherUserName = _displayName(match);
    final otherUserAvatar = _avatarUrl(match);

    if (otherUserId == null || otherUserId.isEmpty) return;

    Navigator.pushNamed(
      context,
      '/profile-view-screen',
      arguments: {
        'isOtherUser': true,
        'userId': otherUserId,
        'userName': otherUserName,
        'userImage': otherUserAvatar.isEmpty ? null : otherUserAvatar,
        'profileData': match,
      },
    );
  }

  void _navigateToChat(Map<String, dynamic> match) {
    final otherUserId = match['id'] as String?;
    final otherUserName = _displayName(match);
    final otherUserAvatar = _avatarUrl(match);

    if (otherUserId == null || otherUserId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(
          name: '/chat-screen',
          arguments: {
            'matchId': otherUserId,
            'otherUserId': otherUserId,
            'otherUserName': otherUserName,
            'otherUserAvatar': otherUserAvatar,
          },
        ),
        builder: (context) => const ChatScreen(),
      ),
    );
  }

  String _displayName(Map<String, dynamic> match) {
    final name = (match['full_name'] as String?) ?? '';
    if (name.trim().isNotEmpty) return name.trim();

    final email = (match['email'] as String?) ?? '';
    if (email.isNotEmpty) return email.split('@').first;

    return 'Rider';
  }

  String _bikeType(Map<String, dynamic> match) {
    final bikeTypes = match['bike_types'];
    if (bikeTypes is List && bikeTypes.isNotEmpty) {
      return bikeTypes.first.toString();
    }
    return 'Not specified';
  }

  String _avatarUrl(Map<String, dynamic> match) {
    final url = match['avatar_url'] as String?;
    if (url == null) return '';

    final trimmed = url.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('blob:') ||
        trimmed.startsWith('file:')) {
      return '';
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F1923)
          : const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            if (_isSearchVisible) _buildSearchBar(theme),
            _buildTabBar(theme),
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      color: theme.scaffoldBackgroundColor,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
            color: const Color(0xFF1B365D),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              'Matches',
              style: GoogleFonts.dmSans(
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1B365D),
              ),
            ),
          ),
          if (_allMatches.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE85A4F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_allMatches.length}',
                style: GoogleFonts.dmSans(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          SizedBox(width: 1.w),
          IconButton(
            onPressed: _toggleSearch,
            icon: Icon(
              _isSearchVisible ? Icons.close : Icons.search,
              color: const Color(0xFF1B365D),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search matches...',
          hintStyle: GoogleFonts.dmSans(
            fontSize: 14.0,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 3.w,
            vertical: 1.2.h,
          ),
        ),
        style: GoogleFonts.dmSans(fontSize: 14.0),
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      height: 5.h,
      margin: EdgeInsets.symmetric(vertical: 1.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        itemCount: _tabs.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedTabIndex == index;

          return GestureDetector(
            onTap: () => setState(() => _selectedTabIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: 2.w),
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.8.h),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1B365D) : theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1B365D)
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _tabs[index],
                style: GoogleFonts.dmSans(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 2.h),
              Text(
                'Could not load matches',
                style: GoogleFonts.dmSans(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 1.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage,
                  style: GoogleFonts.dmSans(
                    fontSize: 11.0,
                    color: Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 3.h),
              ElevatedButton.icon(
                onPressed: _loadMatches,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  'Try Again',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B365D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredMatches;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No matches yet', style: GoogleFonts.dmSans(fontSize: 18.0)),
            SizedBox(height: 1.h),
            Text(
              'Start swiping to find your riding partner!',
              style: GoogleFonts.dmSans(
                fontSize: 13.0,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 3.h),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/discovery-screen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B365D),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Keep Swiping',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final match = filtered[index];
          return _buildMatchTile(context, match, theme);
        },
      ),
    );
  }

  Widget _buildMatchTile(
    BuildContext context,
    Map<String, dynamic> match,
    ThemeData theme,
  ) {
    final name = _displayName(match);
    final bike = _bikeType(match);
    final avatarUrl = _avatarUrl(match);

    return InkWell(
      onTap: () => _navigateToProfile(match),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.5.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _avatarPlaceholder(name),
                      errorWidget: (_, __, ___) => _avatarPlaceholder(name),
                    )
                  : _avatarPlaceholder(name),
            ),
            SizedBox(width: 3.w),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.dmSans(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                  SizedBox(height: 0.4.h),
                  Row(
                    children: [
                      Icon(
                        AppIcons.motorcycle,
                        size: 13,
                        color: const Color(0xFF1B365D),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          bike,
                          style: GoogleFonts.dmSans(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1B365D),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: const Color(0xFF1B365D).withValues(alpha: 0.08),
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: () => _navigateToChat(match),
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF8EC5FF),
                    size: 18,
                  ),
                  tooltip: 'Open chat',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(String name) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 56,
      height: 56,
      color: const Color(0xFF1B365D).withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.dmSans(
            fontSize: 20.0,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1B365D),
          ),
        ),
      ),
    );
  }
}

