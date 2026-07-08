                ),
              ),
            ],
          ),
        ),
        // Waypoint dots
        Positioned(
          bottom: 22,
          left: 30,
          child: _WaypointDot(color: const Color(0xFF66BB6A)),
        ),
        Positioned(
          bottom: 22,
          right: 30,
          child: _WaypointDot(color: Colors.white),
        ),
      ],
    );
  }
}

class _SafetyIllustration extends StatelessWidget {
  const _SafetyIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Shield background glow
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFCA28).withValues(alpha: 0.15),
          ),
        ),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFCA28).withValues(alpha: 0.2),
          ),
        ),
        // Shield icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFCA28), Color(0xFFFFB300)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFCA28).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Color(0xFF4A3000),
            size: 34,
          ),
        ),
        // Feature chips
        Positioned(
          top: 18,
          right: 14,
          child: _SafetyChip(label: 'SOS Alert', icon: Icons.sos_rounded),
        ),
        Positioned(
          bottom: 18,
          left: 14,
          child: _SafetyChip(
            label: 'Live Location',
            icon: Icons.location_on_rounded,
          ),
        ),
        Positioned(
          bottom: 18,
          right: 14,
          child: _SafetyChip(
            label: 'Trusted Contacts',
            icon: Icons.contacts_rounded,
          ),
        ),
      ],
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

class _MiniRiderCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String distance;
  final Color color;
  final String semanticLabel;

  const _MiniRiderCard({
    required this.imageUrl,
    required this.name,
    required this.distance,
    required this.color,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)
