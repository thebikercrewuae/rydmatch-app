import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyAlertScreen extends StatefulWidget {
  const EmergencyAlertScreen({super.key});

  @override
  State<EmergencyAlertScreen> createState() => _EmergencyAlertScreenState();
}

class _EmergencyAlertScreenState extends State<EmergencyAlertScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  Map<String, dynamic>? _alert;
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _acknowledging = false;
  bool _acknowledged = false;
  String? _error;

  String? get _alertId {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) return args['alert_id'] as String?;
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _alert == null && _error == null) {
      unawaited(_loadAlert());
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadAlert() async {
    final alertId = _alertId;
    final userId = _client.auth.currentUser?.id;
    if (alertId == null || userId == null) {
      setState(() {
        _loading = false;
        _error = 'This emergency alert is unavailable.';
      });
      return;
    }

    try {
      final alert = await _client
          .from('emergency_alerts')
          .select()
          .eq('id', alertId)
          .single();
      final recipient = await _client
          .from('emergency_alert_recipients')
          .select('acknowledged_at')
          .eq('alert_id', alertId)
          .eq('recipient_id', userId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _alert = Map<String, dynamic>.from(alert);
        _acknowledged = recipient?['acknowledged_at'] != null;
        _loading = false;
      });
      _subscribe(alertId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this emergency alert.';
      });
    }
  }

  void _subscribe(String alertId) {
    _channel?.unsubscribe();
    _channel = _client
        .channel('emergency-alert:$alertId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'emergency_alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: alertId,
          ),
          callback: (payload) {
            if (!mounted) return;
            setState(
              () => _alert = Map<String, dynamic>.from(payload.newRecord),
            );
          },
        )
        .subscribe();
  }

  Future<void> _acknowledge() async {
    final alertId = _alertId;
    final userId = _client.auth.currentUser?.id;
    if (alertId == null || userId == null) return;
    setState(() => _acknowledging = true);
    try {
      await _client
          .from('emergency_alert_recipients')
          .update({'acknowledged_at': DateTime.now().toUtc().toIso8601String()})
          .eq('alert_id', alertId)
          .eq('recipient_id', userId);
      if (!mounted) return;
      setState(() {
        _acknowledging = false;
        _acknowledged = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _acknowledging = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not acknowledge the alert.')),
      );
    }
  }

  Future<void> _navigate() async {
    final latitude = _alert?['latitude'];
    final longitude = _alert?['longitude'];
    if (latitude == null || longitude == null) return;
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _call() async {
    final phone = (_alert?['phone_number'] as String?)?.trim();
    if (phone == null || phone.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  @override
  Widget build(BuildContext context) {
    final alert = _alert;
    final status = alert?['status'] as String? ?? 'active';
    final isTest = alert?['is_test'] as bool? ?? false;
    final isActive = status == 'active';
    final phone = (alert?['phone_number'] as String?)?.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: isTest
            ? const Color(0xFFB7791F)
            : const Color(0xFFB3261E),
        foregroundColor: Colors.white,
        title: Text(
          isTest ? 'Test Emergency Alert' : 'Emergency SOS',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: GoogleFonts.dmSans()))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Icon(
                  isActive
                      ? Icons.emergency_rounded
                      : Icons.check_circle_rounded,
                  color: isActive
                      ? const Color(0xFFB3261E)
                      : const Color(0xFF2E7D32),
                  size: 72,
                ),
                const SizedBox(height: 12),
                Text(
                  isActive
                      ? '${alert?['rider_name']} needs assistance'
                      : 'This alert has been ${status == 'resolved' ? 'resolved' : 'cancelled'}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF17365D),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                _InfoCard(
                  icon: Icons.location_on_rounded,
                  title: 'Latest location',
                  body:
                      '${alert?['latitude']}, ${alert?['longitude']}\nAccuracy: ${alert?['accuracy'] == null ? 'Unknown' : '${alert?['accuracy']} m'}',
                ),
                const SizedBox(height: 16),
                if (isActive) ...[
                  FilledButton.icon(
                    onPressed: _acknowledged || _acknowledging
                        ? null
                        : _acknowledge,
                    icon: _acknowledging
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.volunteer_activism_rounded),
                    label: Text(
                      _acknowledged
                          ? 'Acknowledged'
                          : 'Acknowledge and respond',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB3261E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _navigate,
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Navigate to rider'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  if (phone != null && phone.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _call,
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('Call rider'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                const _InfoCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Safety note',
                  body:
                      'RydMatch emergency alerts are not a replacement for contacting local emergency services. Call local emergency services when required.',
                ),
              ],
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9E1EA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF17365D)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF17365D),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF44566C),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
