import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final referralRepositoryProvider = Provider((ref) => ReferralRepository());

class ReferralRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Kullanıcının referans kodunu getir
  Future<String?> getMyReferralCode() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('profiles')
        .select('referral_code')
        .eq('id', userId)
        .single();

    return response['referral_code'] as String?;
  }

  // Arkadaşını öner (manuel form)
  Future<bool> referFriend({
    required String name,
    String? email,
    String? phone,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final referralCode = await getMyReferralCode();
      if (referralCode == null) return false;

      await _client.from('referrals').insert({
        'referrer_id': userId,
        'referral_code': referralCode,
        'candidate_name': name,
        'candidate_email': email,
        'candidate_phone': phone,
        'source': 'manual',
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Landing page'den aday kaydı (AUTH GEREKTİRMEZ — RPC kullanır)
  Future<Map<String, dynamic>> registerCandidate({
    required String referralCode,
    required String name,
    required String profession,
    required String email,
  }) async {
    try {
      final response = await _client.rpc('register_referral_candidate', params: {
        'p_referral_code': referralCode,
        'p_candidate_name': name,
        'p_candidate_profession': profession,
        'p_candidate_email': email,
      });

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': 'Bir hata oluştu: $e'};
    }
  }

  // Referans kodu ile profil bilgisini getir (AUTH GEREKTİRMEZ)
  Future<Map<String, dynamic>?> getReferralProfile(String referralCode) async {
    try {
      final response = await _client.rpc('get_referral_profile', params: {
        'p_referral_code': referralCode,
      });

      final data = Map<String, dynamic>.from(response as Map);
      if (data['success'] == true) return data;
      return null;
    } catch (e) {
      return null;
    }
  }

  // Referanslarımı listele
  Future<List<Map<String, dynamic>>> getMyReferrals() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('referrals')
        .select()
        .eq('referrer_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Uygulama yorumu kaydet
  Future<bool> submitReview({
    required String text,
    required int rating,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      await _client.from('user_reviews').upsert({
        'user_id': userId,
        'review_text': text,
        'rating': rating,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Mevcut yorumumu getir
  Future<Map<String, dynamic>?> getMyReview() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('user_reviews')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }
}
