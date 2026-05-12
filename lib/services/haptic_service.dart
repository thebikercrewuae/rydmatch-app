import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HapticService {
  static const String _prefKey = 'haptic_feedback_enabled';

  static HapticService? _instance;
  static HapticService get instance => _instance ??= HapticService._();
  HapticService._();

  bool _enabled = true;

  bool get isEnabled => _enabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  /// Light tap — button presses, toggles
  void light() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  /// Medium impact — likes, matches
  void medium() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact — SOS, destructive actions
  void heavy() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Selection click — swipes, navigation
  void selection() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }
}
