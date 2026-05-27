import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class EmergencyContactSetupWidget extends StatefulWidget {
  final String contactName;
  final String contactPhone;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onPhoneChanged;

  const EmergencyContactSetupWidget({
    super.key,
    required this.contactName,
    required this.contactPhone,
    required this.onNameChanged,
    required this.onPhoneChanged,
  });

  @override
  State<EmergencyContactSetupWidget> createState() =>
      _EmergencyContactSetupWidgetState();
}

class _EmergencyContactSetupWidgetState
    extends State<EmergencyContactSetupWidget> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  String? _phoneError;

  /// Returns null if valid (or empty — optional field), otherwise an error string.
  static String? validatePhone(String phone) {
    if (phone.isEmpty) return null; // optional
    // Allow digits, spaces, dashes, parentheses, and a leading +
    final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(cleaned)) {
      return 'Enter a valid phone number (7–15 digits, optional + prefix)';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contactName);
    _phoneController = TextEditingController(text: widget.contactPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    widget.onPhoneChanged(value);
    final error = validatePhone(value);
    if (_phoneError != error) {
      setState(() => _phoneError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + header
          Center(
            child: Container(
              width: 18.w,
              height: 18.w,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sos_rounded,
                color: Color(0xFFE53935),
                size: 40,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Center(
            child: Text(
              'Emergency SOS Contact',
              style: GoogleFonts.dmSans(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 1.h),
          Center(
            child: Text(
              'Set a trusted contact who will receive your GPS location if you trigger an SOS alert while riding.',
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'Contact Name',
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.h),
          TextField(
            controller: _nameController,
            onChanged: widget.onNameChanged,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'e.g. Jane Smith',
              hintStyle: GoogleFonts.dmSans(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              prefixIcon: Icon(
                Icons.person_outline_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(
                  color: Color(0xFFE53935),
                  width: 2,
                ),
              ),
            ),
            style: GoogleFonts.dmSans(fontSize: 13.sp),
          ),
          SizedBox(height: 2.h),
          Text(
            'Phone Number',
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.h),
          TextField(
            controller: _phoneController,
            onChanged: _onPhoneChanged,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'e.g. +1 555 000 1234',
              hintStyle: GoogleFonts.dmSans(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              prefixIcon: Icon(
                Icons.phone_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              errorText: _phoneError,
              errorStyle: GoogleFonts.dmSans(fontSize: 11.sp),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: _phoneError != null
                      ? theme.colorScheme.error
                      : theme.colorScheme.outline,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(
                  color: _phoneError != null
                      ? theme.colorScheme.error
                      : const Color(0xFFE53935),
                  width: 2,
                ),
              ),
            ),
            style: GoogleFonts.dmSans(fontSize: 13.sp),
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: const Color(0xFFE53935).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFE53935),
                  size: 18,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'You can skip this step and set it up later from your Profile. SOS is free for all riders.\n\nRydMatch emergency alerts are not a replacement for contacting local emergency services.',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.sp,
                      color: const Color(0xFFE53935).withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
