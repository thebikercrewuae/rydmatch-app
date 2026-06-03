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
  Map<String, dynamic>? _stravaHealth;
  String? _stravaHealthError;

  final List<String> _features = const [
    'all',
    'matching',
    'profile_media',
    'discovery',
    'matches',
    'ride_groups',
    'route_planner',
    'premium',
    'strava',
    'emergency_sos',
    'live_ride',
    'live_ride_voice',
  ];

  final List<String> _severities = const ['all', 'error', 'warning', 'info'];

  List<Map<String, dynamic>> get _visibleErrors {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _errors;

    return _errors.where((error) {
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
    for (final error in _errors) {
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
      _loadStravaHealth(),
    ]);
  }

  Future<void> _loadErrors() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final query = Supabase.instance.client
          .from('app_errors')
          .select(
            'id, user_id, feature, action, severity, message, stack_trace, context, platform, is_debug, created_at',
          );

      dynamic filteredQuery = query;
      if (_selectedFeature != 'all') {
        filteredQuery = filteredQuery.eq('feature', _selectedFeature);
      }
      if (_selectedSeverity != 'all') {
        filteredQuery = filteredQuery.eq('severity', _selectedSeverity);
      }

      final data = await filteredQuery
          .order('created_at', ascending: false)
          .limit(150);

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
          : _buildDiagnosticsList(),
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
          _buildStravaPanel(),
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
              'Could not load Strava diagnostics. Confirm strava-auth is deployed and Supabase secrets are set.',
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
    final errors = _errors
        .where((e) => (e['severity'] ?? '').toString() == 'error')
        .length;
    final warnings = _errors
        .where((e) => (e['severity'] ?? '').toString() == 'warning')
        .length;
    final topFeature = _featureCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        Expanded(
          child: _summaryCard('Loaded', _errors.length.toString(), _deepBlue),
        ),
        SizedBox(width: 2.w),
        Expanded(child: _summaryCard('Errors', errors.toString(), _orange)),
        SizedBox(width: 2.w),
        Expanded(
          child: _summaryCard(
            'Warnings',
            warnings.toString(),
            const Color(0xFFB7791F),
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
  }) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 9.sp, color: Colors.black54),
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
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedFeature,
                decoration: _filterDecoration('Feature'),
                items: _features
                    .map(
                      (feature) => DropdownMenuItem(
                        value: feature,
                        child: Text(
                          feature == 'all' ? 'All features' : feature,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(fontSize: 10.sp),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _selectedFeature = value);
                  await _loadErrors();
                },
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedSeverity,
                decoration: _filterDecoration('Severity'),
                items: _severities
                    .map(
                      (severity) => DropdownMenuItem(
                        value: severity,
                        child: Text(
                          severity == 'all' ? 'All severities' : severity,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(fontSize: 10.sp),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _selectedSeverity = value);
                  await _loadErrors();
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        TextField(
          controller: _searchController,
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
                  '${user['full_name'] ?? 'Unnamed'} • ${user['email'] ?? error['user_id']}',
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
                style: GoogleFonts.dmSans(fontSize: 10.sp),
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
