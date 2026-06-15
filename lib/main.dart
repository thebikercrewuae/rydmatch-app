import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './services/haptic_service.dart';
import './services/offline_queue_service.dart';
import './services/premium_service.dart';
import './services/profile_service.dart';
import './services/session_service.dart';
import './services/strava_service.dart';
import './services/supabase_service.dart';
import './services/theme_service.dart';
import './widgets/custom_error_widget.dart';
import 'core/app_export.dart';
import 'web_utils.dart' if (dart.library.io) 'web_utils_stub.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    loadGoogleMapsApi(googleMapsApiKey);
  }

  try {
    await SupabaseService.initialize();
  } catch (e, stack) {
    debugPrint('Supabase initialization failed: $e');
    debugPrintStack(stackTrace: stack);

    runApp(_StartupFailureApp(error: e.toString()));
    return;
  }

  OfflineQueueService.instance.startMonitoring();

  bool hasShownError = false;

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!hasShownError) {
      hasShownError = true;

      Future.delayed(const Duration(seconds: 5), () {
        hasShownError = false;
      });

      return CustomErrorWidget(errorDetails: details);
    }

    return const SizedBox.shrink();
  };

  final bool sessionActive = await SessionService.isSessionActive();

  final uri = Uri.base;
  final isPasswordResetLink =
      uri.path == '/reset-password' ||
      uri.fragment.contains('/reset-password') ||
      uri.queryParameters['type'] == 'recovery' ||
      uri.fragment.contains('type=recovery');

  String initialRoute;

  if (isPasswordResetLink) {
    initialRoute = '/reset-password';
  } else if (sessionActive) {
    final supabaseUser = Supabase.instance.client.auth.currentUser;

    if (supabaseUser != null) {
      await ProfileService.restoreProfileFromSupabase();
      initialRoute = '/main-screen';
    } else {
      bool recovered = false;

      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (Supabase.instance.client.auth.currentUser != null) {
          recovered = true;
          break;
        }
      }

      if (recovered) {
        await ProfileService.restoreProfileFromSupabase();
        initialRoute = '/main-screen';
      } else {
        await SessionService.clearSession();
        final prefs = await SharedPreferences.getInstance();
        final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
        initialRoute = onboardingSeen ? '/' : '/onboarding-screen';
      }
    }
  } else {
    final prefs = await SharedPreferences.getInstance();
    final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
    initialRoute = onboardingSeen ? '/' : '/onboarding-screen';
  }

  await ThemeService().loadThemeMode();
  await HapticService.instance.init();
  await PremiumService().init();
  await StravaService.instance.init();

  void launchApp() {
    runApp(MyApp(initialRoute: initialRoute));
  }

  if (kIsWeb) {
    launchApp();
  } else {
    try {
      await SystemChrome.setPreferredOrientations([]);
    } catch (e) {
      debugPrint('Orientation preference failed: $e');
    }

    launchApp();
  }
}

class _StartupFailureApp extends StatelessWidget {
  final String error;

  const _StartupFailureApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RydMatch',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'RydMatch could not connect.\n\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();
  StreamSubscription<AuthState>? _authSubscription;
  RealtimeChannel? _notificationChannel;

  @override
  void initState() {
    super.initState();

    _themeService.addListener(_onThemeChanged);

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/reset-password',
            (route) => false,
          );
        });
      }

      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        final userId = data.session?.user.id;
        if (userId != null) {
          _startNotificationListener(userId);
        }
      } else if (data.event == AuthChangeEvent.signedOut) {
        _stopNotificationListener();
      }
    });

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _startNotificationListener(currentUser.id);
    }
  }

  void _startNotificationListener(String userId) {
    _stopNotificationListener();

    _notificationChannel = Supabase.instance.client
        .channel('user_notifications_global')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final row = payload.newRecord;

            if (row['notification_type'] == 'emergency_sos' &&
                row['is_read'] == false) {
              final rawArgs = row['action_arguments'];
              final args = rawArgs is Map
                  ? Map<String, dynamic>.from(rawArgs)
                  : <String, dynamic>{};
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final context = _navigatorKey.currentContext;
                if (context == null) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      row['message'] as String? ??
                          'A RydMatch rider needs immediate assistance.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    action: SnackBarAction(
                      label: 'VIEW',
                      textColor: Colors.white,
                      onPressed: () => _navigatorKey.currentState?.pushNamed(
                        '/emergency-alert-screen',
                        arguments: args,
                      ),
                    ),
                    backgroundColor: const Color(0xFFB3261E),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 15),
                  ),
                );
              });
            }

            if (row['notification_type'] == 'new_message' &&
                row['is_read'] == false) {
              final senderId = row['reference_id'] as String?;

              () async {
                String senderName = 'New Message';
                final messageText = row['message'] as String? ?? '';

                if (senderId != null) {
                  try {
                    final profile = await Supabase.instance.client
                        .from('user_profiles')
                        .select('full_name')
                        .eq('id', senderId)
                        .maybeSingle();

                    if (profile != null) {
                      senderName =
                          profile['full_name'] as String? ?? 'New Message';
                    }
                  } catch (_) {}
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final context = _navigatorKey.currentContext;
                  if (context == null) return;

                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();

                          if (senderId != null) {
                            _navigatorKey.currentState?.pushNamedAndRemoveUntil(
                              '/main-screen',
                              (route) => false,
                            );

                            _navigatorKey.currentState?.pushNamed(
                              '/chat-screen',
                              arguments: {
                                'otherUserId': senderId,
                                'otherUserName': senderName,
                              },
                            );
                          }
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    senderName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (messageText.isNotEmpty)
                                    Text(
                                      messageText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'View',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      backgroundColor: const Color(0xFF1B365D),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(seconds: 5),
                      dismissDirection: DismissDirection.horizontal,
                    ),
                  );
                });
              }();
            }
          },
        )
        .subscribe();
  }

  void _stopNotificationListener() {
    _notificationChannel?.unsubscribe();
    _notificationChannel = null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _stopNotificationListener();
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, screenType) {
        return MaterialApp(
          title: 'RydMatch',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _themeService.themeMode,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.0)),
              child: child!,
            );
          },
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          routes: AppRoutes.routes,
          initialRoute: widget.initialRoute,
        );
      },
    );
  }
}
