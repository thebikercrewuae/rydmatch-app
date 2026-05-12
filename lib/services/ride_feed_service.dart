import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ride_feed_post_model.dart';

class RideFeedService {
  static RideFeedService? _instance;
  static RideFeedService get instance => _instance ??= RideFeedService._();
  RideFeedService._();

  SupabaseClient get _client => Supabase.instance.client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Fetch posts from all users (RLS filters; app-level match filter applied)
  Future<List<RideFeedPost>> fetchFeedPosts({
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final userId = _currentUserId;
      final response = await _client
          .from('ride_feed_posts')
          .select('*')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final posts = (response as List<dynamic>)
          .map((e) => RideFeedPost.fromMap(e as Map<String, dynamic>))
          .toList();

      // Mark liked posts
      if (userId != null && posts.isNotEmpty) {
        final postIds = posts.map((p) => p.id).toList();
        try {
          final likes = await _client
              .from('post_likes')
              .select('post_id')
              .eq('user_id', userId)
              .inFilter('post_id', postIds);
          final likedIds = (likes as List<dynamic>)
              .map((l) => l['post_id'] as String)
              .toSet();
          for (final post in posts) {
            post.isLikedByMe = likedIds.contains(post.id);
          }
        } catch (_) {}
      }
      return posts;
    } catch (e) {
      return [];
    }
  }

  /// Create a new post
  Future<RideFeedPost?> createPost({
    required String? caption,
    required String? photoUrl,
    required String? routeName,
    required double distance,
    required String distanceUnit,
    required String? bikeName,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return null;
      final data = {
        'user_id': userId,
        'caption': caption,
        'photo_url': photoUrl,
        'route_name': routeName,
        'distance': distance,
        'distance_unit': distanceUnit,
        'bike_name': bikeName,
      };
      final response = await _client
          .from('ride_feed_posts')
          .insert(data)
          .select()
          .single();
      return RideFeedPost.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// Toggle like on a post
  Future<bool> toggleLike(String postId, bool currentlyLiked) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return currentlyLiked;
      if (currentlyLiked) {
        await _client
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
        await _client.rpc(
          'decrement_post_likes',
          params: {'post_uuid': postId},
        );
        return false;
      } else {
        await _client.from('post_likes').insert({
          'post_id': postId,
          'user_id': userId,
        });
        await _client.rpc(
          'increment_post_likes',
          params: {'post_uuid': postId},
        );
        return true;
      }
    } catch (e) {
      return currentlyLiked;
    }
  }

  /// Fetch comments for a post
  Future<List<PostComment>> fetchComments(String postId) async {
    try {
      final response = await _client
          .from('post_comments')
          .select('*')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      return (response as List<dynamic>)
          .map((e) => PostComment.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Add a comment
  Future<PostComment?> addComment(String postId, String content) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return null;
      final response = await _client
          .from('post_comments')
          .insert({'post_id': postId, 'user_id': userId, 'content': content})
          .select()
          .single();
      await _client.rpc(
        'increment_post_comments',
        params: {'post_uuid': postId},
      );
      return PostComment.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// Fetch saved routes for the current user
  Future<List<String>> fetchSavedRouteNames() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];
      final response = await _client
          .from('saved_routes')
          .select('name')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (response as List<dynamic>)
          .map((r) => r['name'] as String)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch garage bikes for the current user
  Future<List<String>> fetchGarageBikeNames() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];
      final response = await _client
          .from('garage_bikes')
          .select('make, model, year')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (response as List<dynamic>).map((b) {
        final make = b['make'] as String? ?? '';
        final model = b['model'] as String? ?? '';
        final year = b['year']?.toString() ?? '';
        return '$year $make $model'.trim();
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
