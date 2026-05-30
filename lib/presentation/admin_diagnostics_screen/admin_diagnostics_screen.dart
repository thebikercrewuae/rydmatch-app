import 'package:flutter/material.dart';
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

  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _isLoading = false;
  String _selectedFeature = 'all';
  List<Map<String, dynamic>> _errors = [];

  final List<String> _features = const [
    'all',
    'profile_media',
    'discovery',
    'matches',
    'ride_groups',
    'route_planner',
    'premium',
    'emergency_sos',
    'live_ride',
    'live_ride_voice',
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
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
        await _loadErrors();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _checkingAdmin = false;
      });
    }
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
      final data = _selectedFeature == 'all'
          ? await query.order('created_at', ascending: false).limit(100)
          : await query
                .eq('feature', _selectedFeature)
                .order('created_at', ascending: false)
                .limit(100);
      if (!mounted) return;

      setState(() {
        _errors = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load diagnostics.',
            style: GoogleFonts.dmSans(),
          ),
          backgroundColor: _orange,
        ),
      );
    }
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

  void _showErrorDetails(Map<String, dynamic> error) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.92,
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
                  Text(
                    '${error['feature']} / ${error['action']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: _deepBlue,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  _detailLine('Severity', error['severity']),
                  _detailLine('Created', _formatDate(error['created_at'])),
                  _detailLine('Platform', error['platform']),
                  _detailLine('User', error['user_id']),
                  SizedBox(height: 1.5.h),
                  _detailBlock('Message', error['message']),
                  _detailBlock('Context', error['context']),
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
            onPressed: _isAdmin && !_isLoading ? _loadErrors : null,
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
      onRefresh: _loadErrors,
      child: ListView(
        padding: EdgeInsets.all(4.w),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedFeature,
            decoration: InputDecoration(
              labelText: 'Feature',
              labelStyle: GoogleFonts.dmSans(color: _deepBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _features
                .map(
                  (feature) => DropdownMenuItem(
                    value: feature,
                    child: Text(
                      feature == 'all' ? 'All features' : feature,
                      style: GoogleFonts.dmSans(),
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
          SizedBox(height: 2.h),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errors.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 20.h),
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
            ..._errors.map(_buildErrorCard),
        ],
      ),
    );
  }

  Widget _buildErrorCard(Map<String, dynamic> error) {
    final severity = (error['severity'] as String?) ?? 'error';

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
}
