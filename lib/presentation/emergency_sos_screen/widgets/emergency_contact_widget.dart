import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class EmergencyContactWidget extends StatelessWidget {
  final String contactName;
  final String contactPhone;
  final VoidCallback onEdit;

  const EmergencyContactWidget({
    super.key,
    required this.contactName,
    required this.contactPhone,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasContact = contactName.isNotEmpty && contactPhone.isNotEmpty;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: hasContact
              ? Colors.white.withValues(alpha: 0.2)
              : const Color(0xFFE53935).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 11.w,
            height: 11.w,
            decoration: BoxDecoration(
              color: hasContact
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                  : const Color(0xFFE53935).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasContact ? Icons.person_rounded : Icons.person_add_rounded,
              color: hasContact
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFE53935),
              size: 20,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: hasContact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contactName,
                        style: GoogleFonts.dmSans(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        contactPhone,
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  )
                : Text(
                    'No emergency contact set',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.sp,
                      color: const Color(0xFFE53935).withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasContact ? Icons.edit_rounded : Icons.add_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
