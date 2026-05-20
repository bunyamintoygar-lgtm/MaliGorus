import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supabase/credit_service.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/survey_model.dart';
import '../../data/models/discussion_model.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/survey_repository.dart';
import '../../data/repositories/discussion_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/models/listing_model.dart';
import '../../data/repositories/listing_repository.dart';

class HomeState {
  final ProfileModel? profile;
  final List<SurveyModel> latestSurveys;
  final List<DiscussionModel> latestDiscussions;
  final List<DiscussionModel> latestConsultations;
  final List<ListingModel> latestListings;
  final List<Map<String, dynamic>> myReplies;
  final List<Map<String, dynamic>> unreadMessages;
  final List<Map<String, dynamic>> latestAnnouncements;

  HomeState({
    this.profile,
    this.latestSurveys = const [],
    this.latestDiscussions = const [],
    this.latestConsultations = const [],
    this.latestListings = const [],
    this.myReplies = const [],
    this.unreadMessages = const [],
    this.latestAnnouncements = const [],
  });

  // Toplam bildirim sayısı (Anasayfa badge için)
  int get totalNotifications => myReplies.length + unreadMessages.length + latestAnnouncements.length;
}

class HomeNotifier extends AsyncNotifier<HomeState> {
  @override
  FutureOr<HomeState> build() async {
    return _fetchData();
  }

  Future<HomeState> _fetchData() async {
    final profileRepo = ref.watch(profileRepositoryProvider);
    final surveyRepo = ref.watch(surveyRepositoryProvider);
    final discussionRepo = ref.watch(discussionRepositoryProvider);
    final chatRepo = ref.watch(chatRepositoryProvider);
    final listingRepo = ref.watch(listingRepositoryProvider);
    final creditService = ref.watch(creditServiceProvider);

    // Tüm verileri paralel olarak çek
    final results = await Future.wait([
      profileRepo.getMyProfile(),
      surveyRepo.getSurveys(to: 2, onlyActive: true), // Son 3 aktif anketi getir
      discussionRepo.getDiscussions('tartisma', pageSize: 5),
      discussionRepo.getMyTopicReplies(limit: 10),
      chatRepo.getUnreadMessageNotifications(),
      discussionRepo.getDiscussions('danisma', pageSize: 5),
      listingRepo.getListings(pageSize: 3),
      _fetchLatestAnnouncements(),
    ]);

    ProfileModel? profile = results[0] as ProfileModel?;

    // --- Seviye Kontrolü ve Düzeltme (Optimize Edildi) ---
    if (profile != null) {
      final newLevel = await creditService.checkAndSetHighestLevel(
        profile.id,
        currentBalance: profile.creditBalance,
        currentHighest: profile.highestLevel,
      );
      if (newLevel != null) {
        profile = profile.copyWith(highestLevel: newLevel);
      }
    }

    return HomeState(
      profile: profile,
      latestSurveys: results[1] as List<SurveyModel>,
      latestDiscussions: results[2] as List<DiscussionModel>,
      myReplies: results[3] as List<Map<String, dynamic>>,
      unreadMessages: results[4] as List<Map<String, dynamic>>,
      latestConsultations: results[5] as List<DiscussionModel>,
      latestListings: results[6] as List<ListingModel>,
      latestAnnouncements: results[7] as List<Map<String, dynamic>>,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchLatestAnnouncements() async {
    try {
      final response = await Supabase.instance.client
          .from('announcements')
          .select('*, author:profiles(full_name)')
          .order('created_at', ascending: false)
          .limit(3);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<void> loadHomeData() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchData());
  }
}

final homeProvider = AsyncNotifierProvider<HomeNotifier, HomeState>(() {
  return HomeNotifier();
});
