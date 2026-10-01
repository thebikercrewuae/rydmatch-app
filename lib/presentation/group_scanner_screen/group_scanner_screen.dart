import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/event_service.dart';
import '../../theme/app_theme.dart';

class GroupScannerScreen extends StatefulWidget {
  const GroupScannerScreen({super.key});

  @override
  State<GroupScannerScreen> createState() => _GroupScannerScreenState();
}

class _GroupScannerScreenState extends State<GroupScannerScreen> {
  final EventService _eventService = EventService.instance;
  bool _processing = false;
  String? _result;
  Color? _resultColor;

  void _handleScan(BarcodeCapture capture) async {
    if (_processing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final token = barcodes.first.rawValue;
    if (token == null || token.isEmpty) return;

    setState(() {
      _processing = true;
      _result = null;
    });

    final group = await _eventService.joinGroupByQr(token);

    setState(() => _processing = false);

    if (group != null) {
      final groupName = group['name'] as String? ?? 'Group';
      setState(() {
        _result = ['Joined ', groupName, ' successfully!'].join();
        _resultColor = Colors.green;
      });
    } else {
      setState(() {
        _result = 'Failed to join group. Invalid QR or group is full.';
        _resultColor = Colors.red;
      });
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _result = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Join Ride Group'),
        backgroundColor: AppTheme.backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _handleScan,
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.noDuplicates,
              returnImage: false,
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.secondaryDark, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_result != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _resultColor?.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _result!,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_processing)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'Point camera at the group leader QR code to join the ride group',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
