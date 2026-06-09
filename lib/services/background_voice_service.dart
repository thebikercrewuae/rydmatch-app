import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BackgroundVoiceService {
  const BackgroundVoiceService._();

  static const MethodChannel _channel = MethodChannel(
    'rydmatch/background_voice',
  );

  static Future<void> start() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('start');
  }

  static Future<void> stop() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('stop');
  }
}
