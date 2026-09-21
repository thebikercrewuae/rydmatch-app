import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventInfo {
  const EventInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.locationName,
    required this.maxRiders,
    required this.donationRequired,
    required this.donationInstructions,
    required this.donationTarget,
    required this.status,
    required this.bannerUrl,
  });

  final String id;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String? locationName;
  final int? maxRiders;
  final bool donationRequired;
  final String? donationInstructions;
  final String? donationTarget;
  final String status;
  final String? bannerUrl;

  factory EventInfo.fromMap(Map<String, dynamic> map) {
    return EventInfo(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      startDate: DateTime.tryParse(map['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(map['end_date']?.toString() ?? '') ?? DateTime.now(),
      locationName: map['location_name'] as String?,
      maxRiders: map['max_riders'] != null ? (map['max_riders'] as num).toInt() : null,
      donationRequired: map['donation_required'] == true,
      donationInstructions: map['donation_instructions'] as String?,
      donationTarget: map['donation_target'] as String?,
      status: map['status'] as String? ?? 'draft',
      bannerUrl: map['banner_url'] as String?,
    );
  }
}

class EventApplicationInfo {
  const EventApplicationInfo({
    required this.id,
    required this.status,
    required this.qrToken,
    required this.checkedIn,
    required this.giftCollected,
    required this.donationVerified,
    required this.donationScreenshotUrl,
  });

  final String id;
  final String status;
  final String? qrToken;
  final bool checkedIn;
  final bool giftCollected;
  final bool donationVerified;
  final String? donationScreenshotUrl;
}

class EventChannelInfo {
  const EventChannelInfo({required this.id, required this.name, this.description, required this.isRestricted});
  final String id;
  final String name;
  final String? description;
  final bool isRestricted;
}

class EventMessageInfo {
  const EventMessageInfo({required this.id, required this.channelId, required this.senderId, required this.body, required this.createdAt});
  final String id;
  final String channelId;
  final String senderId;
  final String? body;
  final DateTime createdAt;
}

class EventService {
  EventService._();
  static final EventService instance = EventService._();
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<EventInfo>> getOpenEvents() async {
    try {
      final response = await _client
          .from('events')
          .select('*')
          .inFilter('status', ['open', 'closed'])
          .order('start_date', ascending: true);
      return (response as List).map((e) => EventInfo.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('getOpenEvents error: $e');
      return [];
    }
  }

  Future<EventInfo?> getEvent(String eventId) async {
    try {
      final response = await _client
          .from('events')
          .select('*')
          .eq('id', eventId)
          .maybeSingle();
      if (response == null) return null;
      return EventInfo.fromMap(response);
    } catch (e) {
      debugPrint('getEvent error: $e');
      return null;
    }
  }

  Future<EventApplicationInfo?> getMyApplication(String eventId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;
      final response = await _client
          .from('event_applications')
          .select('*')
          .eq('event_id', eventId)
          .eq('applicant_id', userId)
          .maybeSingle();
      if (response == null) return null;
      final map = response;
      return EventApplicationInfo(
        id: map['id'] as String,
        status: map['status'] as String? ?? 'pending',
        qrToken: map['qr_token'] as String?,
        checkedIn: map['checked_in'] == true,
        giftCollected: map['gift_collected'] == true,
        donationVerified: map['donation_verified'] == true,
        donationScreenshotUrl: map['donation_screenshot_url'] as String?,
      );
    } catch (e) {
      debugPrint('getMyApplication error: $e');
      return null;
    }
  }

  Future<bool> applyForEvent({
    required String eventId,
    String? clubId,
    String? riderName,
    String? phone,
    String? bikeMake,
    String? bikeModel,
    String? ridingExperience,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    try {
      await _client.rpc('apply_for_event', params: {
        'p_event_id': eventId,
        'p_club_id': clubId,
        'p_rider_name': riderName,
        'p_phone': phone,
        'p_bike_make': bikeMake,
        'p_bike_model': bikeModel,
        'p_riding_experience': ridingExperience,
        'p_emergency_contact_name': emergencyContactName,
        'p_emergency_contact_phone': emergencyContactPhone,
      });
      return true;
    } catch (e) {
      debugPrint('applyForEvent error: $e');
      return false;
    }
  }

  Future<bool> uploadDonationScreenshot(String applicationId, String base64Image) async {
    try {
      await _client
          .from('event_applications')
          .update({'donation_screenshot_url': base64Image})
          .eq('id', applicationId);
      return true;
    } catch (e) {
      debugPrint('uploadDonationScreenshot error: $e');
      return false;
    }
  }

  Future<List<EventChannelInfo>> getEventChannels(String eventId) async {
    try {
      final response = await _client
          .from('event_channels')
          .select('id, name, description, is_restricted')
          .eq('event_id', eventId)
          .order('name');
      return (response as List).map((e) {
        final m = e as Map<String, dynamic>;
        return EventChannelInfo(
          id: m['id'] as String,
          name: m['name'] as String,
          description: m['description'] as String?,
          isRestricted: m['is_restricted'] == true,
        );
      }).toList();
    } catch (e) {
      debugPrint('getEventChannels error');
      return [];
    }
  }

  Future<List<EventMessageInfo>> getChannelMessages(String channelId) async {
    try {
      final response = await _client
          .from('event_channel_messages')
          .select('id, channel_id, sender_id, body, created_at')
          .eq('channel_id', channelId)
          .order('created_at', ascending: false)
          .limit(100);
      return (response as List).map((e) {
        final m = e as Map<String, dynamic>;
        return EventMessageInfo(
          id: m['id'] as String,
          channelId: m['channel_id'] as String,
          senderId: m['sender_id'] as String,
          body: m['body'] as String?,
          createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('getChannelMessages error');
      return [];
    }
  }

  Future<bool> sendChannelMessage(String channelId, String body) async {
    try {
      await _client.rpc('send_channel_message', params: {
        'p_channel_id': channelId,
        'p_body': body,
      });
      return true;
    } catch (e) {
      debugPrint('sendChannelMessage error');
      return false;
    }
  }

  // Staff: check in a rider by QR token
  Future<Map<String, dynamic>?> checkInRider(String qrToken) async {
    try {
      final response = await _client.rpc('event_check_in', params: {'p_qr_token': qrToken});
      if (response is List && response.isNotEmpty) return Map<String, dynamic>.from(response.first as Map);
      if (response is Map) return Map<String, dynamic>.from(response);
      return null;
    } catch (e) {
      debugPrint('checkInRider error: $e');
      return null;
    }
  }

  // Staff: issue gift by QR token
  Future<Map<String, dynamic>?> issueGift(String qrToken) async {
    try {
      final response = await _client.rpc('issue_gift', params: {'p_qr_token': qrToken});
      if (response is List && response.isNotEmpty) return Map<String, dynamic>.from(response.first as Map);
      if (response is Map) return Map<String, dynamic>.from(response);
      return null;
    } catch (e) {
      debugPrint('issueGift error: $e');
      return null;
    }
  }
}
