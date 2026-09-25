import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/event_service.dart';
import '../../services/session_service.dart';
import '../../services/profile_service.dart';
import '../../services/premium_service.dart';
import '../../theme/app_theme.dart';

class StaffSignupScreen extends StatefulWidget {
  const StaffSignupScreen({super.key});

  @override
  State<StaffSignupScreen> createState() => _StaffSignupScreenState();
}

class _StaffSignupScreenState extends State<StaffSignupScreen> {
  final EventService _eventService = EventService.instance;
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _codeVerified = false;
  bool _loading = false;
  bool _registering = false;
  String? _eventName;

  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _eventService.verifyStaffCode(code);

    setState(() => _loading = false);

    if (result != null) {
      setState(() {
        _codeVerified = true;
        _eventName = result['event_name'] as String?;

      });
    } else {
      setState(() => _error = 'Invalid or expired staff code');
    }
  }

  Future<void> _register() async {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || email.isEmpty || password.length < 6) {
      setState(() => _error = 'Please fill in all fields. Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _registering = true;
      _error = null;
    });

    final success = await _eventService.registerEventStaff(
      code: code,
      email: email,
      password: password,
      fullName: name,
      phone: phone.isEmpty ? null : phone,
    );

    if (success) {
      // Sign in with the credentials
      try {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (response.session != null) {
          await SessionService.saveSession(staySignedIn: true);
          await ProfileService.restoreProfileFromSupabase();
          await PremiumService().refresh();

          if (mounted) {
            // Navigate to event channels
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/main-screen',
              (route) => false,
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _error = 'Account created but sign-in failed. Please try signing in manually.');
        }
      }
    } else {
      if (mounted) {
        setState(() => _error = 'Registration failed. The email may already be in use.');
      }
    }

    if (mounted) setState(() => _registering = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Event Staff Sign Up'),
        backgroundColor: AppTheme.backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              const Icon(Icons.event_available, size: 56, color: AppTheme.secondaryDark),
              const SizedBox(height: 16),

              Text(
                'Join as Event Staff',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the code provided by the event organizer to get started.',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Step 1: Enter code
              if (!_codeVerified) ...[
                _buildTextField(
                  controller: _codeController,
                  label: 'Staff Code',
                  hint: 'EVENT-XXXXXX',
                  icon: Icons.qr_code,
                  uppercase: true,
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Verify Code'),
                  ),
                ),
              ],

              // Step 2: Registration form
              if (_codeVerified) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ['Verified for: ', _eventName ?? 'Event'].join(),
                          style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildTextField(controller: _nameController, label: 'Full Name', hint: 'Enter your name', icon: Icons.person),
                const SizedBox(height: 12),
                _buildTextField(controller: _emailController, label: 'Email', hint: 'you@example.com', icon: Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildTextField(controller: _passwordController, label: 'Password', hint: 'At least 6 characters', icon: Icons.lock, obscureText: true),
                const SizedBox(height: 12),
                _buildTextField(controller: _phoneController, label: 'Phone (optional)', hint: '+971...', icon: Icons.phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 20),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _registering ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _registering
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Sign Up as Staff'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {
                    _codeVerified = false;
                    _error = null;
                    _codeController.clear();
                  }),
                  child: const Text('Use a different code', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    bool uppercase = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: uppercase ? TextCapitalization.characters : TextCapitalization.none,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: AppTheme.surfaceDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
