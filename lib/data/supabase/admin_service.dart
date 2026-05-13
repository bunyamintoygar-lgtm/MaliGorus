import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Dashboard istatistikleri
  Future<Map<String, int>> getStats() async {
    try {
      final results = await Future.wait([
        _client.from('profiles').select('id').count(CountOption.exact).then((v) => v.count),
        _client.from('discussions').select('id').count(CountOption.exact).then((v) => v.count),
        _client.from('listings').select('id').count(CountOption.exact).then((v) => v.count),
        _client.from('user_reports').select('id').eq('status', 'pending').count(CountOption.exact).then((v) => v.count),
      ]);
      return {
        'users': results[0],
        'discussions': results[1],
        'listings': results[2],
        'pending_reports': results[3],
      };
    } catch (e) {
      print('Admin stats hatası: $e');
      return {'users': 0, 'discussions': 0, 'listings': 0, 'pending_reports': 0};
    }
  }

  /// Son 7 günlük kullanıcı kayıt istatistikleri
  Future<List<Map<String, dynamic>>> getUserGrowth() async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 6));
      
      final response = await _client
          .from('profiles')
          .select('created_at')
          .gte('created_at', sevenDaysAgo.toIso8601String())
          .order('created_at');

      // Günlere göre grupla
      final Map<String, int> dailyCounts = {};
      for (int i = 0; i < 7; i++) {
        final date = sevenDaysAgo.add(Duration(days: i));
        final key = '${date.day}.${date.month}';
        dailyCounts[key] = 0;
      }

      for (final row in response) {
        final date = DateTime.parse(row['created_at']);
        final key = '${date.day}.${date.month}';
        dailyCounts[key] = (dailyCounts[key] ?? 0) + 1;
      }

      return dailyCounts.entries
          .map((e) => {'date': e.key, 'count': e.value})
          .toList();
    } catch (e) {
      print('Growth stats hatası: $e');
      return [];
    }
  }

  /// Kullanıcıları sayfalı getir (lazy loading)
  static const int usersPageSize = 20;

  Future<List<Map<String, dynamic>>> getAllUsers({
    String? search,
    int page = 0,
    String sortBy = 'created_at',  // 'created_at' | 'credit_balance'
    bool sortAsc = false,
    String? profession,            // 'mali_musavir' | 'muhasebe_uzmani' | 'ymm' | null
  }) async {
    var query = _client.from('profiles').select();
    
    // Unvan filtresi
    if (profession != null && profession.isNotEmpty) {
      query = query.eq('profession', profession);
    }
    
    // Arama — Supabase ilike + Türkçe karakter dönüşümü
    if (search != null && search.isNotEmpty) {
      // Türkçe karakter dönüşümleri ile arama
      final normalizedSearch = _turkishNormalize(search);
      query = query.ilike('full_name', '%$normalizedSearch%');
    }
    
    final from = page * usersPageSize;
    final to = from + usersPageSize - 1;
    
    final response = await query
        .order(sortBy, ascending: sortAsc)
        .range(from, to);
    
    var results = List<Map<String, dynamic>>.from(response);
    
    // Client-side Türkçe karakter duyarlı ek filtre
    if (search != null && search.isNotEmpty) {
      final searchLower = _turkishToLower(search);
      results = results.where((user) {
        final name = _turkishToLower(user['full_name']?.toString() ?? '');
        return name.contains(searchLower);
      }).toList();
    }
    
    return results;
  }

  /// Türkçe küçük harfe çevirme (İ→i, I→ı, Ş→ş, Ç→ç, Ü→ü, Ö→ö, Ğ→ğ)
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

  /// Supabase ilike için normalize (Türkçe özel karakterleri _ ile değiştir)
  static String _turkishNormalize(String input) {
    // ilike Türkçe'yi düzgün handle edemeyebilir, geniş arama yapalım
    return input
        .replaceAll('İ', '_')
        .replaceAll('ı', '_')
        .replaceAll('I', '_')
        .replaceAll('i', '_');
  }

  /// Kullanıcıyı admin yap/kaldır
  Future<bool> toggleAdmin(String userId, bool makeAdmin) async {
    try {
      await _client.from('profiles').update({'is_admin': makeAdmin}).eq('id', userId);
      return true;
    } catch (e) {
      print('Admin toggle hatası: $e');
      return false;
    }
  }

  /// Kullanıcı üyeliğini sonlandır (ban)
  Future<bool> banUser(String userId) async {
    try {
      await _client.from('profiles').update({
        'is_banned': true,
        'banned_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
      return true;
    } catch (e) {
      print('Ban hatası: $e');
      return false;
    }
  }

  /// Kullanıcı banını kaldır
  Future<bool> unbanUser(String userId) async {
    try {
      await _client.from('profiles').update({
        'is_banned': false,
        'banned_at': null,
      }).eq('id', userId);
      return true;
    } catch (e) {
      print('Unban hatası: $e');
      return false;
    }
  }

  /// Kullanıcının moderasyon durumunu sıfırlar (Admin)
  Future<bool> clearModerationStrike(String userId) async {
    try {
      await _client.from('profiles').update({
        'moderation_strike_count': 0,
        'temp_blocked_until': null,
        'moderation_block_count_today': 0,
        'is_indefinite_blocked': false,
        'is_appeal_pending': false,
        'appeal_explanation': null,
      }).eq('id', userId);
      return true;
    } catch (e) {
      print('Moderasyon sıfırlama hatası: $e');
      return false;
    }
  }


  /// Tüm ilanları getir (admin)
  Future<List<Map<String, dynamic>>> getAllListings() async {
    final response = await _client
        .from('listings')
        .select('*, author:profiles!listings_author_id_fkey(full_name, avatar_url)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// İlanı sil (Admin)
  Future<bool> deleteListing(String listingId) async {
    try {
      await _client.from('listings').delete().eq('id', listingId);
      return true;
    } catch (e) {
      print('İlan silme hatası: $e');
      return false;
    }
  }

  /// Tartışmayı sil (Admin)
  Future<bool> deleteDiscussion(String id) async {
    try {
      await _client.from('discussions').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Tartışma silme hatası: $e');
      return false;
    }
  }

  /// Cevabı sil (Admin)
  Future<bool> deleteReply(String id) async {
    try {
      await _client.from('discussion_replies').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Cevap silme hatası: $e');
      return false;
    }
  }

  /// Anketi sil (Admin)
  Future<bool> deleteSurvey(String id) async {
    try {
      await _client.from('surveys').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Anket silme hatası: $e');
      return false;
    }
  }

  /// Duyuru gönder (app_config'e kaydet)
  Future<bool> sendAnnouncement({required String title, required String body}) async {
    try {
      await _client.from('announcements').insert({
        'title': title,
        'body': body,
        'author_id': _client.auth.currentUser!.id,
      });
      return true;
    } catch (e) {
      print('Duyuru gönderme hatası: $e');
      return false;
    }
  }

  /// Şikayetleri getir (Sayfalı ve Filtreli)
  Future<List<Map<String, dynamic>>> getReports({
    int page = 0,
    int limit = 20,
    String? status,
  }) async {
    try {
      var query = _client
          .from('user_reports')
          .select('*, reporter:profiles!user_reports_reporter_id_fkey(full_name, avatar_url), reported:profiles!user_reports_reported_id_fkey(full_name, avatar_url)');

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      final from = page * limit;
      final to = from + limit - 1;
      
      final response = await query
          .order('created_at', ascending: false)
          .range(from, to);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Şikayet getirme hatası: $e');
      return [];
    }
  }

  /// Duyuruları getir
  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    try {
      final response = await _client
          .from('announcements')
          .select('*, author:profiles!announcements_author_id_fkey(full_name)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Duyuru getirme hatası: $e');
      return [];
    }
  }

  /// Duyuru sil
  Future<bool> deleteAnnouncement(String id) async {
    try {
      await _client.from('announcements').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Politika kaydet/güncelle
  Future<bool> savePolicy({required String key, required String content}) async {
    try {
      // Upsert: varsa güncelle, yoksa oluştur
      await _client.from('app_config').upsert({
        'key': key,
        'value': {'content': content},
      }, onConflict: 'key');
      return true;
    } catch (e) {
      print('Politika kaydetme hatası: $e');
      return false;
    }
  }

  /// Politika getir
  Future<String> getPolicy(String key) async {
    try {
      final response = await _client
          .from('app_config')
          .select('value')
          .eq('key', key)
          .maybeSingle();
      if (response != null) {
        final value = response['value'];
        if (value is Map) return value['content'] ?? '';
        return value?.toString() ?? '';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  /// SSS (FAQ) listesini getir
  Future<List<Map<String, String>>> getFaqs() async {
    try {
      final response = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'faqs')
          .maybeSingle();

      if (response == null) return [];
      
      final dynamic value = response['value'];
      final List<dynamic> faqsJson = (value is Map && value.containsKey('items')) 
          ? value['items'] 
          : [];
          
      return faqsJson.map((f) => {
        'q': f['q']?.toString() ?? '',
        'a': f['a']?.toString() ?? '',
      }).toList();
    } catch (e) {
      print('SSS getirme hatası: $e');
      return [];
    }
  }

  /// SSS (FAQ) listesini kaydet
  Future<bool> saveFaqs(List<Map<String, String>> faqs) async {
    try {
      await _client.from('app_config').upsert({
        'key': 'faqs',
        'value': {'items': faqs},
      }, onConflict: 'key');
      return true;
    } catch (e) {
      print('SSS kaydetme hatası: $e');
      return false;
    }
  }

  /// Destek taleplerini getir (Sayfalı ve Kullanıcı bilgileriyle birlikte)
  Future<List<Map<String, dynamic>>> getSupportRequests({
    int page = 0,
    int limit = 20,
    String? status,
    String? searchQuery,
  }) async {
    try {
      var query = _client
          .from('support_requests')
          .select('*, profiles(full_name, profession)');

      // Filtreler
      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('subject.ilike.%$searchQuery%,profiles.full_name.ilike.%$searchQuery%');
      }

      final from = page * limit;
      final to = from + limit - 1;

      final response = await query
          .order('created_at', ascending: false)
          .range(from, to);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Destek talepleri getirme hatası: $e');
      return [];
    }
  }

  /// Destek talebi durumunu güncelle
  Future<bool> updateSupportRequestStatus(String requestId, String status) async {
    try {
      await _client
          .from('support_requests')
          .update({'status': status})
          .eq('id', requestId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
