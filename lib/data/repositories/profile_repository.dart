import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../supabase/credit_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider((ref) {
  final creditService = ref.watch(creditServiceProvider);
  return ProfileRepository(creditService);
});

class ProfileRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final CreditService _creditService;

  ProfileRepository(this._creditService);

  Future<ProfileModel?> getMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return getProfile(userId);
  }

  Future<ProfileModel?> getProfile(String userId) async {
    final results = await Future.wait<dynamic>([
      _client.from('profiles').select().eq('id', userId).maybeSingle(),
      _client.from('discussions').count().eq('author_id', userId),
      _client.from('listings').count().eq('author_id', userId),
    ]);

    final profileData = results[0] as Map<String, dynamic>?;
    if (profileData == null) return null;

    final data = Map<String, dynamic>.from(profileData);
    data['discussion_count'] = results[1] as int? ?? 0;
    data['listing_count'] = results[2] as int? ?? 0;

    return ProfileModel.fromJson(data);
  }

  Future<void> updateProfile(ProfileModel profile) async {
    await _client
        .from('profiles')
        .update(profile.toJson())
        .eq('id', profile.id);
  }

  Future<void> requestVerification(String documentUrl) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('profiles').update({
      'verification_doc_url': documentUrl,
      'verification_status': 'pending',
    }).eq('id', userId);
  }

  Future<void> completeProfile({
    required String fullName,
    required String profession,
    required String companyName,
    String? avatarUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // Önce mevcut durumu kontrol et (Bonus daha önce verilmiş mi?)
    final currentProfile = await _client.from('profiles').select('profile_completed').eq('id', userId).maybeSingle();
    final wasCompleted = currentProfile?['profile_completed'] as bool? ?? false;

    // 1. Profili upsert et (Eğer yoksa oluşturur, varsa günceller)
    await _client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      'profession': profession,
      'company_name': companyName,
      'avatar_url': avatarUrl,
      'profile_completed': true,
    });

    // 2. Kredi bonusunu SADECE ilk kez tamamlanıyorsa ekle
    if (!wasCompleted) {
      await _creditService.processCreditAction(
        actionKey: 'welcome_bonus',
        description: 'Profil tamamlama bonusu',
      );
    }
  }

  Future<void> updateAvatar(String? avatarUrl) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('profiles').update({
      'avatar_url': avatarUrl,
    }).eq('id', userId);
  }
}
