import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/app_icons.dart';

class ForgotPasswordModalWidget extends StatefulWidget {
  const ForgotPasswordModalWidget({super.key});

  @override
  State<ForgotPasswordModalWidget> createState() =>
      _ForgotPasswordModalWidgetState();
}

class _ForgotPasswordModalWidgetState extends State<ForgotPasswordModalWidget> {
  final TextEditingController _emailController = TextEditingController();
  bool _sent = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo:
            'https://www.rydmatch.com/#/reset-password',
      );
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(5.w, 3.h, 5.w, 4.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 10.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(4.0),
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Reset Password',
            style: GoogleFonts.dmSans(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B365D),
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            _sent
                ? 'Check your inbox — we sent a reset link to your email.'
                : 'Enter your email and we\'ll send you a reset link.',
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              color: const Color(0xFF666666),
            ),
          ),
          SizedBox(height: 2.5.h),
          if (!_sent) ...[
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.dmSans(fontSize: 13.sp),
              decoration: InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(
                  AppIcons.email,
                  color: const Color(0xFF1B365D),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                errorText: _errorMessage,
              ),
            ),
            SizedBox(height: 2.5.h),
            SizedBox(
              width: double.infinity,
              height: 6.h,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendResetLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE85A4F),
                  disabledBackgroundColor: const Color(
                    0xFFE85A4F,
                  ).withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Send Reset Link',
                        style: GoogleFonts.dmSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  Container(
                    width: 15.w,
                    height: 15.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D5A27).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: Color(0xFF2D5A27),
                      size: 36,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  SizedBox(
                    width: double.infinity,
                    height: 6.h,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: Text(
                        'Back to Sign In',
                        style: GoogleFonts.dmSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
