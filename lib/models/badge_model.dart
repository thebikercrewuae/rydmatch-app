import 'package:flutter/material.dart';

enum BadgeCategory { rideMilestones, social, trustSafety, profile, seasonal }

class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String unlockCriteria;
  final BadgeCategory category;
  final IconData icon;
  final Color color;
  bool isEarned;
  DateTime? earnedAt;
  final int? progressCurrent;
  final int? progressTarget;

  BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockCriteria,
    required this.category,
    required this.icon,
    required this.color,
    this.isEarned = false,
    this.earnedAt,
    this.progressCurrent,
    this.progressTarget,
  });

  double get progressRatio {
    if (isEarned) return 1.0;
    if (progressCurrent == null ||
        progressTarget == null ||
        progressTarget == 0) {
      return 0.0;
    }
    return (progressCurrent! / progressTarget!).clamp(0.0, 1.0);
  }

  bool get hasProgress => progressTarget != null && progressTarget! > 0;

  BadgeModel copyWith({
    bool? isEarned,
    DateTime? earnedAt,
    int? progressCurrent,
    int? progressTarget,
  }) {
    return BadgeModel(
      id: id,
      name: name,
      description: description,
      unlockCriteria: unlockCriteria,
      category: category,
      icon: icon,
      color: color,
      isEarned: isEarned ?? this.isEarned,
      earnedAt: earnedAt ?? this.earnedAt,
      progressCurrent: progressCurrent ?? this.progressCurrent,
      progressTarget: progressTarget ?? this.progressTarget,
    );
  }

  static String categoryLabel(BadgeCategory cat) {
    switch (cat) {
      case BadgeCategory.rideMilestones:
        return 'Ride Milestones';
      case BadgeCategory.social:
        return 'Social';
      case BadgeCategory.trustSafety:
        return 'Trust & Safety';
      case BadgeCategory.profile:
        return 'Profile';
      case BadgeCategory.seasonal:
        return 'Seasonal';
    }
  }

  static IconData categoryIcon(BadgeCategory cat) {
    switch (cat) {
      case BadgeCategory.rideMilestones:
        return Icons.route_rounded;
      case BadgeCategory.social:
        return Icons.people_rounded;
      case BadgeCategory.trustSafety:
        return Icons.verified_user_rounded;
      case BadgeCategory.profile:
        return Icons.person_rounded;
      case BadgeCategory.seasonal:
        return Icons.wb_sunny_rounded;
    }
  }

  static List<BadgeModel> allBadges() {
    return [
      // Ride Milestones
      BadgeModel(
        id: 'first_ride',
        name: 'First Ride',
        description: 'Completed your very first ride match.',
        unlockCriteria: 'Complete 1 ride',
        category: BadgeCategory.rideMilestones,
        icon: Icons.flag_rounded,
        color: const Color(0xFF4CAF50),
        progressTarget: 1,
      ),
      BadgeModel(
        id: 'ten_rides',
        name: '10 Rides',
        description: 'A seasoned rider with 10 completed rides.',
        unlockCriteria: 'Complete 10 rides',
        category: BadgeCategory.rideMilestones,
        icon: Icons.directions_bike_rounded,
        color: const Color(0xFF2196F3),
        progressTarget: 10,
      ),
      BadgeModel(
        id: 'fifty_rides',
        name: '50 Rides',
        description: 'Dedicated rider with 50 rides under your belt.',
        unlockCriteria: 'Complete 50 rides',
        category: BadgeCategory.rideMilestones,
        icon: Icons.motorcycle_rounded,
        color: const Color(0xFF9C27B0),
        progressTarget: 50,
      ),
      BadgeModel(
        id: 'hundred_km_club',
        name: '100km Club',
        description: 'Crossed the 100km total distance milestone.',
        unlockCriteria: 'Ride 100km total',
        category: BadgeCategory.rideMilestones,
        icon: Icons.speed_rounded,
        color: const Color(0xFFFF9800),
        progressTarget: 100,
      ),
      BadgeModel(
        id: 'five_hundred_km_club',
        name: '500km Club',
        description: 'Elite rider who has covered 500km total.',
        unlockCriteria: 'Ride 500km total',
        category: BadgeCategory.rideMilestones,
        icon: Icons.emoji_events_rounded,
        color: const Color(0xFFFFD700),
        progressTarget: 500,
      ),
      // Social
      BadgeModel(
        id: 'first_match',
        name: 'First Match',
        description: 'Found your first riding partner.',
        unlockCriteria: 'Get 1 match',
        category: BadgeCategory.social,
        icon: Icons.bolt_rounded,
        color: const Color(0xFFE91E63),
        progressTarget: 1,
      ),
      BadgeModel(
        id: 'five_matches',
        name: '5 Matches',
        description: 'Building a great riding community.',
        unlockCriteria: 'Get 5 matches',
        category: BadgeCategory.social,
        icon: Icons.group_rounded,
        color: const Color(0xFF00BCD4),
        progressTarget: 5,
      ),
      BadgeModel(
        id: 'first_group_ride',
        name: 'First Group Ride',
        description: 'Joined your first group ride adventure.',
        unlockCriteria: 'Join 1 group ride',
        category: BadgeCategory.social,
        icon: Icons.groups_rounded,
        color: const Color(0xFF8BC34A),
        progressTarget: 1,
      ),
      BadgeModel(
        id: 'social_butterfly',
        name: 'Social Butterfly',
        description: 'A true connector with 10 riding matches.',
        unlockCriteria: 'Get 10 matches',
        category: BadgeCategory.social,
        icon: Icons.hub_rounded,
        color: const Color(0xFFFF5722),
        progressTarget: 10,
      ),
      // Trust & Safety
      BadgeModel(
        id: 'verified_rider',
        name: 'Verified Rider',
        description: 'Identity verified for a safer community.',
        unlockCriteria: 'Complete profile verification',
        category: BadgeCategory.trustSafety,
        icon: Icons.verified_rounded,
        color: const Color(0xFF1B365D),
      ),
      BadgeModel(
        id: 'safe_rider',
        name: 'Safe Rider',
        description: 'Consistently rated as a safe riding partner.',
        unlockCriteria: 'Receive 3+ safe rider tags in reviews',
        category: BadgeCategory.trustSafety,
        icon: Icons.shield_rounded,
        color: const Color(0xFF2D5A27),
        progressTarget: 3,
      ),
      BadgeModel(
        id: 'reliable',
        name: 'Reliable',
        description: 'Known for respecting pace and commitments.',
        unlockCriteria: 'Maintain a 5-star streak across 5 rides',
        category: BadgeCategory.trustSafety,
        icon: Icons.thumb_up_rounded,
        color: const Color(0xFF4A7CC7),
        progressTarget: 5,
      ),
      // Profile
      BadgeModel(
        id: 'profile_complete',
        name: 'Profile Complete',
        description: 'Filled out all profile details.',
        unlockCriteria: 'Complete all profile sections',
        category: BadgeCategory.profile,
        icon: Icons.person_pin_rounded,
        color: const Color(0xFF607D8B),
      ),
      BadgeModel(
        id: 'photo_pro',
        name: 'Photo Pro',
        description: 'Showcased your bikes with 6 photos.',
        unlockCriteria: 'Upload 6 bike photos',
        category: BadgeCategory.profile,
        icon: Icons.photo_camera_rounded,
        color: const Color(0xFF795548),
        progressTarget: 6,
      ),
      BadgeModel(
        id: 'premium_member',
        name: 'Premium Member',
        description: 'Unlocked the full RydMatch experience.',
        unlockCriteria: 'Subscribe to Premium',
        category: BadgeCategory.profile,
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFFFFB300),
      ),
      // Seasonal
      BadgeModel(
        id: 'weekend_warrior',
        name: 'Weekend Warrior',
        description: 'Rides hard every weekend.',
        unlockCriteria: 'Complete 5 weekend rides',
        category: BadgeCategory.seasonal,
        icon: Icons.weekend_rounded,
        color: const Color(0xFFE85A4F),
        progressTarget: 5,
      ),
      BadgeModel(
        id: 'early_bird',
        name: 'Early Bird',
        description: 'Loves the quiet roads of early morning.',
        unlockCriteria: 'Complete 3 morning rides (before 8am)',
        category: BadgeCategory.seasonal,
        icon: Icons.wb_twilight_rounded,
        color: const Color(0xFFFF7043),
        progressTarget: 3,
      ),
      BadgeModel(
        id: 'first_live_ride',
        name: 'First Live Ride',
        description: 'Completed your first live group ride.',
        unlockCriteria: 'Complete 1 live ride',
        category: BadgeCategory.rideMilestones,
        icon: Icons.gps_fixed_rounded,
        color: const Color(0xFF2563EB),
        progressTarget: 1,
      ),
      BadgeModel(
        id: 'five_live_rides',
        name: '5 Live Rides',
        description: 'Completed 5 live group rides.',
        unlockCriteria: 'Complete 5 live rides',
        category: BadgeCategory.rideMilestones,
        icon: Icons.gps_fixed_rounded,
        color: const Color(0xFF7C3AED),
        progressTarget: 5,
      ),
      BadgeModel(
        id: 'ten_live_rides',
        name: '10 Live Rides',
        description: 'A true pack rider with 10 live rides.',
        unlockCriteria: 'Complete 10 live rides',
        category: BadgeCategory.rideMilestones,
        icon: Icons.satellite_alt_rounded,
        color: const Color(0xFFDC2626),
        progressTarget: 10,
      ),
      BadgeModel(
        id: 'century_live_ride',
        name: '100km Live Ride',
        description: 'Covered 100km in a single live ride.',
        unlockCriteria: 'Ride 100km in one live session',
        category: BadgeCategory.rideMilestones,
        icon: Icons.map_rounded,
        color: const Color(0xFF059669),
        progressTarget: 100,
      ),
      BadgeModel(
        id: 'night_rider',
        name: 'Night Rider',
        description: 'Completed a live ride after dark.',
        unlockCriteria: 'Complete a ride between 8pm and 5am',
        category: BadgeCategory.seasonal,
        icon: Icons.nightlight_rounded,
        color: const Color(0xFF1E1B4B),
        progressTarget: 1,
      ),
      BadgeModel(
        id: 'speed_demon',
        name: 'Speed Demon',
        description: 'Hit 120km/h during a live ride.',
        unlockCriteria: 'Reach 120km/h in a live ride',
        category: BadgeCategory.rideMilestones,
        icon: Icons.bolt_rounded,
        color: const Color(0xFFEA580C),
        progressTarget: 1,
      ),
      BadgeModel(
        id: 'marathon_rider',
        name: 'Marathon Rider',
        description: 'Rode for over 3 hours in a single live ride.',
        unlockCriteria: 'Complete a 3+ hour live ride',
        category: BadgeCategory.rideMilestones,
        icon: Icons.hourglass_bottom_rounded,
        color: const Color(0xFF0891B2),
        progressTarget: 1,
      ),
      BadgeModel(
        id: 'squad_leader',
        name: 'Squad Leader',
        description: 'Led a live ride with 4+ riders.',
        unlockCriteria: 'Start a live ride with 4+ participants',
        category: BadgeCategory.social,
        icon: Icons.military_tech_rounded,
        color: const Color(0xFFB45309),
        progressTarget: 1,
      ),
    ];
  }
}
