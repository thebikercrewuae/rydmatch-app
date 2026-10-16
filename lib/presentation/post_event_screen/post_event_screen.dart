import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class PostEventScreen extends StatefulWidget {
  final String eventName;

  const PostEventScreen({super.key, required this.eventName});

  @override
  State<PostEventScreen> createState() => _PostEventScreenState();
}

class _PostEventScreenState extends State<PostEventScreen> {
  bool _processing = false;
  bool _isPermanentUser = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _checking = false);
        return;
      }

      // Check if user is a pioneer member or premium subscriber
      // These are "permanent" users who should NOT see the delete option
      bool isPermanent = false;

      // Check pioneer_members table
      final pioneerResult = await client
          .from('pioneer_members')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      if (pioneerResult != null) {
        isPermanent = true;
      }

      // Check if user has premium status
      if (!isPermanent) {
        final profileResult = await client
            .from('user_profiles')
            .select('is_premium')
            .eq('id', userId)
            .maybeSingle();
        if (profileResult != null && profileResult['is_premium'] == true) {
          isPermanent = true;
        }
      }


      if (mounted) {
        setState(() {
          _isPermanentUser = isPermanent;
          _checking = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _keepAccount() async {
    Navigator.of(context).pop();
  }

  Future<void> _deleteAccount() async {
    setState(() => _processing = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        await client.from('user_profiles').delete().eq('id', userId);
        await client.auth.signOut();
      }
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete account'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Event Ended'),
        backgroundColor: AppTheme.backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event_available, size: 64, color: AppTheme.secondaryDark),
              const SizedBox(height: 24),
              Text(
                [widget.eventName, ' has ended'].join(),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Thank you for participating! What would you like to do with your RydMatch account?',
                style: TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _keepAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Keep My Account'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Continue using RydMatch to discover riders, join rides, and more.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              if (!_isPermanentUser) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _processing ? null : _deleteAccount,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _processing
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))
                        : const Text('Delete My Account'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Permanently delete your account and all data.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: AppTheme.secondaryDark, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "You are a valued RydMatch member. Your account will remain active.",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}