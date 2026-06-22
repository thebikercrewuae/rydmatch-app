class PublicContentSafetyResult {
  final bool allowed;
  final String? reason;

  const PublicContentSafetyResult._({required this.allowed, this.reason});

  const PublicContentSafetyResult.allowed()
    : this._(allowed: true, reason: null);

  const PublicContentSafetyResult.blocked(String reason)
    : this._(allowed: false, reason: reason);
}

class PublicContentSafetyService {
  static const String blockedMessage =
      'This content could not be shared because it may describe graphic real-world violence. Please keep public posts and comments safe for riders.';

  static final RegExp _graphicViolencePattern = RegExp(
    r'\b('
    r'gore|gory|bloodbath|blood-soaked|blood soaked|mutilated|mutilation|'
    r'dismembered|dismemberment|decapitated|decapitation|beheaded|'
    r'corpse|dead body|dead bodies|body parts|severed|open wound|'
    r'graphic injury|graphic injuries|graphic violence|violent death|'
    r'crushed body|mangled body|mangled corpse'
    r')\b',
    caseSensitive: false,
  );

  static PublicContentSafetyResult assessText(String? text) {
    final value = text?.trim();
    if (value == null || value.isEmpty) {
      return const PublicContentSafetyResult.allowed();
    }

    if (_graphicViolencePattern.hasMatch(value)) {
      return const PublicContentSafetyResult.blocked(blockedMessage);
    }

    return const PublicContentSafetyResult.allowed();
  }
}
