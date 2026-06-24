import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDiagnosticsScreen extends StatefulWidget {
  const AdminDiagnosticsScreen({super.key});

  @override
  State<AdminDiagnosticsScreen> createState() => _AdminDiagnosticsScreenState();
}

class _AdminDiagnosticsScreenState extends State<AdminDiagnosticsScreen> {
  static const Color _deepBlue = Color(0xFF1B365D);
  static const Color _orange = Color(0xFFE85A4F);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _screenBackground = Color(0xFFF1F5F9);
  static const Color _bodyText = Color(0xFF172033);

  final _searchController = TextEditingController();

  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _isLoading = false;
  String _selectedFeature = 'all';
  String _selectedSeverity = 'all';
  String _searchQuery = '';
  List<Map<String, dynamic>> _errors = [];
  Map<String, Map<String, dynamic>> _profilesById = {};
  Map<String, dynamic>? _matchingHealth;
  String? _matchingHealthError;
  Map<String, dynamic>? _liveRideHealth;
  String? _liveRideHealthError;
  Map<String, dynamic>? _notificationHealth;
  String? _notificationHealthError;
  Map<String, dynamic>? _stravaHealth;
  String? _stravaHealthError;
  Map<String, dynamic>? _aiReview;
  String? _aiReviewError;
  bool _isAiReviewLoading = false;

  final List<String> _features = const [
    'all',
    'matching',
    'profile_media',
    'discovery',
    'matches',
    'notifications',
    'ride_groups',
    'route_planner',
    'premium',
    'strava',
    'emergency_sos',
    'live_ride',
    'live_ride_voice',
  ];

  final List<String> _severities = const ['all', 'error', 'warning', 'info'];

  List<Map<String, dynamic>> get _uniqueErrors {
    final seen = <String>{};
    return _errors.where((error) => seen.add(_errorSignature(error))).toList();
  }

  List<Map<String, dynamic>> get _visibleErrors {
    final q = _searchQuery.trim().toLowerCase();
    return _uniqueErrors.where((error) {
      if (_selectedFeature != 'all' &&
          error['feature']?.toString() != _selectedFeature) {
        return false;
      }
      if (_selectedSeverity != 'all' &&
          error['severity']?.toString() != _selectedSeverity) {
        return false;
      }
      if (q.isEmpty) return true;

      final user = _profileFor(error);
      final text = [
        error['feature'],
        error['action'],
        error['severity'],
        error['message'],
        error['platform'],
        error['user_id'],
        user?['full_name'],
        user?['email'],
      ].whereType<Object>().join(' ').toLowerCase();
      return text.contains(q);
    }).toList();
  }

  Map<String, int> get _featureCounts {
    final counts = <String, int>{};
    for (final error in _uniqueErrors) {
      final feature = (error['feature'] ?? 'unknown').toString();
      counts[feature] = (counts[feature] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> get _signatureCounts {
    final counts = <String, int>{};
    for (final error in _errors) {
      final key = '${error['feature']}|${error['action']}|${error['message']}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAndLoad() async {
    try {
      final result =
          await Supabase.instance.client.rpc('is_admin_user') as bool?;
      if (!mounted) return;

      setState(() {
        _isAdmin = result ?? false;
        _checkingAdmin = false;
      });

      if (_isAdmin) {
        await _loadDashboard();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _checkingAdmin = false;
      });
    }
  }

  Future<void> _loadDashboard() async {
    await Future.wait([
      _loadErrors(),
      _loadMatchingHealth(),
      _loadOperationalHealth(),
      _loadStravaHealth(),
      _loadLatestAiReview(),
    ]);
  }

  Future<void> _loadErrors() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await Supabase.instance.client
          .from('app_errors')
          .select(
            'id, user_id, feature, action, severity, message, stack_trace, context, platform, is_debug, created_at',
          )
          .eq('is_debug', false)
          .gte(
            'created_at',
            DateTime.now()
                .subtract(const Duration(days: 30))
                .toUtc()
                .toIso8601String(),
          )
          .order('created_at', ascending: false)
          .limit(500);

      final errors = List<Map<String, dynamic>>.from(data);
      final profiles = await _loadProfilesForErrors(errors);

      if (!mounted) return;
      setState(() {
        _errors = errors;
        _profilesById = profiles;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Could not load diagnostics.', isError: true);
    }
  }

  Future<Map<String, Map<String, dynamic>>> _loadProfilesForErrors(
    List<Map<String, dynamic>> errors,
  ) async {
    final userIds = errors
        .map((e) => e['user_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    if (userIds.isEmpty) return {};

    try {
      final data = await Supabase.instance.client
          .from('user_profiles')
          .select('id, full_name, email')
          .inFilter('id', userIds);

      return {
        for (final row in List<Map<String, dynamic>>.from(data))
          row['id'].toString(): row,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _loadMatchingHealth() async {
    try {
      final supabase = Supabase.instance.client;

      final swipeRows = await supabase
          .from('swipes')
          .select('swiper_id, swiped_id, direction, created_at')
          .eq('direction', 'right')
          .limit(3000);

      final riderMatchRows = await supabase
          .from('rider_matches')
          .select('user1_id, user2_id, created_at')
          .limit(3000);

      final legacyMatchRows = await supabase
          .from('matches')
          .select('user_id, matched_user_id, created_at')
          .limit(6000);

      final rightSwipes = List<Map<String, dynamic>>.from(swipeRows);
      final riderMatches = List<Map<String, dynamic>>.from(riderMatchRows);
      final legacyMatches = List<Map<String, dynamic>>.from(legacyMatchRows);

      final rightPairs = <String, Set<String>>{};
      for (final swipe in rightSwipes) {
        final swiperId = swipe['swiper_id']?.toString();
        final swipedId = swipe['swiped_id']?.toString();
        if (swiperId == null || swipedId == null || swiperId == swipedId) {
          continue;
        }
        final pair = _pairKey(swiperId, swipedId);
        rightPairs.putIfAbsent(pair, () => <String>{}).add(swiperId);
      }

      final mutualPairs = rightPairs.entries
          .where((entry) => entry.value.length >= 2)
          .map((entry) => entry.key)
          .toSet();

      final riderMatchPairs = riderMatches
          .map((row) {
            final user1 = row['user1_id']?.toString();
            final user2 = row['user2_id']?.toString();
            return user1 == null || user2 == null
                ? null
                : _pairKey(user1, user2);
          })
          .whereType<String>()
          .toSet();

      final legacyDirectedPairs = legacyMatches
          .map((row) {
            final user1 = row['user_id']?.toString();
            final user2 = row['matched_user_id']?.toString();
            return user1 == null || user2 == null ? null : '$user1->$user2';
          })
          .whereType<String>()
          .toSet();

      final missingRiderMatches =
          mutualPairs.where((pair) => !riderMatchPairs.contains(pair)).toList()
            ..sort();

      final missingLegacyDirections = <String>[];
      for (final pair in riderMatchPairs) {
        final parts = pair.split('|');
        if (parts.length != 2) {
          continue;
        }
        final aToB = '${parts[0]}->${parts[1]}';
        final bToA = '${parts[1]}->${parts[0]}';
        if (!legacyDirectedPairs.contains(aToB)) {
          missingLegacyDirections.add(aToB);
        }
        if (!legacyDirectedPairs.contains(bToA)) {
          missingLegacyDirections.add(bToA);
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _matchingHealthError = null;
        _matchingHealth = {
          'rightSwipeCount': rightSwipes.length,
          'mutualSwipePairs': mutualPairs.length,
          'riderMatchPairs': riderMatchPairs.length,
          'legacyMatchRows': legacyDirectedPairs.length,
          'missingRiderMatches': missingRiderMatches,
          'missingLegacyDirections': missingLegacyDirections,
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _matchingHealth = null;
        _matchingHealthError = e.toString();
      });
    }
  }

  Future<void> _loadStravaHealth() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'strava-auth',
        body: {'action': 'admin_status'},
      );

      final data = response.data;
      if (data is! Map) {
        throw Exception('Invalid Strava diagnostics response');
      }

      if (!mounted) return;
      setState(() {
        _stravaHealth = Map<String, dynamic>.from(data);
        _stravaHealthError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stravaHealth = null;
        _stravaHealthError = e.toString();
      });
    }
  }

  Future<void> _loadOperationalHealth() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'admin-growth-dashboard',
      );

      final data = response.data;
      if (data is! Map ||
          data['liveRide'] is! Map ||
          data['notifications'] is! Map) {
        throw Exception('Invalid operational diagnostics response');
      }

      if (!mounted) return;
      final liveRide = Map<String, dynamic>.from(data['liveRide'] as Map);
      final notifications = Map<String, dynamic>.from(
        data['notifications'] as Map,
      );
      setState(() {
        _liveRideHealth = liveRide;
        _liveRideHealthError = liveRide['available'] == false
            ? liveRide['error']?.toString() ??
                  'Live ride diagnostics unavailable'
            : null;
        _notificationHealth = notifications;
        _notificationHealthError = notifications['available'] == false
            ? notifications['error']?.toString() ??
                  'Notification diagnostics unavailable'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liveRideHealth = null;
        _liveRideHealthError = e.toString();
        _notificationHealth = null;
        _notificationHealthError = e.toString();
      });
    }
  }

  Future<void> _loadAiReview() async {
    if (_isAiReviewLoading) return;

    setState(() {
      _isAiReviewLoading = true;
      _aiReviewError = null;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'admin-diagnostics-review',
        body: {
          'days': 30,
          'feature': _selectedFeature == 'all' ? null : _selectedFeature,
          'severity': _selectedSeverity == 'all' ? null : _selectedSeverity,
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw Exception('Invalid AI diagnostics response');
      }
      if (data['error'] != null) {
        throw Exception(data['error'].toString());
      }

      if (!mounted) return;
      setState(() {
        _aiReview = Map<String, dynamic>.from(data);
        _aiReviewError = null;
        _isAiReviewLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiReviewError = e.toString();
        _isAiReviewLoading = false;
      });
      _showSnack('Could not load AI diagnostic review.', isError: true);
    }
  }

  Future<void> _loadLatestAiReview() async {
    try {
      final data = await Supabase.instance.client
          .from('admin_diagnostic_reviews')
          .select('review')
          .order('generated_at', ascending: false)
          .limit(1);

      final rows = List<Map<String, dynamic>>.from(data);
      if (rows.isEmpty) return;
      final review = rows.first['review'];
      if (review is! Map) return;

      if (!mounted) return;
      setState(() {
        _aiReview = Map<String, dynamic>.from(review);
        _aiReviewError = null;
      });
    } catch (_) {
      // The scheduled review table may not exist until the migration is applied.
    }
  }

  String _pairKey(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}|${ids[1]}';
  }

  Map<String, dynamic>? _profileFor(Map<String, dynamic> error) {
    final userId = error['user_id']?.toString();
    if (userId == null || userId.isEmpty) return null;
    return _profilesById[userId];
  }

  String _formatDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '';

    final local = parsed.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String _prettyJson(dynamic value) {
    if (value == null) return '';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  String _errorSignature(Map<String, dynamic> error) {
    return '${error['feature']}|${error['action']}|${error['message']}';
  }

  String _copyPayload(Map<String, dynamic> error) {
    final user = _profileFor(error);
    return const JsonEncoder.withIndent('  ').convert({
      'id': error['id'],
      'feature': error['feature'],
      'action': error['action'],
      'severity': error['severity'],
      'message': error['message'],
      'created_at': error['created_at'],
      'platform': error['platform'],
      'is_debug': error['is_debug'],
      'user': {
        'id': error['user_id'],
        'name': user?['full_name'],
        'email': user?['email'],
      },
      'context': error['context'],
      'stack_trace': error['stack_trace'],
    });
  }

  Future<void> _copyErrorDetails(Map<String, dynamic> error) async {
    await Clipboard.setData(ClipboardData(text: _copyPayload(error)));
    if (!mounted) return;
    _showSnack('Diagnostic details copied.');
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'warning':
        return const Color(0xFFB7791F);
      case 'info':
        return const Color(0xFF1976D2);
      default:
        return _orange;
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans()),
        backgroundColor: isError ? _orange : _deepBlue,
      ),
    );
  }

  void _showErrorDetails(Map<String, dynamic> error) {
    final user = _profileFor(error);
    final repeatCount = _signatureCounts[_errorSignature(error)] ?? 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (ctx, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 2.h),
              child: ListView(
                controller: controller,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${error['feature']} / ${error['action']}',
                          style: GoogleFonts.dmSans(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: _deepBlue,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy details',
                        onPressed: () => _copyErrorDetails(error),
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  _detailLine('Severity', error['severity']),
                  _detailLine('Repeated in current view', '$repeatCount times'),
                  _detailLine('Created', _formatDate(error['created_at'])),
                  _detailLine('Platform', error['platform']),
                  _detailLine(
                    'User',
                    user == null
                        ? error['user_id']
                        : '${user['full_name'] ?? 'Unnamed'} (${user['email'] ?? error['user_id']})',
                  ),
                  SizedBox(height: 1.5.h),
                  _detailBlock('Message', error['message']),
                  _detailBlock('Context', _prettyJson(error['context'])),
                  _detailBlock('Stack trace', error['stack_trace']),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailLine(String label, dynamic value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 0.7.h),
      child: Text(
        '$label: ${value?.toString().isNotEmpty == true ? value : '-'}',
        style: GoogleFonts.dmSans(fontSize: 11.sp, color: Colors.black87),
      ),
    );
  }

  Widget _detailBlock(String label, dynamic value) {
    final text = value?.toString();
    if (text == null || text.trim().isEmpty || text == 'null') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: _deepBlue,
            ),
          ),
          SizedBox(height: 0.5.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              text,
              style: GoogleFonts.dmSans(fontSize: 10.sp, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      appBar: AppBar(
        title: Text(
          'Admin Diagnostics',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
        ),
        backgroundColor: _deepBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isAdmin && !_isLoading ? _loadDashboard : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _checkingAdmin
          ? const Center(child: CircularProgressIndicator())
          : !_isAdmin
          ? _buildAccessDenied()
          : Theme(
              data: ThemeData.light(useMaterial3: true).copyWith(
                scaffoldBackgroundColor: _screenBackground,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: _deepBlue,
                  brightness: Brightness.light,
                  surface: Colors.white,
                ),
                textTheme: ThemeData.light().textTheme.apply(
                  bodyColor: _bodyText,
                  displayColor: _bodyText,
                ),
              ),
              child: _buildDiagnosticsList(),
            ),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Text(
          'Admin access required',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: _deepBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticsList() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: EdgeInsets.all(4.w),
        children: [
          _buildHealthPanel(),
          SizedBox(height: 1.5.h),
          _buildLiveRidePanel(),
          SizedBox(height: 1.5.h),
          _buildNotificationPanel(),
          SizedBox(height: 1.5.h),
          _buildStravaPanel(),
          SizedBox(height: 1.5.h),
          _buildAiReviewPanel(),
          SizedBox(height: 1.5.h),
          _buildSummaryRow(),
          SizedBox(height: 1.5.h),
          _buildFilters(),
          SizedBox(height: 1.5.h),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_visibleErrors.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 14.h),
              child: Center(
                child: Text(
                  'No diagnostics found',
                  style: GoogleFonts.dmSans(
                    fontSize: 14.sp,
                    color: Colors.black54,
                  ),
                ),
              ),
            )
          else
            ..._visibleErrors.map(_buildErrorCard),
        ],
      ),
    );
  }

  Widget _buildAiReviewPanel() {
    final review = _aiReview;
    final overview = review?['overview']?.toString();
    final blockers = _stringList(review?['releaseBlockers']);
    final rootCauses = _stringList(review?['likelyRootCauses']);
    final nextActions = _stringList(review?['recommendedNextActions']);
    final privacyNotes = _stringList(review?['privacyNotes']);
    final generatedAt = review?['generatedAt'];
    final aiWarning = review?['aiWarning']?.toString();
    final aiProvider = review?['aiProvider']?.toString();

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _deepBlue.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: _deepBlue),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Read-only AI Review',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: _deepBlue,
                  ),
                ),
              ),
              TextButton(
                onPressed: _isAiReviewLoading ? null : _loadAiReview,
                child: Text(_isAiReviewLoading ? 'Reviewing' : 'Review'),
              ),
            ],
          ),
          SizedBox(height: 0.6.h),
          Text(
            'Summarizes recent diagnostics without changing app data, SQL, or code.',
            style: GoogleFonts.dmSans(fontSize: 10.sp, color: Colors.black54),
          ),
          if (_isAiReviewLoading) ...[
            SizedBox(height: 1.2.h),
            const LinearProgressIndicator(),
          ],
          if (_aiReviewError != null) ...[
            SizedBox(height: 1.h),
            Text(
              _aiReviewError!,
              style: GoogleFonts.dmSans(fontSize: 10.sp, color: _orange),
            ),
          ],
          if (overview != null && overview.trim().isNotEmpty) ...[
            SizedBox(height: 1.2.h),
            Text(
              overview,
              style: GoogleFonts.dmSans(
                fontSize: 10.5.sp,
                color: _bodyText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (aiProvider == 'fallback' &&
              aiWarning != null &&
              aiWarning.trim().isNotEmpty) ...[
            SizedBox(height: 1.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFB7791F).withValues(alpha: 0.22),
                ),
              ),
              child: Text(
                aiWarning,
                style: GoogleFonts.dmSans(
                  fontSize: 9.5.sp,
                  color: const Color(0xFF8A5A00),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (generatedAt != null) ...[
            SizedBox(height: 0.5.h),
            Text(
              'Generated: ${_formatDate(generatedAt)}',
              style: GoogleFonts.dmSans(fontSize: 9.sp, color: Colors.black45),
            ),
          ],
          _aiReviewSection('Release blockers', blockers, _orange),
          _aiReviewSection('Likely root causes', rootCauses, _deepBlue),
          _aiReviewSection('Recommended next actions', nextActions, _green),
          _aiReviewSection(
            'Privacy/security notes',
            privacyNotes,
            const Color(0xFFB7791F),
          ),
        ],
      ),
    );
  }

  Widget _aiReviewSection(String title, List<String> items, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: 1.2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: 0.5.h),
          ...items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 0.45.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 0.45.h),
                    child: Icon(Icons.circle, size: 5, color: color),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.dmSans(
                        fontSize: 9.8.sp,
                        color: _bodyText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthPanel() {
    final health = _matchingHealth;
    final missingRider = (health?['missingRiderMatches'] as List?)?.length ?? 0;
    final missingLegacy =
        (health?['missingLegacyDirections'] as List?)?.length ?? 0;
    final healthy = health != null && missingRider == 0 && missingLegacy == 0;

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: healthy
              ? _green.withValues(alpha: 0.28)
              : _orange.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                healthy ? Icons.verified_rounded : Icons.troubleshoot_rounded,
                color: healthy ? _green : _orange,
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Matching Health',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: _deepBlue,
                  ),
                ),
              ),
              TextButton(
                onPressed: _loadMatchingHealth,
                child: const Text('Check'),
              ),
            ],
          ),
          if (_matchingHealthError != null) ...[
            SizedBox(height: 0.8.h),
            Text(
              'Could not check matching health. Run the admin matching SQL policies if this is a permissions error.',
              style: GoogleFonts.dmSans(fontSize: 10.sp, color: _orange),
            ),
          ] else if (health == null) ...[
            SizedBox(height: 0.8.h),
            Text(
              'Pull to refresh or tap Check.',
              style: GoogleFonts.dmSans(fontSize: 10.sp, color: Colors.black54),
            ),
          ] else ...[
            SizedBox(height: 1.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: [
                _metricChip('Right swipes', health['rightSwipeCount']),
                _metricChip('Mutual pairs', health['mutualSwipePairs']),
                _metricChip('Rider matches', health['riderMatchPairs']),
                _metricChip('Legacy rows', health['legacyMatchRows']),
              ],
            ),
            if (missingRider > 0 || missingLegacy > 0) ...[
              SizedBox(height: 1.h),
              Text(
                '$missingRider mutual pairs missing rider_matches. $missingLegacy legacy match directions missing.',
                style: GoogleFonts.dmSans(
                  fontSize: 10.5.sp,
                  color: _orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _metricChip(String label, dynamic value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: ${value ?? 0}',
        style: GoogleFonts.dmSans(
          fontSize: 10.sp,
          color: _deepBlue,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildLiveRidePanel() {
    final health = _liveRideHealth;
    final staleSessions = _asInt(health?['staleActiveSessions']);
    final failedJoins = _asInt(health?['failedJoinEvents']);
    final routeIssues = _asInt(health?['routeIssues']);
    final locationIssues = _asInt(health?['locationIssues']);
    final voiceIssues = _asInt(health?['voiceIssues']);
    final errorEvents = _asInt(health?['errorEvents7d']);
    final healthy =
        health != null &&
        staleSessions == 0 &&
        failedJoins == 0 &&
        routeIssues == 0 &&
        locationIssues == 0 &&
        voiceIssues == 0;
    final recentSessions = health?['recentSessions'] is List
        ? List<Map<String, dynamic>>.from(health!['recentSessions'] as List)
        : <Map<String, dynamic>>[];
    final recentErrors = health?['recentErrors'] is List
        ? List<Map<String, dynamic>>.from(health!['recentErrors'] as List)
        : <Map<String, dynamic>>[];

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: healthy
              ? _green.withValues(alpha: 0.28)
              : _orange.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                healthy ? Icons.route_rounded : Icons.warning_amber_rounded,
                color: healthy ? _green : _orange,
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Live Ride Health',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: _deepBlue,
                  ),
                ),
              ),
              TextButton(
                onPressed: _loadOperationalHealth,
                child: const Text('Check'),
              ),
            ],
          ),
          if (_liveRideHealthError != null) ...[
            SizedBox(height: 0.8.h),
            Text(
              'Could not load live ride diagnostics: $_liveRideHealthError',
              style: GoogleFonts.dmSans(fontSize: 10.sp, color: _orange),
            ),
          ] else if (health == null) ...[
            SizedBox(height: 0.8.h),
            Text(
              'Pull to refresh or tap Check.',
              style: GoogleFonts.dmSans(fontSize: 10.sp, color: Colors.black54),
            ),
          ] else ...[
            SizedBox(height: 1.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: [
                _metricChip('Sessions 30d', health['sessions30d']),
                _metricChip('Active', health['activeSessions']),
                _metricChip('Stale active', staleSessions),
                _metricChip('Participants', health['activeParticipants']),
                _metricChip(
                  'Sharing location',
                  health['locationSharingParticipants'],
                ),
                _metricChip(
                  'Sessions with GPS',
                  health['sessionsWithLocations'],
                ),
                _metricChip('Failed joins', failedJoins),
                _metricChip('Route issues', routeIssues),
                _metricChip('Location issues', locationIssues),
                _metricChip('Voice issues', voiceIssues),
                _metricChip('Errors 7d', errorEvents),
              ],
            ),
            if (!healthy) ...[
              SizedBox(height: 1.h),
              Text(
                'Needs attention: $staleSessions stale sessions, $failedJoins failed joins, $routeIssues route issues, $locationIssues location issues, $voiceIssues voice issues.',
                style: GoogleFonts.dmSans(
                  fontSize: 10.5.sp,
                  color: _orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (recentSessions.isNotEmpty) ...[
              SizedBox(height: 1.4.h),
              Text(
                'Recent sessions',
                style: GoogleFonts.dmSans(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: _deepBlue,
                ),
              ),
              SizedBox(height: 0.4.h),
              ...recentSessions.take(5).map(_buildLiveRideSessionRow),
            ],
            if (recentErrors.isNotEmpty) ...[
              SizedBox(height: 1.2.h),
              Text(
                'Latest live ride warning: ${recentErrors.first['action'] ?? 'unknown'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 10.sp,
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLiveRideSessionRow(Map<String, dynamic> row) {
    final isPastAutoStop = row['isPastAutoStop'] == true;
    final hasRoute = row['hasPlannedRoute'] == true;
    final status = row['status']?.toString() ?? 'unknown';
    final statusColor = isPastAutoStop
        ? _orange
        : status == 'active'
        ? _green
        : _deepBlue;
    final groupName = row['groupName']?.toString().trim().isNotEmpty == true
        ? row['groupName'].toString()
        : 'Unnamed ride';

    return Container(
      margin: EdgeInsets.only(top: 0.8.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w800,
                    color: _deepBlue,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isPastAutoStop ? 'STALE' : status.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 0.4.h),
          Text(
            'Route: ${hasRoute ? 'planned route available' : 'no planned route found'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 9.5.sp,
              color: hasRoute ? Colors.black87 : _orange,
              fontWeight: hasRoute ? FontWeight.w500 : FontWeight.w800,
            ),
          ),
          SizedBox(height: 0.3.h),
          Text(
            'Active riders: ${row['activeParticipants'] ?? 0}/${row['totalParticipants'] ?? 0}  |  Sharing: ${row['locationSharers'] ?? 0}  |  GPS riders: ${row['ridersWithLocation'] ?? 0}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(fontSize: 9.sp, color: Colors.black54),
          ),
          SizedBox(height: 0.3.h),
          Text(
            'Started: ${_formatDate(row['startedAt'])}  |  Last GPS: ${_formatDate(row['lastLocationAt']).isEmpty ? '-' : _formatDate(row['lastLocationAt'])}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(fontSize: 9.sp, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPanel() {
    final health = _notificationHealth;
    final staleUnread = _asInt(health?['staleUnread']);
    final missingRoute = _asInt(health?['missingRoute']);
    final invalidLiveRideTargets = _asInt(health?['invalidLiveRideTargets']);
    final errorEvents = _asInt(health?['errorEvents7d']);
    final healthy =
        health != null &&
        staleUnread == 0 &&
        missingRoute == 0 &&
        invalidLiveRideTargets == 0 &&
        errorEvents == 0;
    final recentNotifications = health?['recentNotifications'] is List
        ? List<Map<String, dynamic>>.from(
            health!['recentNotifications'] as List,
          )
        : <Map<String, dynamic>>[];
    final recentErrors = health?['recentErrors'] is List
        ? List<Map<String, dynamic>>.from(health!['recentErrors'] as List)
        : <Map<String, dynamic>>[];

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: healthy
              ? _green.withValues(alpha: 0.28)
              : _orange.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                healthy
                    ? Icons.notifications_active_rounded
                    : Icons.notification_important_rounded,
                color: healthy ? _green : _orange,
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Notification Health',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: _deepBlue,
                  ),
                ),
              ),
              TextButton(
                onPressed: _loadOperationalHealth,
                child: const Text('Check'),
              ),
            ],
          ),
          if (_notificationHealthError != null) ...[
            SizedBox(height: 0.8.h),
            Text(
              'Could not load notification diagnostics: $_notificationHealthError',
              style: GoogleFonts.dmSans(fontSize: 10.sp, color: _orange),
            ),
          ] else if (health == null) ...[
            SizedBox(height: 0.8.h),
            Text(
              'Pull to refresh or tap Check.',
              style: GoogleFonts.dmSans(fontSize: 10.sp, color: Colors.black54),
            ),
          ] else ...[
            SizedBox(height: 1.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: [
                _metricChip('Sent 30d', health['notifications30d']),
                _metricChip('Unread', health['unread']),
                _metricChip('Stale unread', staleUnread),
                _metricChip('Missing route', missingRoute),
                _metricChip('Bad live ride target', invalidLiveRideTargets),
                _metricChip('Errors 7d', errorEvents),
              ],
            ),
            if (!healthy) ...[
              SizedBox(height: 1.h),
              Text(
                'Needs attention: $staleUnread stale unread, $missingRoute missing routes, $invalidLiveRideTargets bad live ride targets, $errorEvents recent failures.',
                style: GoogleFonts.dmSans(
                  fontSize: 10.5.sp,
                  color: _orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (recentNotifications.isNotEmpty) ...[
              SizedBox(height: 1.4.h),
              Text(
                'Recent notifications',
                style: GoogleFonts.dmSans(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: _deepBlue,
                ),
              ),
              SizedBox(height: 0.4.h),
              ...recentNotifications.take(5).map(_buildNotificationRow),
            ],
            if (recentErrors.isNotEmpty) ...[
              SizedBox(height: 1.2.h),
              Text(
                'Latest notification warning: ${recentErrors.first['action'] ?? 'unknown'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 10.sp,
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationRow(Map<String, dynamic> row) {
    final isRead = row['isRead'] == true;
    final type = row['type']?.toString() ?? 'unknown';
    final hasRoute =
        row['actionRoute']?.toString().isNotEmpty == true ||
        row['referenceId']?.toString().isNotEmpty == true;
    final title = row['title']?.toString().trim().isNotEmpty == true
        ? row['title'].toString()
        : 'Untitled notification';
    final stateColor = !hasRoute
        ? _orange
        : isRead
        ? _deepBlue
        : _green;

    return Container(
      margin: EdgeInsets.only(top: 0.8.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w800,
                    color: _deepBlue,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  !hasRoute
                      ? 'NO ROUTE'
                      : isRead
                      ? 'READ'
                      : 'UNREAD',
                  style: GoogleFonts.dmSans(
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w800,
                    color: stateColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 0.4.h),
          Text(
            'Type: $type  |  Route: ${row['actionRoute'] ?? '-'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(fontSize: 9.5.sp, color: Colors.black87),
          ),
          SizedBox(height: 0.3.h),
          Text(
            'Created: ${_formatDate(row['createdAt'])}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(fontSize: 9.sp, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildStravaPanel() {
    final health = _stravaHealth;
    final connections = health?['connections'] is List
        ? List<Map<String, dynamic>>.from(health!['connections'] as List)
        : <Map<String, dynamic>>[];
    final expired = connections
        .where((row) => row['tokenState']?.toString() == 'expired')
        .length;
    final expiresSoon = connections
        .where((row) => row['tokenState']?.toString() == 'expires_soon')
        .length;
    final hasTokenIssue = expired > 0 || expiresSoon > 0;

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasTokenIssue
              ? _orange.withValues(alpha: 0.28)
              : _green.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasTokenIssue
                    ? Icons.link_off_rounded
                    : Icons.directions_bike_rounded,
                color: hasTokenIssue ? _orange : _green,
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Strava Connections',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: _deepBlue,
                  ),
                ),
              ),
              TextButton(
                onPressed: _loadStravaHealth,
                child: const Text('Check'),
              ),
            ],
          ),
          if (_stravaHealthError != null) ...[
            SizedBox(height: 0.8.h),
            Text(
              'Could not load Strava diagnostics: $_stravaHealthError',
              style: GoogleFonts.dmSans(fontSize: 10.sp, color: _orange),
            ),
          ] else if (health == null) ...[
            SizedBox(height: 0.8.h),
            Text(
              'Pull to refresh or tap Check.',
              style: GoogleFonts.dmSans(fontSize: 10.sp, color: Colors.black54),
            ),
          ] else ...[
            SizedBox(height: 1.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: [
                _metricChip('Connected', health['count'] ?? connections.length),
                _metricChip('Expired', expired),
                _metricChip('Expiring soon', expiresSoon),
              ],
            ),
            if (connections.isEmpty) ...[
              SizedBox(height: 1.h),
              Text(
                'No riders have connected Strava yet.',
                style: GoogleFonts.dmSans(
                  fontSize: 10.5.sp,
                  color: Colors.black54,
                ),
              ),
            ] else ...[
              SizedBox(height: 1.2.h),
              ...connections.take(5).map(_buildStravaConnectionRow),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStravaConnectionRow(Map<String, dynamic> row) {
    final tokenState = row['tokenState']?.toString() ?? 'unknown';
    final tokenColor = tokenState == 'valid'
        ? _green
        : tokenState == 'expires_soon'
        ? const Color(0xFFB7791F)
        : _orange;
    final riderName = row['userName']?.toString().trim().isNotEmpty == true
        ? row['userName'].toString()
        : row['userEmail']?.toString() ?? 'Unknown rider';
    final athleteName = row['athleteName']?.toString().trim().isNotEmpty == true
        ? row['athleteName'].toString()
        : row['athleteUsername']?.toString() ?? 'Unknown athlete';

    return Container(
      margin: EdgeInsets.only(top: 0.8.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  riderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w800,
                    color: _deepBlue,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokenColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tokenState.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w800,
                    color: tokenColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 0.4.h),
          Text(
            'Athlete: $athleteName (${row['athleteId'] ?? '-'})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(fontSize: 9.5.sp, color: Colors.black87),
          ),
          SizedBox(height: 0.3.h),
          Text(
            'Expires: ${_formatDate(row['expiresAt'])}  |  Last refresh: ${_formatDate(row['updatedAt'])}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(fontSize: 9.sp, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final errors = _uniqueErrors
        .where((e) => (e['severity'] ?? '').toString() == 'error')
        .length;
    final warnings = _uniqueErrors
        .where((e) => (e['severity'] ?? '').toString() == 'warning')
        .length;
    final topFeature = _featureCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            'Issues',
            _uniqueErrors.length.toString(),
            _deepBlue,
            selected: _selectedSeverity == 'all',
            onTap: () => _applySeverityFilter('all'),
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: _summaryCard(
            'Errors',
            errors.toString(),
            _orange,
            selected: _selectedSeverity == 'error',
            onTap: () => _applySeverityFilter('error'),
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: _summaryCard(
            'Warnings',
            warnings.toString(),
            const Color(0xFFB7791F),
            selected: _selectedSeverity == 'warning',
            onTap: () => _applySeverityFilter('warning'),
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: _summaryCard(
            'Top',
            topFeature.isEmpty ? '-' : topFeature.first.key,
            _deepBlue,
            small: true,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    String label,
    String value,
    Color color, {
    bool small = false,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 9.sp,
                  color: selected ? color : Colors.black54,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              SizedBox(height: 0.4.h),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: small ? 9.5.sp : 14.sp,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applySeverityFilter(String severity) async {
    if (_selectedSeverity == severity) return;
    setState(() => _selectedSeverity = severity);
  }

  Widget _buildFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedFeature,
                dropdownColor: Colors.white,
                style: GoogleFonts.dmSans(color: _bodyText, fontSize: 10.sp),
                decoration: _filterDecoration('Feature'),
                items: _features
                    .map(
                      (feature) => DropdownMenuItem(
                        value: feature,
                        child: Text(
                          feature == 'all' ? 'All features' : feature,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 10.sp,
                            color: _bodyText,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _selectedFeature = value);
                },
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(_selectedSeverity),
                initialValue: _selectedSeverity,
                dropdownColor: Colors.white,
                style: GoogleFonts.dmSans(color: _bodyText, fontSize: 10.sp),
                decoration: _filterDecoration('Severity'),
                items: _severities
                    .map(
                      (severity) => DropdownMenuItem(
                        value: severity,
                        child: Text(
                          severity == 'all' ? 'All severities' : severity,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 10.sp,
                            color: _bodyText,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _selectedSeverity = value);
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        TextField(
          controller: _searchController,
          style: GoogleFonts.dmSans(color: _bodyText),
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: _filterDecoration('Search diagnostics').copyWith(
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
      ],
    );
  }

  InputDecoration _filterDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.dmSans(color: _deepBlue),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
      ),
    );
  }

  Widget _buildErrorCard(Map<String, dynamic> error) {
    final severity = (error['severity'] as String?) ?? 'error';
    final user = _profileFor(error);
    final repeatCount = _signatureCounts[_errorSignature(error)] ?? 1;

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      margin: EdgeInsets.only(bottom: 1.5.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showErrorDetails(error),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _severityColor(severity).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      severity.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                        color: _severityColor(severity),
                      ),
                    ),
                  ),
                  if (repeatCount > 1) ...[
                    SizedBox(width: 2.w),
                    _repeatBadge(repeatCount),
                  ],
                  const Spacer(),
                  Text(
                    _formatDate(error['created_at']),
                    style: GoogleFonts.dmSans(
                      fontSize: 9.sp,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              Text(
                '${error['feature']} / ${error['action']}',
                style: GoogleFonts.dmSans(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: _deepBlue,
                ),
              ),
              SizedBox(height: 0.4.h),
              if (user != null)
                Text(
                  '${user['full_name'] ?? 'Unnamed'} â€¢ ${user['email'] ?? error['user_id']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 9.5.sp,
                    color: Colors.black54,
                  ),
                ),
              SizedBox(height: 0.5.h),
              Text(
                (error['message'] ?? '').toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(fontSize: 10.sp, color: _bodyText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _repeatBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _deepBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'x$count',
        style: GoogleFonts.dmSans(
          fontSize: 9.sp,
          fontWeight: FontWeight.w800,
          color: _deepBlue,
        ),
      ),
    );
  }
}
