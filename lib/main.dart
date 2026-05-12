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
import './services/supabase_service.dart';
import './services/theme_service.dart';
import './widgets/custom_error_widget.dart';
import 'core/app_export.dart';
import 'web_utils.dart' if (dart.library.io) 'web_utils_stub.dart';
import 'presentation/admin_verification_screen/admin_verification_screen.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool supabaseReady = false;

  if (kIsWeb) {
    const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    loadGoogleMapsApi(googleMapsApiKey);
  }

  try {
    await SupabaseService.initialize();
    supabaseReady = true;
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
    supabaseReady = false;
  }

  if (supabaseReady) {
    try {
      OfflineQueueService.instance.startMonitoring();
    } catch (e) {
      debugPrint('Offline queue start failed: $e');
    }
  }

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

  String initialRoute = '/onboarding-screen';

  try {
    final bool sessionActive = await SessionService.isSessionActive();

    final uri = Uri.base;
    final isPasswordResetLink =
        uri.path == '/reset-password' ||
        uri.fragment.contains('/reset-password') ||
        uri.queryParameters['type'] == 'recovery' ||
        uri.fragment.contains('type=recovery');

    if (isPasswordResetLink) {
      initialRoute = '/reset-password';
    } else if (sessionActive && supabaseReady) {
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
          final bool onboardingSeen =
              prefs.getBool('onboarding_seen') ?? false;
          initialRoute = onboardingSeen ? '/' : '/onboarding-screen';
        }
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final bool onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
      initialRoute = onboardingSeen ? '/' : '/onboarding-screen';
    }
  } catch (e) {
    debugPrint('Startup route resolution failed: $e');
    initialRoute = '/onboarding-screen';
  }

  try {
    await ThemeService().loadThemeMode();
  } catch (e) {
    debugPrint('Theme load failed: $e');
  }

  try {
    await HapticService.instance.init();
  } catch (e) {
    debugPrint('Haptic init failed: $e');
  }

  if (supabaseReady) {
    try {
      await PremiumService().init();
    } catch (e) {
      debugPrint('Premium init failed: $e');
    }
  }

  void launchApp() {
    runApp(MyApp(initialRoute: initialRoute, supabaseReady: supabaseReady));
  }

  if (kIsWeb) {
    launchApp();
  } else {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } catch (e) {
      debugPrint('Orientation lock failed: $e');
    }

    launchApp();
  }
}

class MyApp extends StatefulWidget {
  final String initialRoute;
  final bool supabaseReady;

  const MyApp({
    super.key,
    required this.initialRoute,
    required this.supabaseReady,
  });

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

    if (!widget.supabaseReady) {
      return;
    }

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
    if (!widget.supabaseReady) return;

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

            if (row['notification_type'] == 'new_message' &&
                row['is_read'] == false) {
              final senderId = row['reference_id'] as String?;

              () async {
                String senderName = 'New Message';
                String messageText = row['message'] as String? ?? '';

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
                            _navigatorKey.currentState
                                ?.pushNamedAndRemoveUntil(
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
                                      fontSize: 13.0,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (messageText.isNotEmpty)
                                    Text(
                                      messageText,
                                      style: const TextStyle(
                                        fontSize: 12.0,
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
                                horizontal: 12.0,
                                vertical: 6.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: const Text(
                                'View',
                                style: TextStyle(
                                  fontSize: 12.0,
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
                      margin: const EdgeInsets.fromLTRB(
                        12.0,
                        8.0,
                        12.0,
                        12.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
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
