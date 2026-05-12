import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _keyStaySignedIn = 'stay_signed_in';
  static const String _keyIsLoggedIn = 'is_logged_in';

  /// Saves the user's session preference.
  static Future<void> saveSession({required bool staySignedIn}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyStaySignedIn, staySignedIn);
    if (staySignedIn) {
      await prefs.setBool(_keyIsLoggedIn, true);
    }
  }

  /// Returns true if the user chose to stay signed in and has an active session.
  static Future<bool> isSessionActive() async {
    final prefs = await SharedPreferences.getInstance();
    final staySignedIn = prefs.getBool(_keyStaySignedIn) ?? false;
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    return staySignedIn && isLoggedIn;
  }

  /// Clears the session (used on sign out).
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStaySignedIn);
    await prefs.remove(_keyIsLoggedIn);
  }
}
