import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/survey_model.dart';
import '../supabase/credit_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final surveyRepositoryProvider = Provider((ref) {
  final creditService = ref.watch(creditServiceProvider);
  return SurveyRepository(creditService);
});

class SurveyRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final CreditService _creditService;

  SurveyRepository(this._creditService);

  // Aktif anketleri getir (Arama ve Sayfalama destekli)
  Future<List<SurveyModel>> getSurveys({
    String? search, 
    int from = 0, 
    int to = 14, 
    bool onlyActive = false,
    String? authorId,
    List<String>? votedIds,
    bool? onlyVoted,
    bool? onlyUnvoted,
  }) async {
    var query = _client
        .from('surveys')
        .select('*, profiles(full_name, profession, highest_level)')
        .eq('status', 'active');

    if (onlyActive) {
      query = query.gt('expires_at', DateTime.now().toIso8601String());
    }
    
    if (authorId != null) {
      query = query.eq('author_id', authorId);
    }

    if (onlyVoted == true && votedIds != null) {
      if (votedIds.isEmpty) return [];
      query = query.filter('id', 'in', votedIds);
    }

    if (onlyUnvoted == true && votedIds != null && votedIds.isNotEmpty) {
      query = query.not('id', 'in', '(${votedIds.join(",")})');
    }
    
    if (search != null && search.isNotEmpty) {
      query = query.ilike('title', '%$search%');
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(from, to);
    
    return (response as List).map((e) => SurveyModel.fromJson(e)).toList();
  }

  // Tek bir anketi getir
  Future<SurveyModel?> getSurvey(String id) async {
    final response = await _client
        .from('surveys')
        .select('*, profiles(full_name, profession, highest_level)')
        .eq('id', id)
        .single();
    
    return SurveyModel.fromJson(response);
  }

  // Anasayfa için son yayınlanan aktif anketi getir
  Future<SurveyModel?> getLatestSurvey() async {
    final response = await _client
        .from('surveys')
        .select('*, profiles(full_name, profession, highest_level)')
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1);

    final list = response as List;
    if (list.isEmpty) return null;
    return SurveyModel.fromJson(list.first);
  }

  // Anket oluştur
  Future<bool> createSurvey({
    required String title,
    String? description,
    required List<String> options,
    required DateTime expiresAt,
    bool isOffTopic = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    // 1. Kredi harca (Anket oluşturma maliyeti)
    final (amountProcessed, _) = await _creditService.processCreditAction(
      actionKey: 'survey_create',
      description: 'Yeni anket oluşturma: $title',
    );

    if (amountProcessed == null) return false; // Yetersiz bakiye

    // 2. Anketi kaydet
    int optionIndex = 0;
    final optionModels = options.map((opt) {
      final id = "${DateTime.now().microsecondsSinceEpoch}_${optionIndex++}";
      return {
        'id': id,
        'text': opt,
        'votes': 0
      };
    }).toList();

    await _client.from('surveys').insert({
      'author_id': userId,
      'title': title,
      'description': description,
      'options': optionModels,
      'expires_at': expiresAt.toIso8601String(),
      'is_off_topic': isOffTopic,
    });

    return true;
  }


  // Ankete oy ver (RPC ile atomik işlem)
  Future<bool> voteSurvey(SurveyModel survey, String optionId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    // Süre kontrolü
    if (survey.isExpired) return false;

    try {
      final result = await _client.rpc('vote_survey', params: {
        'p_survey_id': survey.id,
        'p_option_id': optionId,
      });

      if (result == true) {
        // Kredi kazandır (Anket oylama ödülü)
        await _creditService.processCreditAction(
          actionKey: 'survey_vote',
          description: 'Anket oylama ödülü',
          referenceId: survey.id,
        );
        return true;
      }
      return false; // Muhtemelen zaten oy kullanmış
    } catch (e) {
      return false;
    }
  }

  // Kullanıcının oy verdiği anketleri getir: {surveyId: optionId}
  Future<Map<String, String>> getMyVotes() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    try {
      final response = await _client
          .from('survey_votes')
          .select('survey_id, option_id')
          .eq('user_id', userId);

      final Map<String, String> votes = {};
      for (final row in response) {
        votes[row['survey_id']] = row['option_id'];
      }
      return votes;
    } catch (e) {
      return {};
    }
  }

  // Anketi sil (Sadece yazar ve hiç oy yoksa)
  Future<bool> deleteSurvey(String surveyId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await _client.from('survey_votes').select('id').eq('survey_id', surveyId).limit(1);
      if ((response as List).isNotEmpty) return false;

      await _client.from('surveys').delete().eq('id', surveyId).eq('author_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Anketi güncelle (Sadece yazar ve hiç oy yoksa)
  Future<bool> updateSurvey({
    required String surveyId,
    required String title,
    String? description,
    required List<String> options,
    required DateTime expiresAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await _client.from('survey_votes').select('id').eq('survey_id', surveyId).limit(1);
      if ((response as List).isNotEmpty) return false;

      int optionIndex = 0;
      final optionModels = options.map((opt) {
        final id = "${DateTime.now().microsecondsSinceEpoch}_${optionIndex++}";
        return {'id': id, 'text': opt, 'votes': 0};
      }).toList();

      await _client.from('surveys').update({
        'title': title,
        'description': description,
        'options': optionModels,
        'expires_at': expiresAt.toIso8601String(),
      }).eq('id', surveyId).eq('author_id', userId);

      return true;
    } catch (e) {
      return false;
    }
  }
}
