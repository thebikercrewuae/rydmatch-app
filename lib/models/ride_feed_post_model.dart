class RideFeedPost {
  final String id;
  final String userId;
  final String? caption;
  final String? photoUrl;
  final String? routeName;
  final double distance;
  final String distanceUnit;
  final String? bikeName;
  int likesCount;
  int commentsCount;
  final DateTime createdAt;
  bool isLikedByMe;

  // Display fields (joined from profile)
  final String? riderName;
  final String? riderPhotoUrl;
  bool isPioneer;
  int? pioneerNumber;

  RideFeedPost({
    required this.id,
    required this.userId,
    this.caption,
    this.photoUrl,
    this.routeName,
    this.distance = 0,
    this.distanceUnit = 'km',
    this.bikeName,
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    this.isLikedByMe = false,
    this.riderName,
    this.riderPhotoUrl,
    this.isPioneer = false,
    this.pioneerNumber,
  });

  factory RideFeedPost.fromMap(Map<String, dynamic> map) {
    return RideFeedPost(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      caption: map['caption'] as String?,
      photoUrl: map['photo_url'] as String?,
      routeName: map['route_name'] as String?,
      distance: (map['distance'] as num?)?.toDouble() ?? 0,
      distanceUnit: map['distance_unit'] as String? ?? 'km',
      bikeName: map['bike_name'] as String?,
      likesCount: (map['likes_count'] as int?) ?? 0,
      commentsCount: (map['comments_count'] as int?) ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      riderName: map['rider_name'] as String?,
      riderPhotoUrl: map['rider_photo_url'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'caption': caption,
      'photo_url': photoUrl,
      'route_name': routeName,
      'distance': distance,
      'distance_unit': distanceUnit,
      'bike_name': bikeName,
    };
  }

  String get formattedDistance {
    if (distance <= 0) return '';
    final unit = distanceUnit == 'km' ? 'km' : 'mi';
    return '${distance.toStringAsFixed(1)} $unit';
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? riderName;
  final String? riderPhotoUrl;

  PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.riderName,
    this.riderPhotoUrl,
  });

  factory PostComment.fromMap(Map<String, dynamic> map) {
    return PostComment(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      userId: map['user_id'] as String,
      content: map['content'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      riderName: map['rider_name'] as String?,
      riderPhotoUrl: map['rider_photo_url'] as String?,
    );
  }
}
