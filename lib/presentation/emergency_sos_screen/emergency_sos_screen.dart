import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/haptic_service.dart';
import '../../services/profile_service.dart';
import '../../services/analytics_service.dart';
import '../../services/diagnostics_service.dart';
import '../../services/live_ride_service.dart';
import './widgets/sos_button_widget.dart';
import './widgets/emergency_contact_widget.dart';
import './widgets/location_display_widget.dart';

class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen> {
  static const String _contactNameKey = 'sos_contact_name';
  static const String _contactPhoneKey = 'sos_contact_phone';

  bool _isCountingDown = false;
  bool _isSending = false;
  bool _smsSent = false;
  bool _isSendingTest = false;
  int _countdownValue = 3;
  Timer? _countdownTimer;
  Timer? _locationTimer;

  String _contactName = '';
  String _contactPhone = '';
  String _riderName = '';

  double? _latitude;
  double? _longitude;
  double? _accuracy;
  bool _locationLoading = true;

  DateTime? _sentAt;
  String? _activeAlertId;
  int _recipientCount = 0;

  String _normalizePhoneNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('+')) {
      return '+${trimmed.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
    }

    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00') && digits.length > 2) {
      return '+${digits.substring(2)}';
    }

    return digits;
  }

  String _functionErrorMessage(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final providerError =
          details['infobipError'] ?? details['twilioError'] ?? details['error'];
      final providerCode = details['twilioCode'];
      if (providerError != null) {
        return providerCode != null
            ? '$providerError (code: $providerCode)'
            : providerError.toString();
      }
    }
    return 'HTTP ${error.status}';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final profileData = await ProfileService.loadProfile();
    if (mounted) {
      setState(() {
        _contactName = prefs.getString(_contactNameKey) ?? '';
        _contactPhone = prefs.getString(_contactPhoneKey) ?? '';
        _riderName = profileData['riderName'] as String? ?? 'Rider';
      });
    }
    await _fetchLocation();
    _startLocationRefresh();
  }

  Future<void> _fetchLocation() async {
    if (mounted) setState(() => _locationLoading = true);

    if (kIsWeb) {
      // On web, Geolocator.isLocationServiceEnabled() throws — use browser geolocation
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (mounted) {
          setState(() {
            _latitude = position.latitude;
            _longitude = position.longitude;
            _accuracy = position.accuracy;
            _locationLoading = false;
          });
        }
        await _updateActiveAlertLocation(position);
      } catch (_) {
        if (mounted) setState(() => _locationLoading = false);
      }
      return;
    }

    // Mobile path — full permission flow
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationLoading = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) setState(() => _locationLoading = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _accuracy = position.accuracy;
          _locationLoading = false;
        });
      }
      await _updateActiveAlertLocation(position);
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _updateActiveAlertLocation(Position position) async {
    final alertId = _activeAlertId;
    if (alertId == null) return;
    try {
      await Supabase.instance.client
          .from('emergency_alerts')
          .update({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', alertId)
          .eq('status', 'active');
    } catch (error) {
      debugPrint('Emergency alert location update failed: $error');
    }
  }

  void _startLocationRefresh() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchLocation();
    });
  }

  void _startCountdown() {
    if (_latitude == null || _longitude == null) {
      _showNoLocationDialog();
      return;
    }
    HapticService.instance.heavy();
    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
      _smsSent = false;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownValue <= 1) {
        timer.cancel();
        _triggerSOS();
      } else {
        HapticService.instance.medium();
        setState(() => _countdownValue--);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    HapticService.instance.light();
    setState(() {
      _isCountingDown = false;
      _countdownValue = 3;
    });
  }

  Future<void> _openWhatsAppSos({
    required bool isTest,
    required double latitude,
    required double longitude,
  }) async {
    // Opens WhatsApp addressed to the rider's emergency contact with a
    // pre-filled SOS message and a live Google Maps link. The rider taps
    // send in WhatsApp. No emergency contact set -> silent no-op.
    final phone = _contactPhone.trim();
    if (phone.isEmpty) return;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final rider = _riderName.isNotEmpty ? _riderName : 'RydMatch Rider';
    final mapLink = 'https://maps.google.com/?q=$latitude,$longitude';
    final message = isTest
        ? '[TEST] $rider is testing their RydMatch emergency SOS. No action needed. Location: $mapLink'
        : 'EMERGENCY: $rider needs help. This is an emergency SOS from RydMatch. Live location: $mapLink';
    final url = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('WhatsApp SOS launch failed: $e');
    }
  }

  Future<void> _triggerSOS() async {
    if (_latitude == null || _longitude == null) {
      _showNoLocationDialog();
      return;
    }
    setState(() {
      _isCountingDown = false;
      _isSending = true;
    });
    HapticService.instance.heavy();
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'emergency-sos',
        body: {
          'riderName': _riderName.isNotEmpty ? _riderName : 'RydMatch Rider',
          'latitude': _latitude,
          'longitude': _longitude,
          'accuracy': _accuracy,
          'liveRideSessionId': LiveRideService.instance.currentSessionId,
          'isTest': false,
        },
      );

      // Check if the edge function returned an error in the response body
      final responseData = response.data;
      if (responseData is Map && responseData['error'] != null) {
        throw Exception(
          'Edge function error: ${responseData['error']} - ${responseData['details'] ?? ''}',
        );
      }

      await AnalyticsService.instance.logSosTriggered(
        latitude: _latitude,
        longitude: _longitude,
      );
      if (mounted) {
        final recipientCount = responseData is Map
            ? (responseData['recipientCount'] as num?)?.toInt() ?? 0
            : 0;
        setState(() {
          _isSending = false;
          _smsSent = true;
          _sentAt = DateTime.now();
          _activeAlertId = responseData is Map
              ? responseData['alertId'] as String?
              : null;
          _recipientCount = recipientCount;
        });
        HapticService.instance.heavy();
        if (recipientCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Alert created, but no active ride participants or matches could be notified. Contact emergency services directly.',
              ),
              backgroundColor: Color(0xFFB3261E),
            ),
          );
        }
      }
    } on FunctionException catch (e) {
      debugPrint('SOS FunctionException: ${e.status} - ${e.details}');
      await DiagnosticsService.instance.logError(
        feature: 'emergency_sos',
        action: 'send_sos_function_exception',
        error: e,
        context: {
          'status': e.status,
          'details': e.details?.toString(),
          'has_location': _latitude != null && _longitude != null,
        },
      );
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send SOS: ${_functionErrorMessage(e)}. Please call emergency services directly.',
              style: GoogleFonts.dmSans(fontSize: 12.sp),
            ),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('SOS send error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'emergency_sos',
        action: 'send_sos',
        error: e,
        context: {'has_location': _latitude != null && _longitude != null},
      );
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send SOS. Please call emergency services directly.',
              style: GoogleFonts.dmSans(fontSize: 12.sp),
            ),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // Always reach the personal emergency contact via WhatsApp, even if
      // the in-app rider network alert failed.
      await _openWhatsAppSos(
        isTest: false,
        latitude: _latitude!,
        longitude: _longitude!,
      );
    }
  }

  Future<void> _triggerTestSMS() async {
    setState(() => _isSendingTest = true);
    HapticService.instance.medium();

    // Use real GPS if available, otherwise use a safe fallback for test
    final lat = _latitude ?? 37.7749;
    final lng = _longitude ?? -122.4194;
    final usingFallback = _latitude == null || _longitude == null;

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'emergency-sos',
        body: {
          'riderName':
              '${_riderName.isNotEmpty ? _riderName : 'RydMatch Rider'} [TEST]',
          'latitude': lat,
          'longitude': lng,
          'accuracy': _accuracy,
          'isTest': true,
        },
      );

      final responseData = response.data;
      if (responseData is Map && responseData['error'] != null) {
        throw Exception(
          '${responseData['error']}${responseData['twilioError'] != null ? ' — ${responseData['twilioError']} (code: ${responseData['twilioCode']})' : ''}',
        );
      }

      if (mounted) {
        setState(() => _isSendingTest = false);
        HapticService.instance.heavy();
        _showTestResultDialog(
          success: true,
          message: usingFallback
              ? 'Test RydMatch alert delivered to your own notification inbox using fallback coordinates.'
              : 'Test RydMatch alert delivered to your own notification inbox with your live GPS location.',
          messageSid: responseData is Map
              ? responseData['alertId'] as String?
              : null,
        );
        // Also open WhatsApp to the emergency contact so the rider can
        // verify the full flow (clearly marked as a test).
        await _openWhatsAppSos(isTest: true, latitude: lat, longitude: lng);
      }
    } on FunctionException catch (e) {
      debugPrint('Test SMS FunctionException: ${e.status} - ${e.details}');
      await DiagnosticsService.instance.logError(
        feature: 'emergency_sos',
        action: 'send_test_sms_function_exception',
        error: e,
        context: {
          'status': e.status,
          'details': e.details?.toString(),
          'using_fallback_location': usingFallback,
        },
      );
      if (mounted) {
        setState(() => _isSendingTest = false);
        _showTestResultDialog(
          success: false,
          message: 'Failed to send test alert.\n\n${_functionErrorMessage(e)}',
        );
      }
    } catch (e) {
      debugPrint('Test SMS error: $e');
      await DiagnosticsService.instance.logError(
        feature: 'emergency_sos',
        action: 'send_test_sms',
        error: e,
        context: {'using_fallback_location': usingFallback},
      );
      if (mounted) {
        setState(() => _isSendingTest = false);
        _showTestResultDialog(
          success: false,
          message:
              'Failed to send test alert.\n\n${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  void _showTestResultDialog({
    required bool success,
    required String message,
    String? messageSid,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(
            color: success
                ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                : const Color(0xFFE53935).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: success
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFE53935),
              size: 22,
            ),
            SizedBox(width: 2.w),
            Text(
              success ? 'Test Alert Sent!' : 'Test Alert Failed',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11.sp,
                height: 1.5,
              ),
            ),
            if (messageSid != null) ...[
              SizedBox(height: 1.5.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white38,
                      size: 14,
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'Alert ID: $messageSid',
                        style: GoogleFonts.dmSans(
                          color: Colors.white38,
                          fontSize: 9.sp,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: success
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFE85A4F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showNoLocationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Location Unavailable',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'GPS location is required to send SOS. Please enable location services.',
          style: GoogleFonts.dmSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.dmSans()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _fetchLocation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85A4F),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditContactSheet() {
    final nameController = TextEditingController(text: _contactName);
    final phoneController = TextEditingController(text: _contactPhone);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 5.w,
          right: 5.w,
          top: 2.h,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 3.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 10.w,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Emergency Contact',
              style: GoogleFonts.dmSans(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 2.h),
            _buildTextField(
              nameController,
              'Contact Name',
              Icons.person_rounded,
            ),
            SizedBox(height: 1.5.h),
            _buildTextField(
              phoneController,
              'Phone Number (with country code)',
              Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 2.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                    _contactNameKey,
                    nameController.text.trim(),
                  );
                  final normalizedPhone = _normalizePhoneNumber(
                    phoneController.text,
                  );
                  await prefs.setString(_contactPhoneKey, normalizedPhone);
                  if (mounted) {
                    setState(() {
                      _contactName = nameController.text.trim();
                      _contactPhone = normalizedPhone;
                    });
                  }
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE85A4F),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 1.8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: Text(
                  'Save Contact',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13.sp),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 12.sp,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.5),
          size: 20,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color(0xFFE85A4F)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isSending
                      ? _buildSendingState()
                      : _smsSent
                      ? _buildSuccessState()
                      : _buildSosContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B365D), Color(0xFF0D1B2E), Color(0xFF1A1A2E)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Emergency SOS',
            style: GoogleFonts.dmSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSosContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: Column(
        children: [
          SizedBox(height: 2.h),
          Text(
            'Hold in emergencies only',
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: 4.h),
          SosButtonWidget(
            isCountingDown: _isCountingDown,
            countdownValue: _countdownValue,
            onPressed: _startCountdown,
            onCancel: _cancelCountdown,
          ),
          SizedBox(height: 5.h),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'EMERGENCY CONTACT',
              style: GoogleFonts.dmSans(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE53935).withValues(alpha: 0.8),
                letterSpacing: 1.2,
              ),
            ),
          ),
          SizedBox(height: 1.h),
          EmergencyContactWidget(
            contactName: _contactName,
            contactPhone: _contactPhone,
            onEdit: _showEditContactSheet,
          ),
          SizedBox(height: 2.h),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'LIVE LOCATION',
              style: GoogleFonts.dmSans(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4FC3F7).withValues(alpha: 0.8),
                letterSpacing: 1.2,
              ),
            ),
          ),
          SizedBox(height: 1.h),
          LocationDisplayWidget(
            latitude: _latitude,
            longitude: _longitude,
            accuracy: _accuracy,
            isLoading: _locationLoading,
          ),
          SizedBox(height: 3.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'Tapping SOS alerts your active live ride participants and RydMatch matches with your continuously updated GPS location after a 3-second countdown.\n\nRydMatch emergency alerts are not a replacement for contacting local emergency services.',
                    style: GoogleFonts.dmSans(
                      fontSize: 10.sp,
                      color: Colors.white.withValues(alpha: 0.45),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSendingTest ? null : _triggerTestSMS,
              icon: _isSendingTest
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFFE85A4F),
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(
                _isSendingTest ? 'Sending Test...' : 'Test RydMatch Alert',
                style: GoogleFonts.dmSans(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE85A4F),
                side: const BorderSide(color: Color(0xFFE85A4F), width: 1.2),
                padding: EdgeInsets.symmetric(vertical: 1.4.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
          SizedBox(height: 3.h),
          SizedBox(height: 3.h),
        ],
      ),
    );
  }

  Widget _buildSendingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: Color(0xFFE85A4F),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'Sending SOS Alert...',
            style: GoogleFonts.dmSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Alerting your RydMatch emergency network',
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveAlert() async {
    final alertId = _activeAlertId;
    if (alertId != null) {
      try {
        await Supabase.instance.client
            .from('emergency_alerts')
            .update({
              'status': 'resolved',
              'resolved_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', alertId);
      } catch (error) {
        debugPrint('Emergency alert resolution failed: $error');
      }
    }
    if (!mounted) return;
    setState(() {
      _smsSent = false;
      _sentAt = null;
      _activeAlertId = null;
      _recipientCount = 0;
    });
  }

  Widget _buildSuccessState() {
    final timeStr = _sentAt != null
        ? '${_sentAt!.hour.toString().padLeft(2, '0')}:${_sentAt!.minute.toString().padLeft(2, '0')}'
        : '';
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                border: Border.all(color: const Color(0xFF4CAF50), width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF4CAF50),
                size: 40,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'SOS Alert Sent!',
              style: GoogleFonts.dmSans(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Notified $_recipientCount RydMatch ${_recipientCount == 1 ? 'rider' : 'riders'}',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            if (timeStr.isNotEmpty) ...[
              SizedBox(height: 0.5.h),
              Text(
                'Sent at $timeStr',
                style: GoogleFonts.dmSans(
                  fontSize: 11.sp,
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.8),
                ),
              ),
            ],
            SizedBox(height: 3.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text(
                'Your live GPS location will continue updating while this screen remains open.',
                style: GoogleFonts.dmSans(
                  fontSize: 11.sp,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 3.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resolveAlert,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  padding: EdgeInsets.symmetric(vertical: 1.5.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: Text(
                  'Resolve Alert',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
