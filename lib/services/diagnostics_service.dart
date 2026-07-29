import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiagnosticsService {
  static DiagnosticsService? _instance;
  static DiagnosticsService get instance =>
      _instance ??= DiagnosticsService._();

  DiagnosticsService._();

  Future<void> logError({
    required String feature,
    required String action,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    String severity = 'error',
    bool isDebug = kDebugMode,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      await supabase.from('app_errors').insert({
        'user_id': user?.id,
        'feature': feature,
        'action': action,
        'severity': severity,
        'message': error.toString(),
        'stack_trace': stackTrace?.toString(),
        'context': context ?? {},
        'platform': defaultTargetPlatform.name,
        'is_debug': isDebug,
      });
    } catch (loggingError) {
      debugPrint('DiagnosticsService.logError failed: $loggingError');
    }
  }
}
