import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/supabase/credit_service.dart';

class CreditLogsState {
  final List<Map<String, dynamic>> logs;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String filter; // 'all', 'earn', 'spend'
  final String? categoryFilter; // 'discussion', 'consultation', 'message', 'survey', etc.
  final int offset;

  CreditLogsState({
    required this.logs,
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.filter = 'all',
    this.categoryFilter,
    this.offset = 0,
  });

  CreditLogsState copyWith({
    List<Map<String, dynamic>>? logs,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? filter,
    String? categoryFilter,
    int? offset,
  }) {
    return CreditLogsState(
      logs: logs ?? this.logs,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      filter: filter ?? this.filter,
      categoryFilter: categoryFilter ?? this.categoryFilter,
      offset: offset ?? this.offset,
    );
  }
}

class CreditLogsNotifier extends Notifier<CreditLogsState> {
  @override
  CreditLogsState build() {
    // İlk yüklemeyi başlat
    Future.microtask(() => loadLogs());
    return CreditLogsState(logs: []);
  }

  Future<void> loadLogs({bool isRefresh = true}) async {
    if (isRefresh) {
      state = state.copyWith(loading: true, offset: 0, logs: [], hasMore: true);
    } else {
      state = state.copyWith(loadingMore: true);
    }

    try {
      final client = Supabase.instance.client;
      var query = client.from('credit_logs').select();

      // Filtrele: Kazanç/Harcama
      if (state.filter == 'earn') {
        query = query.gt('amount', 0);
      } else if (state.filter == 'spend') {
        query = query.lt('amount', 0);
      }

      // Filtrele: Kategori
      if (state.categoryFilter != null) {
        final List<String> actions = _getActionsForCategory(state.categoryFilter!);
        if (actions.isNotEmpty) {
          query = query.filter('action', 'in', actions);
        }
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(state.offset, state.offset + 49);

      final newLogs = List<Map<String, dynamic>>.from(response);

      state = state.copyWith(
        logs: isRefresh ? newLogs : [...state.logs, ...newLogs],
        loading: false,
        loadingMore: false,
        offset: state.offset + newLogs.length,
        hasMore: newLogs.length == 50,
      );
    } catch (e) {
      state = state.copyWith(loading: false, loadingMore: false);
    }
  }

  List<String> _getActionsForCategory(String category) {
    switch (category) {
      case 'discussion':
        return ['discussion_reply', 'discussion_create'];
      case 'consultation':
        return ['consultation_reply', 'consultation_ask'];
      case 'message':
        return ['chat_message'];
      case 'survey':
        return ['survey_vote', 'survey_create'];
      case 'listing':
        return ['listing_create'];
      case 'referral':
        return ['friend_referral', 'link_referral'];
      case 'other':
        return ['app_review', 'profile_completion', 'system_bonus'];
      default:
        return [];
    }
  }

  void setFilter(String filter) {
    if (state.filter == filter && state.categoryFilter == null) return;
    state = state.copyWith(filter: filter, categoryFilter: null);
    loadLogs();
  }

  void setCategoryFilter(String? category) {
    if (state.categoryFilter == category) return;
    state = state.copyWith(categoryFilter: category);
    loadLogs();
  }
}

final creditLogsProvider = NotifierProvider<CreditLogsNotifier, CreditLogsState>(() {
  return CreditLogsNotifier();
});

final creditStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final service = ref.watch(creditServiceProvider);
  return service.getCreditStats();
});
