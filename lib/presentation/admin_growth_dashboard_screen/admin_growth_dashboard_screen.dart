import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminGrowthDashboardScreen extends StatefulWidget {
  const AdminGrowthDashboardScreen({super.key});

  @override
  State<AdminGrowthDashboardScreen> createState() =>
      _AdminGrowthDashboardScreenState();
}

class _AdminGrowthDashboardScreenState
    extends State<AdminGrowthDashboardScreen> {
  static const Color _deepBlue = Color(0xFF1B365D);
  static const Color _orange = Color(0xFFE85A4F);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _gold = Color(0xFFB7791F);

  bool _isLoading = true;
  String _period = '7d';
  String? _error;
  Map<String, dynamic>? _dashboard;

  Map<String, dynamic> get _totals =>
      Map<String, dynamic>.from(_dashboard?['totals'] as Map? ?? {});

  Map<String, dynamic> get _periodMetrics {
    final periods = _dashboard?['periods'];
    if (periods is! Map) return {};
    return Map<String, dynamic>.from(periods[_period] as Map? ?? {});
  }

  Map<String, dynamic> get _onboardingMetrics =>
      Map<String, dynamic>.from(_periodMetrics['onboarding'] as Map? ?? {});

  Map<String, dynamic> get _activationMetrics =>
      Map<String, dynamic>.from(_periodMetrics['activation'] as Map? ?? {});

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'admin-growth-dashboard',
      );
      final data = response.data;
      if (data is! Map) throw Exception('Invalid dashboard response');

      if (!mounted) return;
      setState(() {
        _dashboard = Map<String, dynamic>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Growth & Revenue',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
        ),
        backgroundColor: _deepBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: EdgeInsets.all(4.w),
                children: [
                  _buildPeriodSelector(),
                  SizedBox(height: 2.h),
                  _buildHeadlineMetrics(),
                  SizedBox(height: 2.h),
                  _buildSection(
                    title: 'Growth & Activation',
                    icon: Icons.trending_up_rounded,
                    children: [
                      _metricRow(
                        'New riders',
                        _period == '7d'
                            ? _totals['newUsers7d']
                            : _totals['newUsers30d'],
                        note: 'Accounts created during this period',
                      ),
                      _metricRow(
                        'Active riders',
                        _periodMetrics['activeUsers'],
                        note: 'Riders generating tracked events',
                      ),
                      _metricRow(
                        'Profiles created',
                        _periodMetrics['profileCreated'],
                      ),
                      _metricRow(
                        'Profile completion',
                        _formatPercent(_totals['profileCompletionRate']),
                        note:
                            '${_totals['completeProfiles'] ?? 0} of ${_totals['users'] ?? 0} riders',
                      ),
                    ],
                  ),
                  SizedBox(height: 1.5.h),
                  _buildOnboardingSection(),
                  SizedBox(height: 1.5.h),
                  _buildActivationSection(),
                  SizedBox(height: 1.5.h),
                  _buildSection(
                    title: 'Matching & Engagement',
                    icon: Icons.people_alt_rounded,
                    children: [
                      _metricRow('Right swipes', _periodMetrics['rightSwipes']),
                      _metricRow('Matches', _periodMetrics['matchRows']),
                      _metricRow(
                        'Right swipe to match',
                        _formatPercent(_periodMetrics['rightSwipeToMatchRate']),
                      ),
                      _metricRow(
                        'Messages sent',
                        _periodMetrics['messageRows'],
                      ),
                      _metricRow(
                        'Ride groups created',
                        _periodMetrics['rideGroupsCreated'],
                      ),
                    ],
                  ),
                  SizedBox(height: 1.5.h),
                  _buildSection(
                    title: 'Premium Funnel',
                    icon: Icons.workspace_premium_rounded,
                    accent: _gold,
                    children: [
                      _metricRow(
                        'Premium screen views',
                        _periodMetrics['premiumViews'],
                      ),
                      _metricRow(
                        'Subscribe starts',
                        _periodMetrics['premiumSubscribeStarts'],
                      ),
                      _metricRow(
                        'Premium conversions',
                        _periodMetrics['premiumConversions'],
                        note: 'Includes beta unlocks and store activations',
                      ),
                      _metricRow(
                        'View to subscribe',
                        _formatPercent(
                          _periodMetrics['premiumViewToStartRate'],
                        ),
                      ),
                      _metricRow(
                        'Subscribe to conversion',
                        _formatPercent(
                          _periodMetrics['premiumStartToConversionRate'],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.5.h),
                  _buildSection(
                    title: 'Adoption',
                    icon: Icons.extension_rounded,
                    accent: _green,
                    children: [
                      _metricRow(
                        'Current premium accounts',
                        _totals['premiumUsers'],
                        note:
                            '${_formatPercent(_totals['premiumAccountRate'])} of riders',
                      ),
                      _metricRow(
                        'Strava connections',
                        _totals['stravaConnections'] ?? '-',
                      ),
                    ],
                  ),
                  SizedBox(height: 1.5.h),
                  _buildRevenueNote(),
                  SizedBox(height: 3.h),
                ],
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42, color: _orange),
            SizedBox(height: 1.5.h),
            Text(
              'Could not load growth metrics',
              style: GoogleFonts.dmSans(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: _deepBlue,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Confirm the admin-growth-dashboard Supabase function is deployed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 11.sp),
            ),
            SizedBox(height: 2.h),
            FilledButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: '7d', label: Text('Last 7 days')),
        ButtonSegment(value: '30d', label: Text('Last 30 days')),
      ],
      selected: {_period},
      onSelectionChanged: (selection) {
        setState(() => _period = selection.first);
      },
    );
  }

  Widget _buildHeadlineMetrics() {
    return Row(
      children: [
        Expanded(
          child: _headlineCard(
            'Riders',
            _totals['users'],
            Icons.person_rounded,
            _deepBlue,
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: _headlineCard(
            'Active',
            _periodMetrics['activeUsers'],
            Icons.bolt_rounded,
            _green,
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: _headlineCard(
            'Premium',
            _totals['premiumUsers'],
            Icons.workspace_premium_rounded,
            _gold,
          ),
        ),
      ],
    );
  }

  Widget _headlineCard(
    String label,
    dynamic value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(height: 1.h),
          Text(
            '${value ?? 0}',
            style: GoogleFonts.dmSans(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 9.5.sp, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color accent = _deepBlue,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                Icon(icon, size: 22, color: accent),
                SizedBox(width: 2.w),
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: _deepBlue,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildOnboardingSection() {
    final weakestStep = Map<String, dynamic>.from(
      _onboardingMetrics['weakestStep'] as Map? ?? {},
    );
    final steps = _onboardingMetrics['steps'] is List
        ? List<Map<String, dynamic>>.from(_onboardingMetrics['steps'] as List)
        : <Map<String, dynamic>>[];

    return _buildSection(
      title: 'Onboarding Funnel',
      icon: Icons.route_rounded,
      accent: _orange,
      children: [
        _metricRow(
          'Registrations completed',
          _onboardingMetrics['registrationCompleted'],
        ),
        _metricRow('Profile setup started', _onboardingMetrics['setupStarted']),
        _metricRow('Profiles completed', _onboardingMetrics['profileCreated']),
        _metricRow(
          'Registration to profile',
          _formatPercent(_onboardingMetrics['registrationToProfileRate']),
        ),
        _metricRow(
          'Setup completion',
          _formatPercent(_onboardingMetrics['setupStartToProfileRate']),
        ),
        _metricRow(
          'Skipped setup',
          _onboardingMetrics['skipped'],
          note: 'Skip rate: ${_formatPercent(_onboardingMetrics['skipRate'])}',
        ),
        if (weakestStep.isNotEmpty)
          _metricRow(
            'Weakest step',
            weakestStep['stepName'] ?? '-',
            note:
                '${weakestStep['dropOffUsers'] ?? 0} rider(s) viewed but did not continue',
          ),
        if (steps.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 0.5.h, 4.w, 1.25.h),
            child: Column(
              children: steps.take(9).map(_buildOnboardingStepRow).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildOnboardingStepRow(Map<String, dynamic> step) {
    final viewed = step['viewedUsers'] ?? 0;
    final completed = step['completedUsers'] ?? 0;
    final rate = _formatPercent(step['completionRate']);

    return Container(
      margin: EdgeInsets.only(top: 0.8.h),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${step['stepNumber'] ?? '-'} - ${step['stepName'] ?? 'Step'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 9.8.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(width: 2.w),
          Text(
            '$completed/$viewed - $rate',
            style: GoogleFonts.dmSans(
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w800,
              color: _deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivationSection() {
    final weakestMoment = Map<String, dynamic>.from(
      _activationMetrics['weakestMoment'] as Map? ?? {},
    );
    final strongestMoment = Map<String, dynamic>.from(
      _activationMetrics['strongestMoment'] as Map? ?? {},
    );

    return _buildSection(
      title: 'Activation & Retention',
      icon: Icons.insights_rounded,
      accent: _green,
      children: [
        _metricRow(
          'Activated riders',
          _activationMetrics['activatedUsers'],
          note: 'Profile-complete riders who reached a tracked value moment',
        ),
        _metricRow(
          'Activation rate',
          _formatPercent(_activationMetrics['activationRate']),
        ),
        _metricRow(
          'Returning riders',
          _activationMetrics['returningUsers'],
          note: 'Active on at least two different days in this period',
        ),
        _metricRow(
          'Multi-day active rate',
          _formatPercent(_activationMetrics['multiDayActiveRate']),
        ),
        _metricRow(
          'New rider activation',
          _formatPercent(_activationMetrics['newUserValueRate']),
          note:
              '${_activationMetrics['newValueUsers'] ?? 0} new rider(s) reached a value moment',
        ),
        _metricRow('First swipe riders', _activationMetrics['firstSwipeUsers']),
        _metricRow('First match riders', _activationMetrics['firstMatchUsers']),
        _metricRow(
          'First message riders',
          _activationMetrics['firstMessageUsers'],
        ),
        _metricRow(
          'Ride group creators',
          _activationMetrics['rideGroupCreators'],
        ),
        _metricRow(
          'Live ride starters',
          _activationMetrics['liveRideStarters'],
        ),
        _metricRow('Premium viewers', _activationMetrics['premiumViewers']),
        if (strongestMoment.isNotEmpty)
          _metricRow(
            'Strongest value moment',
            strongestMoment['label'] ?? '-',
            note: '${strongestMoment['users'] ?? 0} rider(s)',
          ),
        if (weakestMoment.isNotEmpty)
          _metricRow(
            'Weakest value moment',
            weakestMoment['label'] ?? '-',
            note: '${weakestMoment['users'] ?? 0} rider(s)',
          ),
      ],
    );
  }

  Widget _metricRow(String label, dynamic value, {String? note}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.25.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                if (note != null)
                  Text(
                    note,
                    style: GoogleFonts.dmSans(
                      fontSize: 8.8.sp,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 3.w),
          Text(
            '${value ?? 0}',
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              color: _deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueNote() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gold.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _gold),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              'RevenueCat remains the source of truth for actual revenue, renewals, refunds, and churn. This dashboard measures the in-app conversion funnel.',
              style: GoogleFonts.dmSans(
                fontSize: 10.sp,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPercent(dynamic value) {
    if (value == null) return '-';
    return '${value.toString()}%';
  }
}
