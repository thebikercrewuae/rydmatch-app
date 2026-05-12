import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerificationService {
  static VerificationService? _instance;
  static VerificationService get instance =>
      _instance ??= VerificationService._();
  VerificationService._();

  final SupabaseClient _client = Supabase.instance.client;

  /// Fetch current user's verification record
  Future<Map<String, dynamic>?> getMyVerification() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;
      final response = await _client
          .from('rider_verifications')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Check if a specific user is verified (approved)
  Future<bool> isUserVerified(String userId) async {
    try {
      final response = await _client
          .from('rider_verifications')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'approved')
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  /// Submit a verification request with optional document upload
  Future<({bool success, String? error})> submitVerification({
    required String documentType,
    List<int>? documentBytes,
    String? documentFileName,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return (success: false, error: 'Not logged in');
      }

      // Check if already has a pending/approved verification
      final existing = await getMyVerification();
      if (existing != null) {
        final status = existing['status'] as String?;
        if (status == 'approved') {
          return (success: false, error: 'Already verified');
        }
        if (status == 'pending') {
          return (success: false, error: 'Verification already under review');
        }
      }

      String? documentUrl;

      // Upload document if provided
      if (documentBytes != null && documentFileName != null) {
        final path = '$userId/$documentFileName';
        await _client.storage
            .from('verification-docs')
            .uploadBinary(path, Uint8List.fromList(documentBytes));
        documentUrl = path;
      }

      await _client.from('rider_verifications').insert({
        'user_id': userId,
        'document_type': documentType,
        'document_url': documentUrl,
        'status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
      });

      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: 'Submission failed. Please try again.');
    }
  }

  /// Cancel a pending verification
  Future<bool> cancelVerification() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;
      await _client
          .from('rider_verifications')
          .delete()
          .eq('user_id', userId)
          .eq('status', 'pending');
      return true;
    } catch (_) {
      return false;
    }
  }
}
