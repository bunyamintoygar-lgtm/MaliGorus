import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/discussion_model.dart';
import '../supabase/credit_service.dart';

final discussionRepositoryProvider = Provider((ref) => DiscussionRepository(
  Supabase.instance.client,
  ref.read(creditServiceProvider),
));

class DiscussionRepository {
  final SupabaseClient _client;
  final CreditService _creditService;

  DiscussionRepository(this._client, this._creditService);

  // Tartışmaları Listele (Pagination destekli)
  Future<List<DiscussionModel>> getDiscussions(String type, {int page = 0, int pageSize = 20, String? searchQuery, String? category, String? status}) async {
    final userId = _client.auth.currentUser?.id;
    
    final from = page * pageSize;
    final to = from + pageSize - 1;

    // Temel sorgu
    dynamic query = _client
        .from('discussions')
        .select('*, profiles(full_name, profession, avatar_url, highest_level), reply_count:discussion_replies(count), is_liked:discussion_likes(count)')
        .eq('type', type)
        .neq('status', 'deleted')
        .eq('discussion_likes.user_id', userId ?? '');

    if (category != null && category != 'hepsi') {
      query = query.eq('category', category);
    }

    if (status != null && status != 'tumu') {
      if (status == 'yanitlandi') {
        query = query.or('status.eq.closed,is_resolved.eq.true');
      } else if (status == 'yanitlanmadi') {
        query = query.eq('status', 'active').eq('is_resolved', false);
      } else if (status == 'cevapladiklarim') {
        if (userId != null) {
          // Note: This requires a specific query or a join. 
          // For now, we will use a filter on discussion_replies if possible, 
          // but Supabase's PostgREST has limitations on filtering by related table count in a single go.
          // As a workaround, we'll try to filter where discussion_replies(author_id) equals userId.
          query = query.eq('discussion_replies.author_id', userId);
        }
      } else if (status == 'benimkiler') {
        if (userId != null) {
          query = query.eq('author_id', userId);
        }
      }
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      final lowerTr = q.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
      final upperTr = q.replaceAll('ı', 'I').replaceAll('i', 'İ').toUpperCase();
      final capTr = lowerTr.isNotEmpty ? lowerTr.replaceRange(0, 1, upperTr[0]) : lowerTr;
      
      final variations = {q, lowerTr, upperTr, capTr, q.toLowerCase(), q.toUpperCase()};
      // Hem başlık (title) hem içerik (body) içinde ara
      final orFilters = variations.map((v) => 'title.ilike.%$v%,body.ilike.%$v%').join(',');
      query = query.or(orFilters);
    }

    final response = await query
        .order('last_activity_at', ascending: false)
        .order('id', ascending: false)
        .range(from, to);
    final List list = response as List;

    if (list.isEmpty) return [];

    // Optimize: Tüm kapalı tartışmalar için cevap verenleri tek seferde çekelim
    final closedDiscussionIds = list
        .where((item) => item['status'] == 'closed')
        .map((item) => item['id'])
        .toList();

    Map<String, Set<String>> respondersMap = {};
    if (closedDiscussionIds.isNotEmpty && userId != null) {
      final allReplies = await _client
          .from('discussion_replies')
          .select('discussion_id, author_id')
          .filter('discussion_id', 'in', closedDiscussionIds);
      
      for (var reply in (allReplies as List)) {
        final dId = reply['discussion_id'] as String;
        final aId = reply['author_id'] as String;
        respondersMap.putIfAbsent(dId, () => {}).add(aId);
      }
    }

    final filteredList = list.where((item) {
      if (item['status'] != 'closed') return true;
      if (userId == null) return false;
      if (item['author_id'] == userId) return true;
      
      final responders = respondersMap[item['id']];
      return responders != null && responders.contains(userId);
    }).toList();

    return filteredList.map((e) => DiscussionModel.fromJson(e)).toList();
  }

  // Kullanıcıya ait Tartışmaları Listele
  Future<List<DiscussionModel>> getDiscussionsByUser(String authorId) async {
    final currentUserId = _client.auth.currentUser?.id;
    final response = await _client
        .from('discussions')
        .select('*, profiles(full_name, profession, avatar_url, highest_level), reply_count:discussion_replies(count), is_liked:discussion_likes(count)')
        .eq('author_id', authorId)
        .eq('discussion_likes.user_id', currentUserId ?? '')
        .neq('status', 'deleted')
        .order('created_at', ascending: false);

    final List list = response as List;
    return list.map((e) => DiscussionModel.fromJson(e)).toList();
  }

  // Anasayfa bildirim: Kullanıcının açtığı konulara gelen son cevapları getir
  Future<List<Map<String, dynamic>>> getMyTopicReplies({int limit = 10}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

      // Kullanıcının kendi konularına gelen, kendine ait olmayan cevaplar
      final response = await _client
          .from('discussion_replies')
          .select('*, discussions!inner(id, title, type, author_id), profiles(full_name, profession, avatar_url, highest_level)')
          .eq('discussions.author_id', userId)
          .neq('author_id', userId)
          .gte('created_at', sevenDaysAgo)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // Tartışma Detayı Getir
  Future<DiscussionModel?> getDiscussionById(String id) async {
    final userId = _client.auth.currentUser?.id;
    final response = await _client
        .from('discussions')
        .select('*, profiles(full_name, profession, avatar_url, highest_level), reply_count:discussion_replies(count), is_liked:discussion_likes(count)')
        .eq('id', id)
        .eq('discussion_likes.user_id', userId ?? '')
        .single();
    
    return DiscussionModel.fromJson(response);
  }

  // Tartışma Oluştur
  Future<bool> createDiscussion({
    required String type,
    required String title,
    required String body,
    String? category,
    bool isAnonymous = false,
    List<String> attachmentUrls = const [],
    bool isOffTopic = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    // 1. Kredi kontrolü ve düşümü yap
    final actionKey = type == 'danisma' ? 'consultation_ask' : 'discussion_create';
    final (amountProcessed, _) = await _creditService.processCreditAction(
      actionKey: actionKey,
      description: type == 'danisma' ? 'Danışma sorusu soruldu' : 'Tartışma konusu açıldı',
    );

    if (amountProcessed == null) return false;

    try {
      await _client.from('discussions').insert({
        'type': type,
        'author_id': userId,
        'title': title,
        'body': body,
        'category': category,
        'is_anonymous': isAnonymous,
        'attachment_urls': attachmentUrls,
        'is_off_topic': isOffTopic,
        'last_activity_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      // Hata durumunda iade işlemi eklenebilir (opsiyonel)
      return false;
    }
  }


  // Tartışma Güncelle
  Future<bool> updateDiscussion(String id, String title, String body, {String? category, List<String>? attachmentUrls}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final Map<String, dynamic> data = {
      'title': title,
      'body': body,
      'last_activity_at': DateTime.now().toIso8601String(),
    };
    if (category != null) data['category'] = category;
    if (attachmentUrls != null) data['attachment_urls'] = attachmentUrls;

    await _client
        .from('discussions')
        .update(data)
        .eq('id', id)
        .eq('author_id', userId);

    return true;
  }

  // Cevapları Getir
  Future<List<ReplyModel>> getReplies(String discussionId, {
    int? page, 
    int? pageSize,
    String sortBy = 'created_at',
    bool ascending = false,
  }) async {
    final userId = _client.auth.currentUser?.id;

    dynamic query = _client
        .from('discussion_replies')
        .select('*, profiles(full_name, profession, avatar_url, highest_level), is_liked:reply_likes(count)')
        .eq('discussion_id', discussionId)
        .eq('reply_likes.user_id', userId ?? '');

    query = query.order(sortBy, ascending: ascending);
        
    if (page != null && pageSize != null) {
      final from = page * pageSize;
      final to = from + pageSize - 1;
      query = query.range(from, to);
    }
    
    final response = await query;
    
    final List list = response as List;

    // Danışma ise gizlilik kuralını uygula
    final discData = await _client.from('discussions').select('type, author_id').eq('id', discussionId).single();
    final authorId = discData['author_id'];

    if (discData['type'] == 'danisma') {
      if (authorId != userId) {
        return list
            .where((e) => e['author_id'] == userId || e['author_id'] == authorId)
            .map((e) => ReplyModel.fromJson(e))
            .toList();
      }
    }

    return list.map((e) => ReplyModel.fromJson(e)).toList();
  }

  // Cevap Ver
  Future<(bool, int, String?)> addReply(String discussionId, String body, {String? parentId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return (false, 0, null);

    final discData = await _client.from('discussions').select('type, author_id').eq('id', discussionId).single();
    final isAuthor = discData['author_id'] == userId;

    if (discData['type'] == 'danisma') {
      final replies = await _client.from('discussion_replies').select('author_id').eq('discussion_id', discussionId).order('created_at', ascending: true);
      final List replyList = replies as List;
      
      if (isAuthor && replyList.isEmpty) return (false, 0, null);
      if (!isAuthor && replyList.isNotEmpty && replyList.last['author_id'] == userId) {
        return (false, 0, null);
      }
    }

    await _client.from('discussion_replies').insert({
      'discussion_id': discussionId,
      'author_id': userId,
      'body': body,
      'parent_id': parentId,
    });

    // Danışma ise ve 3. uzman cevabı ise konuyu kapat
    if (discData['type'] == 'danisma' && parentId == null && !isAuthor) {
      final expertReplies = await _client
          .from('discussion_replies')
          .select('id')
          .eq('discussion_id', discussionId)
          .neq('author_id', discData['author_id']) // Konu sahibi olmayanların cevapları
          .filter('parent_id', 'is', null);
      
      if ((expertReplies as List).length >= 3) {
        await _client.from('discussions').update({
          'status': 'closed',
          'last_activity_at': DateTime.now().toIso8601String(),
          'is_resolved': true,
        }).eq('id', discussionId);
      } else {
        await _client.from('discussions').update({
          'last_activity_at': DateTime.now().toIso8601String(),
          'is_resolved': false,
        }).eq('id', discussionId);
      }
    } else {
      await _client.from('discussions').update({
        'last_activity_at': DateTime.now().toIso8601String(),
      }).eq('id', discussionId);
    }

    // Kullanıcının bu tartışmaya daha önce cevap verip vermediğini kontrol et (Kredi ödülü için)
    final existingReply = await _client
        .from('discussion_replies')
        .select('id')
        .eq('discussion_id', discussionId)
        .eq('author_id', userId)
        .limit(2); // Mevcut cevabı da sayacağı için limit 2
    
    // insert sonrası kontrol ettiğimiz için en az 1 tane var. 
    // Eğer sadece 1 tane varsa, bu kullanıcının ilk cevabıdır.
    final bool isFirstReply = (existingReply as List).length <= 1;

    int earnedCredits = 0;
    String? newLevel;
    // Sadece ilk ana cevap (parentId == null) ve daha önce cevap vermemişse kredi ver
    if (parentId == null && isFirstReply) {
      if (discData['type'] == 'danisma') {
        final (amount, level) = await _creditService.processCreditAction(
          actionKey: 'consultation_reply', 
          description: 'Danışmaya cevap verildi',
          referenceId: discussionId,
        );
        earnedCredits = amount ?? 0;
        newLevel = level;
      } else {
        final (amount, level) = await _creditService.processCreditAction(
          actionKey: 'discussion_reply',
          description: 'Tartışmaya cevap verildi',
          referenceId: discussionId,
        );
        earnedCredits = amount ?? 0;
        newLevel = level;
      }
    }

    return (true, earnedCredits, newLevel);
  }

  // Cevap Güncelle
  Future<bool> updateReply(String replyId, String body) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    await _client
        .from('discussion_replies')
        .update({'body': body})
        .eq('id', replyId)
        .eq('author_id', userId);

    return true;
  }

  // Cevap Sil
  Future<(bool, bool)> deleteReply(String replyId, String discussionId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return (false, false);

      await _client.from('discussion_replies').delete().eq('id', replyId).eq('author_id', userId);
      return (true, false);
    } catch (e) {
      return (false, false);
    }
  }

  // Tartışmayı Kapat (Yayından Kaldır)
  Future<bool> closeDiscussion(String id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('discussions')
          .update({'status': 'closed'})
          .eq('id', id)
          .eq('author_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Tartışmayı Pasife Al (Cevap geldiğinde silmek yerine kullanılır)
  Future<bool> deactivateDiscussion(String id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('discussions')
          .update({'status': 'closed'})
          .eq('id', id)
          .eq('author_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Tartışmayı Aktife Al (Pasiften geri döndürmek için)
  Future<bool> activateDiscussion(String id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('discussions')
          .update({'status': 'active'})
          .eq('id', id)
          .eq('author_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Tartışmayı Sil
  Future<bool> deleteDiscussion(String id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _client
          .from('discussions')
          .delete()
          .eq('id', id)
          .eq('author_id', userId)
          .select();
      
      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Dosya Ekleme
  Future<void> updateAttachments(String id, List<String> urls) async {
    await _client.from('discussions').update({
      'attachment_urls': urls,
    }).eq('id', id);
  }
  
  // Beğeni İşlemi
  Future<bool> toggleLike(String discussionId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await _client.rpc('toggle_discussion_like', params: {
        'p_discussion_id': discussionId,
        'p_user_id': userId,
      });
      return response as bool;
    } catch (e) {
      return false;
    }
  }
  
  // Yanıt Beğeni İşlemi
  Future<bool> toggleReplyLike(String replyId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await _client.rpc('toggle_reply_like', params: {
        'p_reply_id': replyId,
        'p_user_id': userId,
      });
      return response as bool;
    } catch (e) {
      return false;
    }
  }

  // İzlenme Sayısını Artır
  Future<void> incrementViewCount(String discussionId) async {
    try {
      await _client.rpc('increment_discussion_view_count', params: {
        'p_discussion_id': discussionId,
      });
    } catch (e) {
      // Sessiz hata
    }
  }
}
