import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Circular avatar that shows a rider's uploaded photo when available and
/// falls back to their initials on a deterministic colored circle when no
/// photo exists (or the photo fails to load). Used across the app so the
/// "no profile pic" state looks intentional and consistent everywhere
/// instead of showing a generic placeholder image.
class FallbackAvatar extends StatelessWidget {
  const FallbackAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 22,
  });

  final String name;
  final String? imageUrl;
  final double radius;

  static const List<Color> _palette = [
    Color(0xFF1B365D),
    Color(0xFFE85A4F),
    Color(0xFFFFB347),
    Color(0xFF2A9D8F),
    Color(0xFF6A4C93),
    Color(0xFF3A6B5C),
    Color(0xFFB03A31),
    Color(0xFF457B9D),
  ];

  /// Stable color for a given name (shared with the card fallback so a
  /// rider's color is consistent across the circular avatar and the card).
  static Color colorFor(String name) {
    final hash = name.toLowerCase().codeUnits.fold<int>(
          0,
          (a, b) => (a * 31 + b) & 0x7FFFFFFF,
        );
    return _palette[hash % _palette.length];
  }

  /// Up to two uppercase initials for a name ("Uday Saji John" -> "UJ").
  static String initialsFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  String get _initials => initialsFor(name);
  Color get _color => colorFor(name);

  bool get _hasImage =>
      imageUrl != null &&
      imageUrl!.isNotEmpty &&
      (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'));

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final initials = Text(
      _initials,
      style: GoogleFonts.dmSans(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: radius * 0.85,
      ),
    );

    final coloredCircle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
      child: Center(child: initials),
    );

    if (!_hasImage) return coloredCircle;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
      child: ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(child: initials),
          loadingBuilder: (context, child, loading) =>
              loading == null ? child : Center(child: initials),
        ),
      ),
    );
  }
}