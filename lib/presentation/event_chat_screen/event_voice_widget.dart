import 'package:flutter/material.dart';
import '../../services/event_voice_service.dart';
import '../../theme/app_theme.dart';

class EventVoiceWidget extends StatefulWidget {
  final String channelId;
  final String channelName;

  const EventVoiceWidget({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  @override
  State<EventVoiceWidget> createState() => _EventVoiceWidgetState();
}

class _EventVoiceWidgetState extends State<EventVoiceWidget> {
  final EventVoiceService _voiceService = EventVoiceService.instance;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _voiceService.addListener(_onVoiceChanged);
    _voiceService.connect(widget.channelId);
  }

  void _onVoiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _voiceService.removeListener(_onVoiceChanged);
    _voiceService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Connection quality + participant count
          if (_voiceService.isConnected || _voiceService.isConnecting)
            _buildStatusBar(),

          // Participant indicators with audio levels
          if (_voiceService.isConnected && _voiceService.participantCount > 0)
            _buildParticipantsRow(),

          if (_voiceService.isConnecting)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondaryDark),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ['Connecting to ', widget.channelName, '...'].join(),
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),

          if (_voiceService.lastError != null && !_voiceService.isConnected)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_voiceService.lastError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),

          // Main controls row
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: _showSettings ? AppTheme.secondaryDark : Colors.white54,
                  size: 22,
                ),
                onPressed: () => setState(() => _showSettings = !_showSettings),
              ),
              Expanded(
                child: _voiceService.alwaysOnMode
                    ? _buildAlwaysOnToggle()
                    : _buildPushToTalkButton(),
              ),
              IconButton(
                icon: Icon(
                  _voiceService.isMuted ? Icons.mic_off : Icons.mic,
                  color: _voiceService.isMuted ? Colors.red : Colors.green,
                  size: 22,
                ),
                onPressed: null,
              ),
            ],
          ),

          if (_showSettings) _buildSettingsPanel(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final quality = _voiceService.connectionQuality;
    final qualityColor = switch (quality) {
      ConnectionQuality.excellent => Colors.green,
      ConnectionQuality.good => Colors.lightGreen,
      ConnectionQuality.fair => Colors.orange,
      ConnectionQuality.poor => Colors.red,
      ConnectionQuality.unknown => Colors.white54,
    };

    final qualityIcon = switch (quality) {
      ConnectionQuality.excellent => Icons.signal_cellular_alt,
      ConnectionQuality.good => Icons.signal_cellular_alt_2_bar,
      ConnectionQuality.fair => Icons.signal_cellular_alt_1_bar,
      ConnectionQuality.poor => Icons.signal_cellular_alt,
      ConnectionQuality.unknown => Icons.signal_cellular_null,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(qualityIcon, size: 16, color: qualityColor),
          const SizedBox(width: 4),
          Text(
            _voiceService.connectionQualityLabel,
            style: TextStyle(color: qualityColor, fontSize: 11),
          ),
          const Spacer(),
          if (_voiceService.isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people, size: 12, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    [_voiceService.participantCount, ' online'].join(),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantsRow() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _voiceService.participants.length,
        itemBuilder: (context, index) {
          final p = _voiceService.participants[index];
          final isSpeaking = p.isSpeaking;
          final level = p.audioLevel;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isSpeaking
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSpeaking ? Colors.green : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Audio level indicator
                if (isSpeaking || level > 0)
                  _AudioLevelBar(level: level)
                else
                  Icon(
                    p.micEnabled ? Icons.mic : Icons.mic_off,
                    size: 12,
                    color: p.micEnabled ? Colors.white54 : Colors.white24,
                  ),
                const SizedBox(width: 4),
                Text(
                  p.name ?? p.identity,
                  style: TextStyle(
                    color: isSpeaking ? Colors.green : Colors.white54,
                    fontSize: 12,
                    fontWeight: isSpeaking ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPushToTalkButton() {
    final isActive = _voiceService.pushToTalkActive;
    return GestureDetector(
      onTapDown: (_) => _voiceService.startPushToTalk(),
      onTapUp: (_) => _voiceService.stopPushToTalk(),
      onTapCancel: () => _voiceService.stopPushToTalk(),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.secondaryDark
              : AppTheme.secondaryDark.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: AppTheme.secondaryDark,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isActive ? 'Release to stop' : 'Hold to talk',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlwaysOnToggle() {
    final isMuted = _voiceService.isMuted;
    return GestureDetector(
      onTap: () => _voiceService.toggleMute(),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isMuted
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isMuted ? Colors.red : Colors.green,
            width: 1,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isMuted ? Icons.mic_off : Icons.mic,
                color: isMuted ? Colors.red : Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isMuted ? 'Tap to unmute' : 'Tap to mute',
                style: TextStyle(
                  color: isMuted ? Colors.red : Colors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Always-on mode', style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
              Switch(
                value: _voiceService.alwaysOnMode,
                activeThumbColor: AppTheme.secondaryDark,
                onChanged: (v) => _voiceService.setAlwaysOnMode(v),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'When off, use push-to-talk. When on, mic stays active.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text('Background audio', style: const TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _showBackgroundAudioInfo(),
                      child: const Icon(Icons.help_outline, size: 16, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _voiceService.backgroundAudioEnabled,
                activeThumbColor: AppTheme.secondaryDark,
                onChanged: (v) => _voiceService.setBackgroundAudioEnabled(v),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _voiceService.backgroundAudioEnabled
                ? 'Voice continues when app is in background'
                : 'Voice stops when app goes to background',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _showBackgroundAudioInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Background Audio', style: TextStyle(color: Colors.white)),
        content: const Text(
          'When enabled, you will continue to hear voice communications even when your phone is locked or you are using another app. This may use more battery.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: AppTheme.secondaryDark)),
          ),
        ],
      ),
    );
  }
}

class _AudioLevelBar extends StatelessWidget {
  final double level;
  const _AudioLevelBar({required this.level});

  @override
  Widget build(BuildContext context) {
    final clampedLevel = level.clamp(0.0, 1.0);
    final barCount = 4;
    final activeBars = (clampedLevel * barCount).ceil();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(barCount, (i) {
        final isActive = i < activeBars;
        return Container(
          width: 3,
          height: 8 + (i * 3),
          margin: const EdgeInsets.only(right: 1),
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.white24,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }
}
