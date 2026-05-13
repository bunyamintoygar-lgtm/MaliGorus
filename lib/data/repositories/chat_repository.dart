import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository());

class ChatRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Geçmiş mesajları sayfalı olarak getir (Lazy Loading)
  Future<List<Map<String, dynamic>>> getMessages(String otherUserId, {int page = 0, int pageSize = 20, String? searchQuery}) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return [];

    var query = _client.from('messages').select().or(
      'and(sender_id.eq.$myId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$myId)'
    );

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.ilike('body', '%${searchQuery.trim()}%');
    }

    final response = await query
        .order('created_at', ascending: false) // En yeni mesajlar en üstte (index 0) olacak
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  // Yeni gelen mesajları anlık dinleyen Realtime Channel
  RealtimeChannel subscribeToMessages(void Function(Map<String, dynamic> payload) onNewMessage) {
    return _client.channel('public:messages').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        onNewMessage(payload.newRecord);
      },
    ).subscribe();
  }

  // Mesaj Gönder
  Future<void> sendMessage(String receiverId, String body) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;

    await _client.from('messages').insert({
      'sender_id': myId,
      'receiver_id': receiverId,
      'body': body,
    });
  }

  // Sohbet Listesini Getir (Lazy Loading ve Arama destekli)
  Future<List<Map<String, dynamic>>> getChatList({int page = 0, int pageSize = 20, String? searchQuery}) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return [];

    final response = await _client.rpc('get_chat_list', params: {
      'p_user_id': myId,
      'p_search_query': searchQuery,
      'p_page': page,
      'p_page_size': pageSize,
    });
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Anasayfa bildirim: Okunmamış mesaj bildirimlerini getir (Mute ve Blok filtreli)
  Future<List<Map<String, dynamic>>> getUnreadMessageNotifications() async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      // 1. Sessize alınan ve Engellenen kullanıcıları al
      final mutedResponse = await _client.from('muted_users').select('muted_user_id');
      final blockedResponse = await _client.from('blocked_users').select('blocked_id');
      
      final mutedIds = List<String>.from(mutedResponse.map((r) => r['muted_user_id']));
      final blockedIds = List<String>.from(blockedResponse.map((r) => r['blocked_id']));
      final excludeIds = {...mutedIds, ...blockedIds};

      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

      // 2. Okunmamış mesajları getir
      final response = await _client
          .from('messages')
          .select('*, profiles!messages_sender_id_fkey(full_name, profession, avatar_url, highest_level)')
          .eq('receiver_id', myId)
          .eq('is_read', false)
          .gte('created_at', sevenDaysAgo)
          .order('created_at', ascending: false)
          .limit(50);

      // 3. Grupla ve Filtrele
      final Map<String, Map<String, dynamic>> grouped = {};
      for (final msg in response) {
        final senderId = msg['sender_id'] as String;
        
        // Filtre: Sessize alınan veya engellenen biriyse geç
        if (excludeIds.contains(senderId)) continue;

        if (!grouped.containsKey(senderId)) {
          grouped[senderId] = {
            ...msg,
            'unread_count': 1,
          };
        } else {
          grouped[senderId]!['unread_count'] = (grouped[senderId]!['unread_count'] as int) + 1;
        }
      }

      return grouped.values.toList();
    } catch (e) {
      print('Bildirim getirme hatası: $e');
      return [];
    }
  }

  // Sohbeti temizle (Sadece kendi ekranından kaldır)
  Future<bool> deleteChat(String otherUserId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return false;

    try {
      await _client.from('chat_clears').upsert({
        'user_id': myId,
        'partner_id': otherUserId,
        'cleared_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Sohbet temizleme hatası: $e');
      return false;
    }
  }

  // Temizleme tarihini getir
  Future<DateTime?> getChatClearDate(String otherUserId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return null;

    final response = await _client
        .from('chat_clears')
        .select('cleared_at')
        .eq('partner_id', otherUserId)
        .maybeSingle();
    
    if (response != null && response['cleared_at'] != null) {
      return DateTime.parse(response['cleared_at'] as String).toUtc();
    }
    return null;
  }


  // Tüm temizleme tarihlerini getir
  Future<Map<String, DateTime>> getChatClearDates() async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return {};

    final response = await _client
        .from('chat_clears')
        .select('partner_id, cleared_at');
    
    final Map<String, DateTime> result = {};
    for (var row in response) {
      if (row['partner_id'] != null && row['cleared_at'] != null) {
        result[row['partner_id'] as String] = DateTime.parse(row['cleared_at'] as String).toUtc();
      }
    }
    return result;
  }

  // Engellenen kullanıcıları getir
  Future<List<String>> getBlockedUserIds() async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return [];
    
    final response = await _client
        .from('blocked_users')
        .select('blocked_id');
    
    return List<String>.from(response.map((row) => row['blocked_id'] as String));
  }

  // Kullanıcıyı engelle
  Future<bool> blockUser(String userId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return false;

    try {
      await _client.from('blocked_users').upsert({
        'blocker_id': myId,
        'blocked_id': userId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Engeli kaldır
  Future<bool> unblockUser(String userId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return false;

    try {
      await _client.from('blocked_users').delete().match({
        'blocker_id': myId,
        'blocked_id': userId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  // Kullanıcı sessize alınmış mı kontrol et
  Future<bool> isUserMuted(String userId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return false;

    final response = await _client
        .from('muted_users')
        .select()
        .match({'user_id': myId, 'muted_user_id': userId})
        .maybeSingle();
    
    return response != null;
  }

  // Kullanıcıyı sessize al
  Future<bool> muteUser(String userId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return false;

    try {
      await _client.from('muted_users').upsert({
        'user_id': myId,
        'muted_user_id': userId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Sessizden çıkar
  Future<bool> unmuteUser(String userId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return false;

    try {
      await _client.from('muted_users').delete().match({
        'user_id': myId,
        'muted_user_id': userId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  // Mesajları okundu olarak işaretle
  Future<void> markMessagesAsRead(String senderId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      await _client
          .from('messages')
          .update({'is_read': true})
          .match({
            'sender_id': senderId,
            'receiver_id': myId,
            'is_read': false,
          });
    } catch (e) {
      print('Okundu işaretleme hatası: $e');
    }
  }
  // Engellenmiş kullanıcıları getir
  Future<List<Map<String, dynamic>>> getBlockedUsers({
    String? searchQuery,
    int page = 0,
    int pageSize = 20,
  }) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      final response = await _client.rpc('get_blocked_users_list', params: {
        'p_user_id': myId,
        'p_search_query': searchQuery,
        'p_page': page,
        'p_page_size': pageSize,
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Engellenmiş kullanıcıları getirme hatası: $e');
      return [];
    }
  }
}
