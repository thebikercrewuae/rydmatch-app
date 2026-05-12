import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

/// Full horizontal RydMatch logo (stylized R emblem + RYD MATCH + tagline).
/// Use this on all auth screens (login, signup, forgot password, onboarding).
///
/// [width] controls the display width. Aspect ratio is always preserved.
class BrandLogoFull extends StatelessWidget {
  final double? width;

  const BrandLogoFull({super.key, this.width});

  @override
  Widget build(BuildContext context) {
    final double logoWidth = width ?? 55.w;
    return Image.asset(
      'assets/images/ChatGPT_Image_May_11_2026_04_56_30_PM-1778504216404.png',
      width: logoWidth,
      fit: BoxFit.contain,
      semanticLabel:
          'RydMatch full logo — stylized blue and orange R emblem with silver RYD and orange MATCH text and tagline Match Ride Repeat',
    );
  }
}

/// Centralized RydMatch branding component.
/// Use [AppLogoWidget] everywhere instead of duplicated logo implementations.
///
/// [size] controls the width/height of the logo in logical pixels.
/// [showText] shows the "RydMatch" text below the logo (for splash/onboarding hero).
/// [showTagline] shows the "Just Ride" tagline (only when [showText] is true).
class AppLogoWidget extends StatelessWidget {
  final double? size;
  final bool showText;
  final bool showTagline;
  final Color textColor;

  const AppLogoWidget({
    super.key,
    this.size,
    this.showText = false,
    this.showTagline = false,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    // When showText is requested on auth screens, render the full logo instead
    // (it already contains the brand name and tagline).
    final double logoWidth = size != null ? size! * 3.5 : 55.w;
    return BrandLogoFull(width: logoWidth);
  }
}

/// Compact inline logo for AppBar titles / top-bar marks.
class AppLogoMark extends StatelessWidget {
  final double? size;

  const AppLogoMark({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    final double logoWidth = size != null ? size! * 3.5 : 30.w;
    return Image.asset(
      'assets/images/ChatGPT_Image_May_11_2026_04_56_30_PM-1778504216404.png',
      width: logoWidth,
      fit: BoxFit.contain,
      semanticLabel: 'RydMatch logo',
    );
  }
}
