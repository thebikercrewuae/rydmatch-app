import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/session_service.dart';
import '../../services/profile_service.dart';
import '../../services/premium_service.dart';
import './widgets/forgot_password_modal_widget.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/app_logo_widget.dart';
// BrandLogoFull is exported from app_logo_widget.dart

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _staySignedIn = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sign in failed. Please check your details.';
        });
        return;
      }

      try {
        await SessionService.saveSession(staySignedIn: _staySignedIn);
      } catch (e) {
        debugPrint('LoginScreen: saveSession failed: $e');
      }

      try {
        await ProfileService.restoreProfileFromSupabase();
      } catch (e) {
        debugPrint('LoginScreen: restoreProfileFromSupabase failed: $e');
      }

      try {
        await PremiumService().refresh();
      } catch (e) {
        debugPrint('LoginScreen: premium refresh failed: $e');
      }

      if (!mounted) return;

      setState(() => _isLoading = false);

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/main-screen',
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      debugPrint('LoginScreen: unexpected sign in error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _showForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const ForgotPasswordModalWidget(),
      ),
    );
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
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Color(0xFF0D1B2A)),
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back',
                            style: GoogleFonts.dmSans(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1B365D),
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            'Sign in to continue riding',
                            style: GoogleFonts.dmSans(
                              fontSize: 11.sp,
                              color: const Color(0xFF666666),
                            ),
                          ),
                          SizedBox(height: 2.5.h),
                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: GoogleFonts.dmSans(
                              fontSize: 13.sp,
                              color: const Color(0xFF1B365D),
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              labelText: 'Email address',
                              prefixIcon: Icon(
                                AppIcons.email,
                                color: const Color(0xFF1B365D),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Enter your email';
                              }
                              if (!v.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 2.h),
                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            style: GoogleFonts.dmSans(
                              fontSize: 13.sp,
                              color: const Color(0xFF1B365D),
                            ),
                            onFieldSubmitted: (_) => _signIn(),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              labelText: 'Password',
                              prefixIcon: Icon(
                                AppIcons.lock,
                                color: const Color(0xFF1B365D),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF1B365D),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Enter your password';
                              }
                              if (v.length < 6) return 'Password too short';
                              return null;
                            },
                          ),
                          SizedBox(height: 1.2.h),
                          // Forgot password row + Stay signed in
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Stay signed in checkbox
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _staySignedIn,
                                      activeColor: const Color(0xFFE85A4F),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          4.0,
                                        ),
                                      ),
                                      onChanged: (val) => setState(
                                        () => _staySignedIn = val ?? false,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 1.5.w),
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _staySignedIn = !_staySignedIn,
                                    ),
                                    child: Text(
                                      'Stay signed in',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11.sp,
                                        color: const Color(0xFF444444),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Forgot password
                              TextButton(
                                onPressed: _showForgotPassword,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11.sp,
                                    color: const Color(0xFFE85A4F),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 1.4.h),
                          // Error message
                          if (_errorMessage != null) ...[
                            Container(
                              padding: EdgeInsets.all(3.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: const Color(
                                    0xFFE85A4F,
                                  ).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: const Color(0xFFE85A4F),
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
                            SizedBox(height: 1.5.h),
                          ],
                          // Sign In button
                          SizedBox(
                            width: double.infinity,
                            height: 6.5.h,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE85A4F),
                                disabledBackgroundColor: const Color(
                                  0xFFE85A4F,
                                ).withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                elevation: 0,
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
                                      'Sign In',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 2.5.h),
                          // Divider
                          // remove divider and social buttons
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  // Sign up prompt
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New to RydMatch? ',
                        style: GoogleFonts.dmSans(
                          fontSize: 12.sp,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/registration-screen',
                        ),
                        child: Text(
                          'Create Account',
                          style: GoogleFonts.dmSans(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE85A4F),
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFFE85A4F),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  // Legal links
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/terms'),
                        child: Text(
                          'Terms of Service',
                          style: GoogleFonts.dmSans(
                            fontSize: 10.sp,
                            color: Colors.white.withValues(alpha: 0.45),
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2.w),
                        child: Text(
                          '·',
                          style: GoogleFonts.dmSans(
                            fontSize: 10.sp,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/privacy'),
                        child: Text(
                          'Privacy Policy',
                          style: GoogleFonts.dmSans(
                            fontSize: 10.sp,
                            color: Colors.white.withValues(alpha: 0.45),
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
