import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/haptic_service.dart';
import '../../services/profile_service.dart';
import '../../services/analytics_service.dart';
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

  bool _looksLikeInternationalPhone(String value) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value);
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
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  void _startLocationRefresh() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchLocation();
    });
  }

  void _startCountdown() {
    if (_contactPhone.isEmpty) {
      _showNoContactDialog();
      return;
    }
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

  Future<void> _triggerSOS() async {
    if (_latitude == null || _longitude == null) {
      _showNoLocationDialog();
      return;
    }
    final contactPhone = _normalizePhoneNumber(_contactPhone);
    if (!_looksLikeInternationalPhone(contactPhone)) {
      _showInvalidPhoneDialog();
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
          'contactPhone': contactPhone,
          'latitude': _latitude,
          'longitude': _longitude,
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
        setState(() {
          _isSending = false;
          _smsSent = true;
          _sentAt = DateTime.now();
        });
        HapticService.instance.heavy();
      }
    } on FunctionException catch (e) {
      debugPrint('SOS FunctionException: ${e.status} - ${e.details}');
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
    }
  }

  Future<void> _triggerTestSMS() async {
    if (_contactPhone.isEmpty) {
      _showNoContactDialog();
      return;
    }
    final contactPhone = _normalizePhoneNumber(_contactPhone);
    if (!_looksLikeInternationalPhone(contactPhone)) {
      _showInvalidPhoneDialog();
      return;
    }
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
          'contactPhone': contactPhone,
          'latitude': lat,
          'longitude': lng,
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
              ? 'Test SMS sent to $_contactName!\n\n⚠️ GPS was unavailable — San Francisco coordinates were used as a fallback.'
              : 'Test SMS sent to $_contactName with your live GPS location.',
          messageSid: responseData is Map
              ? responseData['messageSid'] as String?
              : null,
        );
      }
    } on FunctionException catch (e) {
      debugPrint('Test SMS FunctionException: ${e.status} - ${e.details}');
      if (mounted) {
        setState(() => _isSendingTest = false);
        _showTestResultDialog(
          success: false,
          message: 'Failed to send test SMS.\n\n${_functionErrorMessage(e)}',
        );
      }
    } catch (e) {
      debugPrint('Test SMS error: $e');
      if (mounted) {
        setState(() => _isSendingTest = false);
        _showTestResultDialog(
          success: false,
          message:
              'Failed to send test SMS.\n\n${e.toString().replaceFirst('Exception: ', '')}',
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
              success ? 'Test SMS Sent!' : 'Test SMS Failed',
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
                        'SID: $messageSid',
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

  void _showNoContactDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'No Emergency Contact',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Please set an emergency contact before using SOS.',
          style: GoogleFonts.dmSans(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showEditContactSheet();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85A4F),
            ),
            child: Text(
              'Add Contact',
              style: GoogleFonts.dmSans(color: Colors.white),
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

  void _showInvalidPhoneDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Invalid Phone Number',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Please enter the emergency contact number in international format, for example +971501234567.',
          style: GoogleFonts.dmSans(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showEditContactSheet();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85A4F),
            ),
            child: Text(
              'Edit Contact',
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
                  final normalizedPhone =
                      _normalizePhoneNumber(phoneController.text);
                  await prefs.setString(_contactPhoneKey, normalizedPhone);
                  if (mounted) {
                    setState(() {
                      _contactName = nameController.text.trim();
                      _contactPhone = normalizedPhone;
                    });
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
                    'Tapping SOS sends your name and GPS location to your emergency contact via SMS after a 3-second countdown.\n\nRydMatch emergency alerts are not a replacement for contacting local emergency services.',
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
                _isSendingTest ? 'Sending Test...' : 'Send Test SMS',
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
            'Contacting $_contactName',
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
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
              'SMS sent to $_contactName',
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
                'Your name and live GPS location were sent as a Google Maps link.',
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
                onPressed: () => setState(() {
                  _smsSent = false;
                  _sentAt = null;
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  padding: EdgeInsets.symmetric(vertical: 1.5.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: Text(
                  'Back to SOS Screen',
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
