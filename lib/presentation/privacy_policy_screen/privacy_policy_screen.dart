import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import '../../constants/legal_content.dart';
import '../../widgets/app_logo_widget.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFF111827);
    final cardColor = isDark
        ? const Color(0xFF161B22)
        : const Color(0xFF1A2332);
    final subtextColor = Colors.white.withValues(alpha: 0.65);
    const accentOrange = Color(0xFFFF6B35);
    const accentNavy = Color(0xFF1B365D);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogoMark(size: 6.w),
            SizedBox(width: 2.w),
            Text(
              'Privacy Policy',
              style: GoogleFonts.dmSans(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentOrange.withValues(alpha: 0.6),
                  accentNavy.withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header banner
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B365D), Color(0xFF0D1B2A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: accentOrange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: accentOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: accentOrange,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RYDMATCH Privacy Policy',
                          style: GoogleFonts.dmSans(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Last updated: ${RydMatchLegalContent.privacyLastUpdated}',
                          style: GoogleFonts.dmSans(
                            fontSize: 10.sp,
                            color: accentOrange.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 2.h),
            // Sections
            ...RydMatchLegalContent.privacySections.map(
              (section) => _buildSection(
                section,
                cardColor: cardColor,
                subtextColor: subtextColor,
                accentOrange: accentOrange,
              ),
            ),
            SizedBox(height: 3.h),
            // Footer
            _buildFooter(
              accentOrange: accentOrange,
              subtextColor: subtextColor,
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    LegalSection section, {
    required Color cardColor,
    required Color subtextColor,
    required Color accentOrange,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 18,
                margin: const EdgeInsets.only(top: 2, right: 10),
                decoration: BoxDecoration(
                  color: accentOrange,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
              Expanded(
                child: Text(
                  section.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            section.content,
            style: GoogleFonts.dmSans(
              fontSize: 11.sp,
              color: subtextColor,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter({
    required Color accentOrange,
    required Color subtextColor,
  }) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: accentOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: accentOrange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.privacy_tip_outlined, color: accentOrange, size: 18),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              'Your privacy matters. Questions? Contact privacy@rydmatch.app',
              style: GoogleFonts.dmSans(
                fontSize: 10.sp,
                color: subtextColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
