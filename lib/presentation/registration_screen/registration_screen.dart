import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/referral_service.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/app_logo_widget.dart';
// BrandLogoFull is exported from app_logo_widget.dart

enum _RegistrationStep { signup, success }

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with TickerProviderStateMixin {
  _RegistrationStep _step = _RegistrationStep.signup;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  bool _isLoading = false;
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  late AnimationController _successAnimController;
  late Animation<double> _successScaleAnim;
  bool _referralApplied = false;
  bool? _referralCodeValid; // null = not checked, true = valid, false = invalid
  bool _isValidatingCode = false;

  @override
  void initState() {
    super.initState();
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScaleAnim = CurvedAnimation(
      parent: _successAnimController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    _successAnimController.dispose();
    super.dispose();
  }

  bool get _isFormValid =>
      _emailController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _confirmPasswordController.text.isNotEmpty &&
      _acceptedTerms &&
      _acceptedPrivacy &&
      (_referralCodeController.text.trim().isEmpty ||
          _referralCodeValid == true);

  Future<void> _validateReferralCode() async {
    final code = _referralCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isValidatingCode = true;
      _referralCodeValid = null;
    });

    final isValid = await ReferralService().validateReferralCode(code);

    setState(() {
      _isValidatingCode = false;
      _referralCodeValid = isValid;
    });
  }

  void _signUp() async {
    setState(() => _errorMessage = null);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (!RegExp(r'^[\w.-]+@[\w.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create real Supabase auth user
      final supabase = Supabase.instance.client;
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      try {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } catch (_) {}

      debugPrint('📝 SignUp user: ${authResponse.user?.id}');
      debugPrint('📝 SignUp session exists: ${authResponse.session != null}');
      debugPrint('📝 currentUser: ${supabase.auth.currentUser?.id}');

      if (authResponse.user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sign up failed. Please try again.';
        });
        return;
      }

      // If signUp didn't create a session, sign in explicitly
      if (supabase.auth.currentUser == null ||
          supabase.auth.currentSession == null) {
        debugPrint('⚠️ No session after signUp — signing in...');
        try {
          await supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
          debugPrint('✅ Sign in success: ${supabase.auth.currentUser?.id}');
        } catch (signInError) {
          debugPrint('❌ Sign in after signup failed: $signInError');
        }
      }

      // Upsert a profile row so discovery can find this user
      final currentUser = supabase.auth.currentUser;
      debugPrint('👤 Final currentUser: ${currentUser?.id}');

      if (currentUser != null) {
        try {
          await supabase.from('user_profiles').upsert({
            'id': currentUser.id,
            'email': email,
            'full_name': email.split('@').first,
            'is_profile_complete': false,
          }, onConflict: 'id');
        } catch (_) {
          // Non-critical
        }
      }

      // Apply referral code if provided
      final referralCode = _referralCodeController.text.trim();
      bool applied = false;
      if (referralCode.isNotEmpty) {
        applied = await ReferralService().applyReferralCode(referralCode);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _referralApplied = applied;
          _step = _RegistrationStep.success;
        });
        _successAnimController.forward();
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/profile-setup-screen');
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An error occurred. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // Top accent
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 30.h,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B365D), Color(0xFF2A4A7A)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 2.h,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      children: [
                        // Header with full logo
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5.w,
                            vertical: 2.h,
                          ),
                          child: Center(child: BrandLogoFull(width: 52.w)),
                        ),
                        SizedBox(height: 1.h),
                        // Title area
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _step == _RegistrationStep.signup
                                    ? 'Join RydMatch'
                                    : 'You\'re in!',
                                style: GoogleFonts.dmSans(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 0.5.h),
                              Text(
                                _step == _RegistrationStep.signup
                                    ? 'Create your account to find your perfect riding partner.'
                                    : 'Account created successfully.',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11.sp,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 3.h),
                        // Content card
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.symmetric(horizontal: 4.w),
                          padding: EdgeInsets.all(5.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _step == _RegistrationStep.signup
                              ? _buildSignUpStep()
                              : _buildSuccessStep(),
                        ),
                        SizedBox(height: 2.h),
                        // Sign in link
                        if (_step == _RegistrationStep.signup)
                          Padding(
                            padding: EdgeInsets.only(bottom: 2.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11.sp,
                                    color: const Color(0xFF666666),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pushReplacementNamed(
                                    context,
                                    '/login-screen',
                                  ),
                                  child: Text(
                                    'Sign In',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFE85A4F),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email field
        Text(
          'Email address',
          style: GoogleFonts.dmSans(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B365D),
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: GoogleFonts.dmSans(
            fontSize: 13.sp,
            color: const Color(0xFF1B365D),
          ),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            hintText: 'you@example.com',
            hintStyle: GoogleFonts.dmSans(
              color: const Color(0xFF9E9E9E),
              fontSize: 13.sp,
            ),
            prefixIcon: Icon(AppIcons.email, color: const Color(0xFF9E9E9E)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 3.w,
              vertical: 1.8.h,
            ),
          ),
        ),
        SizedBox(height: 2.h),
        // Password field
        Text(
          'Password',
          style: GoogleFonts.dmSans(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B365D),
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.dmSans(
            fontSize: 13.sp,
            color: const Color(0xFF1B365D),
          ),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            hintText: 'Min. 8 characters',
            hintStyle: GoogleFonts.dmSans(
              color: const Color(0xFF9E9E9E),
              fontSize: 13.sp,
            ),
            prefixIcon: Icon(AppIcons.lock, color: const Color(0xFF9E9E9E)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: const Color(0xFF9E9E9E),
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 3.w,
              vertical: 1.8.h,
            ),
          ),
        ),
        SizedBox(height: 2.h),
        // Confirm password field
        Text(
          'Confirm password',
          style: GoogleFonts.dmSans(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B365D),
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: GoogleFonts.dmSans(
            fontSize: 13.sp,
            color: const Color(0xFF1B365D),
          ),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            hintText: 'Re-enter your password',
            hintStyle: GoogleFonts.dmSans(
              color: const Color(0xFF9E9E9E),
              fontSize: 13.sp,
            ),
            prefixIcon: Icon(AppIcons.lock, color: const Color(0xFF9E9E9E)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: const Color(0xFF9E9E9E),
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 3.w,
              vertical: 1.8.h,
            ),
          ),
        ),
        SizedBox(height: 2.h),
        // Referral code field
        Text(
          'Referral code (optional)',
          style: GoogleFonts.dmSans(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B365D),
          ),
        ),
        SizedBox(height: 1.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _referralCodeController,
                textCapitalization: TextCapitalization.characters,
                style: GoogleFonts.dmSans(
                  fontSize: 13.sp,
                  letterSpacing: 1.5,
                  color: const Color(0xFF1B365D),
                ),
                onChanged: (val) {
                  setState(() => _referralCodeValid = null);
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  hintText: 'Enter a friend\'s code',
                  hintStyle: GoogleFonts.dmSans(
                    color: const Color(0xFF9E9E9E),
                    fontSize: 13.sp,
                  ),
                  prefixIcon: Icon(
                    Icons.card_giftcard_rounded,
                    color: _referralCodeValid == true
                        ? const Color(0xFF2D5A27)
                        : _referralCodeValid == false
                        ? const Color(0xFFE85A4F)
                        : const Color(0xFF9E9E9E),
                  ),
                  suffixIcon: _referralCodeValid == true
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF2D5A27),
                        )
                      : _referralCodeValid == false
                      ? const Icon(
                          Icons.cancel_rounded,
                          color: Color(0xFFE85A4F),
                        )
                      : null,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: _referralCodeValid == true
                          ? const Color(0xFF2D5A27)
                          : _referralCodeValid == false
                          ? const Color(0xFFE85A4F)
                          : const Color(0xFFBDBDBD),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: _referralCodeValid == true
                          ? const Color(0xFF2D5A27)
                          : _referralCodeValid == false
                          ? const Color(0xFFE85A4F)
                          : const Color(0xFF1B365D),
                      width: 2,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 3.w,
                    vertical: 1.8.h,
                  ),
                  helperText: _referralCodeValid == true
                      ? '✓ Valid code! You and your friend each get 7 free Premium days.'
                      : _referralCodeValid == false
                      ? 'Invalid code. Please check and try again.'
                      : 'Both you and your friend earn 7 premium trial days!',
                  helperStyle: GoogleFonts.dmSans(
                    fontSize: 10.sp,
                    color: _referralCodeValid == true
                        ? const Color(0xFF2D5A27)
                        : _referralCodeValid == false
                        ? const Color(0xFFE85A4F)
                        : const Color(0xFF2D5A27),
                  ),
                ),
              ),
            ),
            SizedBox(width: 2.w),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      (_referralCodeController.text.trim().isNotEmpty &&
                          !_isValidatingCode)
                      ? _validateReferralCode
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B365D),
                    disabledBackgroundColor: const Color(
                      0xFF1B365D,
                    ).withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 3.w),
                  ),
                  child: _isValidatingCode
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Check',
                          style: GoogleFonts.dmSans(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        // Error message
        if (_errorMessage != null)
          Padding(
            padding: EdgeInsets.only(bottom: 1.5.h),
            child: Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDEC),
                borderRadius: BorderRadius.circular(10.0),
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
          ),
        // Terms of Service checkbox
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _acceptedTerms,
                activeColor: const Color(0xFFE85A4F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                ),
                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.dmSans(
                    fontSize: 11.sp,
                    color: const Color(0xFF666666),
                  ),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: GoogleFonts.dmSans(
                        fontSize: 11.sp,
                        color: const Color(0xFFE85A4F),
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFFE85A4F),
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => Navigator.pushNamed(context, '/terms'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        // Privacy Policy checkbox
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _acceptedPrivacy,
                activeColor: const Color(0xFFE85A4F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                ),
                onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.dmSans(
                    fontSize: 11.sp,
                    color: const Color(0xFF666666),
                  ),
                  children: [
                    const TextSpan(text: 'I acknowledge the '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: GoogleFonts.dmSans(
                        fontSize: 11.sp,
                        color: const Color(0xFFE85A4F),
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFFE85A4F),
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () =>
                            Navigator.pushNamed(context, '/privacy'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 3.h),
        SizedBox(
          width: double.infinity,
          height: 6.5.h,
          child: ElevatedButton(
            onPressed: (_isFormValid && !_isLoading) ? _signUp : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85A4F),
              disabledBackgroundColor: const Color(
                0xFFE85A4F,
              ).withValues(alpha: 0.4),
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
                    'Create Account',
                    style: GoogleFonts.dmSans(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _successScaleAnim,
              child: Container(
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D5A27).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.check,
                  color: Color(0xFF2D5A27),
                  size: 56,
                ),
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'Account Created!',
              style: GoogleFonts.dmSans(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1B365D),
              ),
            ),
            SizedBox(height: 1.h),
            if (_referralApplied) ...[
              Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D5A27).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: const Color(0xFF2D5A27).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.card_giftcard_rounded,
                      color: Color(0xFF2D5A27),
                      size: 20,
                    ),
                    SizedBox(width: 2.w),
                    Flexible(
                      child: Text(
                        '🎉 7-day Premium trial activated for you and your friend!',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2D5A27),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 1.5.h),
            ],
            Text(
              'Setting up your profile...',
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                color: const Color(0xFF666666),
              ),
            ),
            SizedBox(height: 3.h),
            const CircularProgressIndicator(
              color: Color(0xFFE85A4F),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
