import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

final creditServiceProvider = Provider((ref) => CreditService());

final marketEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(creditServiceProvider);
  final enabled = await service.getConfigValue('market_enabled');
  return enabled ?? true;
});

class CreditService {
  final SupabaseClient _client = Supabase.instance.client;

  // app_config tablosundan güncel kredi fiyatlarını çeker
  Future<Map<String, dynamic>> getCreditPrices() async {
    final response = await _client
        .from('app_config')
        .select('value')
        .eq('key', 'credit_prices')
        .single();
    return response['value'] as Map<String, dynamic>;
  }

  // Genel konfigürasyon çeker
  Future<dynamic> getConfigValue(String key) async {
    try {
      final response = await _client
          .from('app_config')
          .select('value')
          .eq('key', key)
          .maybeSingle();
      return response?['value'];
    } catch (e) {
      return null;
    }
  }

  // Genel konfigürasyon günceller
  Future<bool> updateConfigValue(String key, dynamic value) async {
    try {
      await _client
          .from('app_config')
          .upsert({'key': key, 'value': value});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Kredi fiyatlarını günceller (Admin için)
  Future<bool> updateCreditPrices(Map<String, dynamic> prices) async {
    try {
      await _client
          .from('app_config')
          .update({'value': prices})
          .eq('key', 'credit_prices');
      return true;
    } catch (e) {
      return false;
    }
  }

  // Kredi harcama veya kazanma işlemi - İşlenen miktarı ve (varsa) yeni seviyeyi döndürür.
  Future<(int? amount, String? newLevel)> processCreditAction({
    required String actionKey,
    String? description,
    String? referenceId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return (null, null);

    try {
      // 1. Güncel fiyatı al
      final prices = await getCreditPrices();
      final int amount = prices[actionKey] ?? 0;

      // 2. Mevcut bakiyeyi kontrol et (Harcama ise)
      if (amount < 0) {
        final profile = await _client
            .from('profiles')
            .select('credit_balance')
            .eq('id', userId)
            .single();
        
        final currentBalance = profile['credit_balance'] as int;
        if (currentBalance < amount.abs()) {
          return (null, null); // Yetersiz bakiye
        }
      }

      // 3. RPC veya Transaction ile bakiyeyi güncelle (Atomik işlem)
      await _client.rpc('increment_credit', params: {
        'user_id': userId,
        'amount': amount,
      });

      // 4. Log oluştur
      await _client.from('credit_logs').insert({
        'user_id': userId,
        'amount': amount,
        'action': actionKey,
        'reference_id': referenceId,
        'description': description,
      });

      // 5. Seviye kontrolü (Eğer bakiye arttıysa)
      String? newLevel;
      if (amount > 0) {
        newLevel = await checkAndSetHighestLevel(userId);
      }

      return (amount, newLevel);
    } catch (e) {
      debugPrint('Credit Action Error: $e');
      return (null, null);
    }
  }

  /// Seviye kontrolü ve güncelleme.
  /// Eğer seviye atlanırsa yeni seviyenin key değerini döner, aksi halde null döner.
  Future<String?> checkAndSetHighestLevel(String userId, {int? currentBalance, String? currentHighest}) async {
    try {
      int balance = currentBalance ?? 0;
      String highest = (currentHighest ?? 'bronze').toString().toLowerCase();

      // 1. Eğer veriler eksikse veritabanından çek (Fall-back)
      if (currentBalance == null || currentHighest == null) {
        final profile = await _client
            .from('profiles')
            .select('credit_balance, highest_level')
            .eq('id', userId)
            .single();
        balance = profile['credit_balance'] ?? 0;
        highest = (profile['highest_level'] ?? 'bronze').toString().toLowerCase();
      }

      // 2. Seviye Belirleme (Kredi eşiklerine göre - Veritabanından dinamik olarak çekilir)
      String bestLevel = 'bronze';
      try {
        final levelConfig = await getConfigValue('level_config');
        if (levelConfig != null && levelConfig is List) {
          final List<dynamic> sortedLevelList = List.from(levelConfig)
            ..sort((a, b) {
              final int minA = a['min_credits'] ?? a['minCredits'] ?? 0;
              final int minB = b['min_credits'] ?? b['minCredits'] ?? 0;
              return minB.compareTo(minA);
            });

          for (var level in sortedLevelList) {
            final String k = (level['key'] ?? '').toString().toLowerCase();
            final int minCredits = level['min_credits'] ?? level['minCredits'] ?? 0;
            if (balance >= minCredits) {
              bestLevel = k;
              break;
            }
          }
        } else {
          if (balance >= 10000) {
            bestLevel = 'platin';
          } else if (balance >= 5000) {
            bestLevel = 'gold';
          } else if (balance >= 100) {
            bestLevel = 'silver';
          }
        }
      } catch (e) {
        debugPrint('Dinamik Seviye Hesaplanırken Hata Oluştu: $e');
        if (balance >= 10000) {
          bestLevel = 'platin';
        } else if (balance >= 5000) {
          bestLevel = 'gold';
        } else if (balance >= 100) {
          bestLevel = 'silver';
        }
      }

      // 3. Karşılaştırma (Sıralama: bronze < silver < gold < platin)
      const levels = ['bronze', 'silver', 'gold', 'platin'];
      
      // Normalize et (Türkçe karakterler veya farklı isimlendirmeler için)
      String normalizedHighest = highest;
      if (highest == 'bronz') normalizedHighest = 'bronze';
      if (highest == 'gümüş') normalizedHighest = 'silver';
      if (highest == 'altın') normalizedHighest = 'gold';
      if (highest == 'platinum') normalizedHighest = 'platin';

      final currentIndex = levels.indexOf(normalizedHighest);
      final newIndex = levels.indexOf(bestLevel);

      // Sadece daha üst bir seviyeye çıkıldıysa güncelle
      if (newIndex > currentIndex) {
        await _client
            .from('profiles')
            .update({'highest_level': bestLevel})
            .eq('id', userId);
        
        return bestLevel; // Yeni seviyeyi döndür
      }

      return null; // Değişiklik yok
    } catch (e) {
      debugPrint('Level Check Error: $e');
      return null;
    }
  }

  // Kullanıcıya kredi hediye et
  Future<bool> giftCredits({
    required String receiverId,
    required int amount,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null || senderId == receiverId) return false;

    try {
      // 1. Mevcut bakiyeyi kontrol et
      final profile = await _client
          .from('profiles')
          .select('credit_balance')
          .eq('id', senderId)
          .single();
      
      final currentBalance = profile['credit_balance'] as int;
      if (currentBalance < amount) return false;

      // 2. İşlemleri gerçekleştir (Atomik olması idealdir ama şimdilik seri yapıyoruz)
      // Gönderenden düş
      await _client.rpc('increment_credit', params: {
        'user_id': senderId,
        'amount': -amount,
      });

      // Alıcıya ekle
      await _client.rpc('increment_credit', params: {
        'user_id': receiverId,
        'amount': amount,
      });

      // 3. Log ve Hediye kaydı oluştur
      await _client.from('credit_logs').insert({
        'user_id': senderId,
        'amount': -amount,
        'action': 'gift_sent',
        'reference_id': receiverId,
        'description': 'Hediye gönderildi',
      });

      await _client.from('credit_gifts').insert({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'amount': amount,
        'is_viewed': false,
      });

      // Alıcı için seviye kontrolü
      await checkAndSetHighestLevel(receiverId);

      return true;
    } catch (e) {
      print('Hediye gönderme hatası: $e');
      return false;
    }
  }

  // Hediye geçmişini getir
  Future<List<Map<String, dynamic>>> getGiftLogs(String otherUserId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return [];

    final response = await _client
        .from('credit_gifts')
        .select()
        .eq('sender_id', myId)
        .eq('receiver_id', otherUserId)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Bekleyen hediyeleri getir (Anasayfa bildirimi için)
  Future<Map<String, dynamic>?> getPendingGift() async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return null;

    final response = await _client
        .from('credit_gifts')
        .select('*, sender:profiles!credit_gifts_sender_id_fkey(full_name, profession, avatar_url)')
        .eq('receiver_id', myId)
        .eq('is_viewed', false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    
    return response;
  }

  // Hediyeyi görüldü olarak işaretle
  Future<void> markGiftAsViewed(String giftId) async {
    await _client.from('credit_gifts').update({'is_viewed': true}).eq('id', giftId);
  }

  // Kredi istatistiklerini getir (Toplam kazanılan ve harcanan)
  Future<Map<String, int>> getCreditStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {'earned': 0, 'spent': 0};

    try {
      final response = await _client
          .from('credit_logs')
          .select('amount')
          .eq('user_id', userId);
      
      int earned = 0;
      int spent = 0;
      
      for (var row in response) {
        final amount = row['amount'] as int;
        if (amount > 0) {
          earned += amount;
        } else {
          spent += amount.abs();
        }
      }
      
      return {'earned': earned, 'spent': spent};
    } catch (e) {
      debugPrint('Get Credit Stats Error: $e');
      return {'earned': 0, 'spent': 0};
    }
  }
}

