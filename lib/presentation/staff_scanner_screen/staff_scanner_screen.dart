import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/event_service.dart';
import '../../theme/app_theme.dart';

class StaffScannerScreen extends StatefulWidget {
  const StaffScannerScreen({super.key});

  @override
  State<StaffScannerScreen> createState() => _StaffScannerScreenState();
}

class _StaffScannerScreenState extends State<StaffScannerScreen> {
  final EventService _eventService = EventService.instance;
  bool _processing = false;
  String? _lastResult;
  Color? _resultColor;
  bool _showCheckIn = true;

  void _handleScan(BarcodeCapture capture) async {
    if (_processing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final token = barcodes.first.rawValue;
    if (token == null || token.isEmpty) return;

    setState(() {
      _processing = true;
      _lastResult = null;
    });

    try {
      if (_showCheckIn) {
        final result = await _eventService.checkInRider(token);
        if (result != null) {
          final riderName = result['rider_name'] as String? ?? 'Rider';
          final alreadyCheckedIn = result['checked_in'] == true && result['checked_in_at'] != null;
          final msg = alreadyCheckedIn
              ? [riderName, ' already checked in'].join()
              : [riderName, ' checked in successfully!'].join();
          setState(() {
            _lastResult = msg;
            _resultColor = alreadyCheckedIn ? Colors.orange : Colors.green;
          });
        } else {
          setState(() {
            _lastResult = 'Check-in failed. Invalid QR or not approved.';
            _resultColor = Colors.red;
          });
        }
      } else {
        final result = await _eventService.issueGift(token);
        if (result != null) {
          final riderName = result['rider_name'] as String? ?? 'Rider';
          setState(() {
            _lastResult = ['Gift issued to ', riderName, '!'].join();
            _resultColor = Colors.green;
          });
        } else {
          setState(() {
            _lastResult = 'Gift issue failed. Rider must be checked in first.';
            _resultColor = Colors.red;
          });
        }
      }
    } catch (e) {
      setState(() {
        _lastResult = 'Error occurred during scan';
        _resultColor = Colors.red;
      });
    } finally {
      setState(() => _processing = false);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _lastResult != null) {
          setState(() => _lastResult = null);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Staff Scanner'),
        backgroundColor: AppTheme.backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          ToggleButtons(
            isSelected: [_showCheckIn, !_showCheckIn],
            onPressed: (index) {
              setState(() {
                _showCheckIn = index == 0;
                _lastResult = null;
              });
            },
            color: Colors.white54,
            selectedColor: Colors.white,
            fillColor: _showCheckIn ? Colors.green.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.3),
            borderColor: Colors.white24,
            selectedBorderColor: _showCheckIn ? Colors.green : Colors.blue,
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minHeight: 36, minWidth: 80),
            children: const [
              Text('Check-In', style: TextStyle(fontSize: 12)),
              Text('Gift', style: TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(width: 8),
        ],
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
                border: Border.all(
                  color: _showCheckIn ? Colors.green : Colors.blue,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_lastResult != null)
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
                  _lastResult!,
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
              child: Text(
                _showCheckIn
                    ? 'Point camera at rider QR code to check them in'
                    : 'Point camera at rider QR code to issue gifts',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}