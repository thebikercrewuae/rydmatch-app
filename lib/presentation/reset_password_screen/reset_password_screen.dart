import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/app_icons.dart';
import '../../widgets/app_logo_widget.dart';
// BrandLogoFull is exported from app_logo_widget.dart

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _success = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );
      if (mounted) setState(() => _success = true);
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
    return Scaffold(
      body: Stack(
        children: [
          // Background
          SizedBox.expand(
            child: Image.network(
              'https://images.pexels.com/photos/1715193/pexels-photo-1715193.jpeg',
              fit: BoxFit.cover,
              semanticLabel:
                  'Motorcycle rider on open road at sunset with dramatic sky',
            ),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1B365D).withValues(alpha: 0.85),
                  const Color(0xFF0D1B2A).withValues(alpha: 0.97),
                ],
                stops: const [0.0, 0.65],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 5.h),
                  // Full horizontal logo
                  Center(child: BrandLogoFull(width: 55.w)),
                  SizedBox(height: 4.h),
                  // Card
                  Container(
                    padding: EdgeInsets.all(5.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: _success ? _buildSuccessState() : _buildFormState(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set New Password',
            style: GoogleFonts.dmSans(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B365D),
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            'Choose a strong password for your account.',
            style: GoogleFonts.dmSans(
              fontSize: 11.sp,
              color: const Color(0xFF666666),
            ),
          ),
          SizedBox(height: 2.5.h),
          // New password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            style: GoogleFonts.dmSans(fontSize: 13.sp),
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: Icon(AppIcons.lock, color: const Color(0xFF1B365D)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF666666),
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a new password';
              if (v.length < 8) return 'Password must be at least 8 characters';
              return null;
            },
          ),
          SizedBox(height: 2.h),
          // Confirm password field
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            style: GoogleFonts.dmSans(fontSize: 13.sp),
            onFieldSubmitted: (_) => _updatePassword(),
            decoration: InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: Icon(AppIcons.lock, color: const Color(0xFF1B365D)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF666666),
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              if (v != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            SizedBox(height: 1.5.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: const Color(0xFFE85A4F).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: const Color(0xFFE85A4F).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFE85A4F),
                    size: 18,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.dmSans(
                        fontSize: 11.sp,
                        color: const Color(0xFFE85A4F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 2.5.h),
          SizedBox(
            width: double.infinity,
            height: 6.h,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _updatePassword,
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
                      'Update Password',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 1.5.h),
          Center(
            child: TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/login-screen'),
              child: Text(
                'Back to Sign In',
                style: GoogleFonts.dmSans(
                  fontSize: 12.sp,
                  color: const Color(0xFF1B365D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      children: [
        SizedBox(height: 1.h),
        Container(
          width: 18.w,
          height: 18.w,
          decoration: BoxDecoration(
            color: const Color(0xFF2D5A27).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF2D5A27),
            size: 42,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          'Password Updated!',
          style: GoogleFonts.dmSans(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1B365D),
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          'Your password has been changed successfully. You can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 12.sp,
            color: const Color(0xFF666666),
          ),
        ),
        SizedBox(height: 3.h),
        SizedBox(
          width: double.infinity,
          height: 6.h,
          child: ElevatedButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/login-screen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85A4F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: Text(
              'Sign In',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: 1.h),
      ],
    );
  }
}
