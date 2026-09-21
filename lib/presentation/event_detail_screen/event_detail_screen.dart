import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/event_service.dart';
import '../../theme/app_theme.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final EventService _eventService = EventService.instance;
  bool _loading = true;
  EventInfo? _event;
  EventApplicationInfo? _myApp;
  String? _error;

  // Form fields
  final _phoneController = TextEditingController();
  final _bikeMakeController = TextEditingController();
  final _bikeModelController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  String _ridingExperience = '';
  bool _submitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _loadData(args['eventId'] as String);
    }
  }

  Future<void> _loadData(String eventId) async {
    setState(() { _loading = true; _error = null; });
    try {
      final event = await _eventService.getEvent(eventId);
      _event = event;
      if (event != null) {
        _myApp = await _eventService.getMyApplication(event.id);
      }
    } catch (e) {
      _error = 'Failed to load event';
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitApplication() async {
    if (_event == null) return;
    setState(() => _submitting = true);
    try {
      final success = await _eventService.applyForEvent(
        eventId: _event!.id,
        phone: _phoneController.text.trim(),
        bikeMake: _bikeMakeController.text.trim(),
        bikeModel: _bikeModelController.text.trim(),
        ridingExperience: _ridingExperience.isEmpty ? null : _ridingExperience,
        emergencyContactName: _emergencyNameController.text.trim(),
        emergencyContactPhone: _emergencyPhoneController.text.trim(),
      );
      if (success) {
        _myApp = await _eventService.getMyApplication(_event!.id);
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application submitted!'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit application'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _bikeMakeController.dispose();
    _bikeModelController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(backgroundColor: AppTheme.backgroundDark, foregroundColor: Colors.white, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.secondaryDark)),
      );
    }

    if (_event == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(backgroundColor: AppTheme.backgroundDark, foregroundColor: Colors.white, elevation: 0),
        body: Center(
          child: Text(_error ?? 'Event not found', style: const TextStyle(color: Colors.white54)),
        ),
      );
    }

    final isAuthed = Supabase.instance.client.auth.currentUser != null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(_event!.name, style: const TextStyle(fontSize: 16)),
        backgroundColor: AppTheme.backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            if (_event!.bannerUrl != null && _event!.bannerUrl!.isNotEmpty)
              Image.network(_event!.bannerUrl!, width: double.infinity, height: 180, fit: BoxFit.cover),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event info
                  Text(_event!.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  if (_event!.description != null) ...[
                    const SizedBox(height: 8),
                    Text(_event!.description!, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    children: [
                      if (_event!.locationName != null)
                        _buildInfoRow(Icons.location_on, _event!.locationName!),
                      _buildInfoRow(Icons.calendar_today,
                        '${_event!.startDate.day}/${_event!.startDate.month}/${_event!.startDate.year}'),
                      if (_event!.maxRiders != null)
                        _buildInfoRow(Icons.motorcycle, '${_event!.maxRiders} riders max'),
                    ],
                  ),

                  if (_event!.donationRequired) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Donation Required', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                          if (_event!.donationTarget != null)
                            Text('Target: ${_event!.donationTarget}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          if (_event!.donationInstructions != null)
                            Text(_event!.donationInstructions!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Channels button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/event-channels-screen',
                          arguments: {'eventId': _event!.id},
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Event Channels'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.secondaryDark,
                        side: BorderSide(color: AppTheme.secondaryDark.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Not logged in
                  if (!isAuthed)
                    _buildLoginPrompt()

                  // Has application - show status
                  else if (_myApp != null)
                    _buildApplicationStatus()

                  // No application - show form
                  else if (_event!.status == 'open')
                    _buildApplicationForm()

                  // Event not open
                  else
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('This event is not open for applications.', style: TextStyle(color: Colors.white54)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: Colors.white54),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
  }

  Widget _buildLoginPrompt() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          const Text('Sign in to apply for this event', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login-screen'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryDark),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationStatus() {
    final app = _myApp!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Application', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          // Status badge
          Row(
            children: [
              _buildStatusBadge(app.status),
              if (app.donationVerified)
                const Padding(padding: EdgeInsets.only(left: 8), child: _Badge(text: 'Donation Verified', color: Colors.green)),
              if (app.checkedIn)
                const Padding(padding: EdgeInsets.only(left: 8), child: _Badge(text: 'Checked In', color: Colors.green)),
              if (app.giftCollected)
                const Padding(padding: EdgeInsets.only(left: 8), child: _Badge(text: 'Gift Collected', color: Colors.green)),
            ],
          ),
          const SizedBox(height: 16),

          // Approved + donation required + not verified = upload section
          if (app.status == 'approved' && _event!.donationRequired && !app.donationVerified) ...[
            if (app.donationScreenshotUrl != null && app.donationScreenshotUrl!.isNotEmpty)
              const Text('Screenshot uploaded - waiting for verification', style: TextStyle(color: Colors.orange, fontSize: 14))
            else
              _buildDonationUpload(app.id),
          ],

          // Approved + (no donation required OR donation verified) = QR pass
          if (app.status == 'approved' && app.qrToken != null &&
              (!_event!.donationRequired || app.donationVerified)) ...[
            const Text('Your QR Pass', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: app.qrToken ?? '',
                  version: QrVersions.auto,
                  size: 220,
                  gapless: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Show this code at the event entrance', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ],

          // Pending
          if (app.status == 'pending')
            const Text('Your application is being reviewed. You will be notified when a decision is made.',
                style: TextStyle(color: Colors.white54, fontSize: 14)),

          // Rejected
          if (app.status == 'rejected')
            const Text('Unfortunately, your application was not approved for this event.',
                style: TextStyle(color: Colors.red, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDonationUpload(String appId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Upload Donation Proof', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Take a screenshot of your donation confirmation and upload it here.',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final picker = ImagePicker();
            final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
            if (image == null) return;
            final bytes = await image.readAsBytes();
            final prefix = 'data:image/jpeg;base64,';
            final base64Str = prefix + base64Encode(bytes);
            final success = await _eventService.uploadDonationScreenshot(appId, base64Str);
            if (success && mounted) {
              _myApp = await _eventService.getMyApplication(_event!.id);
              setState(() {});
              messenger.showSnackBar(
                const SnackBar(content: Text('Screenshot uploaded! Waiting for verification.'), backgroundColor: Colors.green),
              );
            } else if (mounted) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Upload failed. Please try again.'), backgroundColor: Colors.red),
              );
            }
          },
          icon: const Icon(Icons.upload),
          label: const Text('Choose Screenshot'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryDark),
        ),
      ],
    );
  }

  Widget _buildApplicationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Apply to Join', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildTextField(_phoneController, 'Phone Number', Icons.phone),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_bikeMakeController, 'Bike Make', Icons.motorcycle)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_bikeModelController, 'Bike Model', Icons.motorcycle)),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _ridingExperience.isEmpty ? null : _ridingExperience,
          decoration: _buildInputDecoration('Riding Experience'),
          dropdownColor: AppTheme.surfaceDark,
          style: const TextStyle(color: Colors.white),
          items: const [
            DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
            DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
            DropdownMenuItem(value: 'experienced', child: Text('Experienced')),
            DropdownMenuItem(value: 'expert', child: Text('Expert')),
          ],
          onChanged: (v) => setState(() => _ridingExperience = v ?? ''),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_emergencyNameController, 'Emergency Contact', Icons.person)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_emergencyPhoneController, 'Contact Phone', Icons.phone)),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submitApplication,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit Application'),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: AppTheme.surfaceDark,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: _buildInputDecoration(label),
    );
  }

  Widget _buildStatusBadge(String status) {
    final colors = {
      'approved': Colors.green,
      'rejected': Colors.red,
      'pending': Colors.orange,
      'waitlisted': Colors.blue,
    };
    final color = colors[status] ?? Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
      child: Text(status[0].toUpperCase() + status.substring(1),
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}