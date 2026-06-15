import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final followerRepositoryProvider = Provider((ref) => FollowerRepository());

class FollowerRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> followUser(String targetUserId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return;
    if (currentUserId == targetUserId) return; // Self-following is blocked by DB check but client-side safeguard is good

    await _client.from('user_follows').insert({
      'follower_id': currentUserId,
      'following_id': targetUserId,
    });
  }

  Future<void> unfollowUser(String targetUserId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return;

    await _client.from('user_follows').delete().match({
      'follower_id': currentUserId,
      'following_id': targetUserId,
    });
  }

  Future<bool> isFollowing(String targetUserId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;

    final response = await _client
        .from('user_follows')
        .select('follower_id')
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId)
        .maybeSingle();

    return response != null;
  }

  Future<int> getFollowersCount(String userId) async {
    return _client
        .from('user_follows')
        .count()
        .eq('following_id', userId);
  }

  Future<int> getFollowingCount(String userId) async {
    return _client
        .from('user_follows')
        .count()
        .eq('follower_id', userId);
  }

  /// Retrieves list of profiles that follow [userId]
  Future<List<ProfileModel>> getFollowersList(String userId) async {
    final response = await _client
        .from('user_follows')
        .select('follower:profiles!user_follows_follower_id_fkey(*)')
        .eq('following_id', userId);

    final list = response as List<dynamic>;
    final result = <ProfileModel>[];
    for (var item in list) {
      if (item is Map && item['follower'] != null) {
        final profileData = Map<String, dynamic>.from(item['follower']);
        result.add(ProfileModel.fromJson(profileData));
      }
    }
    return result;
  }

  /// Retrieves list of profiles that [userId] follows
  Future<List<ProfileModel>> getFollowingList(String userId) async {
    final response = await _client
        .from('user_follows')
        .select('following:profiles!user_follows_following_id_fkey(*)')
        .eq('follower_id', userId);

    final list = response as List<dynamic>;
    final result = <ProfileModel>[];
    for (var item in list) {
      if (item is Map && item['following'] != null) {
        final profileData = Map<String, dynamic>.from(item['following']);
        result.add(ProfileModel.fromJson(profileData));
      }
    }
    return result;
  }

  /// Retrieves paginated list of profiles that follow [userId]
  Future<List<ProfileModel>> getFollowersListPaginated({
    required String userId,
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortBy,
  }) async {
    dynamic query = _client.from('profiles').select('*, user_follows!user_follows_follower_id_fkey!inner()');
    query = query.eq('user_follows.following_id', userId);

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final normalized = _turkishNormalize(searchQuery.trim());
      query = query.or('full_name.ilike.%$normalized%,profession.ilike.%$normalized%');
    }

    bool asc = true;
    String sortCol = 'full_name';
    if (sortBy == 'name_desc') {
      asc = false;
    } else if (sortBy == 'newest') {
      sortCol = 'created_at';
      asc = false;
    }
    query = query.order(sortCol, ascending: asc);

    final from = page * pageSize;
    final to = from + pageSize - 1;
    query = query.range(from, to);

    final response = await query;
    final list = response as List<dynamic>;
    
    var result = list.map((item) => ProfileModel.fromJson(Map<String, dynamic>.from(item))).toList();

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final searchLower = _turkishToLower(searchQuery.trim());
      result = result.where((p) {
        final nameLower = _turkishToLower(p.fullName ?? '');
        final professionLower = _turkishToLower(p.profession ?? '');
        return nameLower.contains(searchLower) || professionLower.contains(searchLower);
      }).toList();
    }

    return result;
  }

  /// Retrieves paginated list of profiles that [userId] follows
  Future<List<ProfileModel>> getFollowingListPaginated({
    required String userId,
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortBy,
  }) async {
    dynamic query = _client.from('profiles').select('*, user_follows!user_follows_following_id_fkey!inner()');
    query = query.eq('user_follows.follower_id', userId);

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final normalized = _turkishNormalize(searchQuery.trim());
      query = query.or('full_name.ilike.%$normalized%,profession.ilike.%$normalized%');
    }

    bool asc = true;
    String sortCol = 'full_name';
    if (sortBy == 'name_desc') {
      asc = false;
    } else if (sortBy == 'newest') {
      sortCol = 'created_at';
      asc = false;
    }
    query = query.order(sortCol, ascending: asc);

    final from = page * pageSize;
    final to = from + pageSize - 1;
    query = query.range(from, to);

    final response = await query;
    final list = response as List<dynamic>;
    
    var result = list.map((item) => ProfileModel.fromJson(Map<String, dynamic>.from(item))).toList();

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final searchLower = _turkishToLower(searchQuery.trim());
      result = result.where((p) {
        final nameLower = _turkishToLower(p.fullName ?? '');
        final professionLower = _turkishToLower(p.profession ?? '');
        return nameLower.contains(searchLower) || professionLower.contains(searchLower);
      }).toList();
    }

    return result;
  }

  static String _turkishToLower(String input) {
    return input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ç', 'ç')
        .replaceAll('Ü', 'ü')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ğ', 'ğ')
        .toLowerCase();
  }

  static String _turkishNormalize(String input) {
    return input
        .replaceAll('İ', '_')
        .replaceAll('ı', '_')
        .replaceAll('I', '_')
        .replaceAll('i', '_');
  }
}
