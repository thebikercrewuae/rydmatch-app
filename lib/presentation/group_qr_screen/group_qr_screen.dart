import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/event_service.dart';
import '../../theme/app_theme.dart';

class GroupQrScreen extends StatefulWidget {
  const GroupQrScreen({super.key});

  @override
  State<GroupQrScreen> createState() => _GroupQrScreenState();
}

class _GroupQrScreenState extends State<GroupQrScreen> {
  final EventService _eventService = EventService.instance;
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String? _groupId;
  String? _groupName;
  String? _qrToken;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && _groupId == null) {
      _groupId = args['groupId'] as String?;
      _groupName = args['groupName'] as String?;
      _qrToken = args['qrToken'] as String?;
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    if (_groupId == null) return;
    setState(() => _loading = true);
    _members = await _eventService.getGroupMembers(_groupId!);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(_groupName ?? 'Group QR', style: const TextStyle(fontSize: 16)),
        backgroundColor: AppTheme.backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _loadMembers,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Show this QR code to your riders',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_qrToken != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: _qrToken!,
                    version: QrVersions.auto,
                    size: 250,
                    gapless: true,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Riders scan this to join your group',
              style: TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Member list
            Row(
              children: [
                Text(
                  ['Members (', _members.length.toString(), ')'].join(),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator(color: AppTheme.secondaryDark))
            else if (_members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No riders have joined yet', style: TextStyle(color: Colors.white54)),
              )
            else
              ..._members.map((m) => Card(
                color: AppTheme.cardDark,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.white54),
                  title: Text(m['full_name'] as String? ?? 'Rider', style: const TextStyle(color: Colors.white)),
                  trailing: Text(
                    _formatTime(m['joined_at'] as String?),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.tryParse(timestamp);
    if (dt == null) return '';
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return [[hour.toString(), minute].join(':'), ' ', ampm].join();
  }
}
