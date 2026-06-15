import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/level_badge.dart';
import '../../core/widgets/profession_label.dart';
import '../../core/utils/name_formatter.dart';

class ParticipantData {
  final String id;
  final String? fullName;
  final String? profession;
  final String? avatarUrl;
  final String highestLevel;
  final bool isVerified;
  final String role;
  final int discussionCount;
  final int consultationCount;
  final int surveyCount;
  final DateTime? createdAt;

  ParticipantData({
    required this.id,
    this.fullName,
    this.profession,
    this.avatarUrl,
    required this.highestLevel,
    required this.isVerified,
    required this.role,
    required this.discussionCount,
    required this.consultationCount,
    required this.surveyCount,
    this.createdAt,
  });
}

class ParticipantsState {
  final List<ParticipantData> allParticipants;
  final List<ParticipantData> participants;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final int offset;
  final String searchQuery;

  ParticipantsState({
    required this.allParticipants,
    required this.participants,
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.offset = 0,
    this.searchQuery = '',
  });

  ParticipantsState copyWith({
    List<ParticipantData>? allParticipants,
    List<ParticipantData>? participants,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    int? offset,
    String? searchQuery,
  }) {
    return ParticipantsState(
      allParticipants: allParticipants ?? this.allParticipants,
      participants: participants ?? this.participants,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ParticipantsNotifier extends Notifier<ParticipantsState> {
  @override
  ParticipantsState build() {
    Future.microtask(() => loadParticipants(isRefresh: true, forceFetch: true));
    return ParticipantsState(participants: [], allParticipants: []);
  }

  Future<void> loadParticipants({bool isRefresh = true, bool forceFetch = false}) async {
    if (isRefresh) {
      state = state.copyWith(loading: true, offset: 0, participants: [], hasMore: true);
    } else {
      if (!state.hasMore || state.loadingMore || state.loading) return;
      state = state.copyWith(loadingMore: true);
    }

    try {
      final limit = 15;
      List<ParticipantData> allLoaded = state.allParticipants;

      // Only fetch from Supabase if we force fetch or if cache is empty
      if (forceFetch || allLoaded.isEmpty) {
        final client = Supabase.instance.client;
        final response = await client.from('profiles').select('''
          id,
          full_name,
          profession,
          avatar_url,
          highest_level,
          is_verified,
          role,
          is_banned,
          profile_completed,
          created_at,
          discussions(id, type),
          discussion_replies(discussion_id, discussions(type)),
          survey_votes(survey_id)
        ''')
        .eq('is_banned', false)
        .eq('profile_completed', true);

        final List list = response as List;
        final parsed = list.map((item) {
          final discussions = item['discussions'] as List<dynamic>? ?? [];
          final replies = item['discussion_replies'] as List<dynamic>? ?? [];
          final surveyVotes = item['survey_votes'] as List<dynamic>? ?? [];
          
          // Tartışma count: unique discussions of type 'tartisma' (opened or replied)
          final openedTartisma = discussions
              .where((d) => d['type'] == 'tartisma')
              .map((d) => d['id'] as String);
          final repliedTartisma = replies
              .where((r) => r['discussions'] != null && r['discussions']['type'] == 'tartisma')
              .map((r) => r['discussion_id'] as String);
          final tartismaCount = <String>{...openedTartisma, ...repliedTartisma}.length;

          // Danışma count: unique discussions of type 'danisma' (opened or replied)
          final openedDanisma = discussions
              .where((d) => d['type'] == 'danisma')
              .map((d) => d['id'] as String);
          final repliedDanisma = replies
              .where((r) => r['discussions'] != null && r['discussions']['type'] == 'danisma')
              .map((r) => r['discussion_id'] as String);
          final danismaCount = <String>{...openedDanisma, ...repliedDanisma}.length;

          // Survey count: number of unique surveys voted on
          final surveyCount = surveyVotes.map((v) => v['survey_id'] as String).toSet().length;
          
          return ParticipantData(
            id: item['id'] as String,
            fullName: item['full_name'] as String?,
            profession: item['profession'] as String?,
            avatarUrl: item['avatar_url'] as String?,
            highestLevel: (item['highest_level'] as String? ?? 'bronze').toLowerCase(),
            isVerified: item['is_verified'] as bool? ?? false,
            role: item['role'] as String? ?? 'user',
            discussionCount: tartismaCount,
            consultationCount: danismaCount,
            surveyCount: surveyCount,
            createdAt: item['created_at'] != null ? DateTime.tryParse(item['created_at'].toString()) : null,
          );
        }).toList();

        // Sort globally: activity descending, registration descending (newest members first)
        parsed.sort((a, b) {
          final totalA = a.discussionCount + a.consultationCount + a.surveyCount;
          final totalB = b.discussionCount + b.consultationCount + b.surveyCount;
          final totalComp = totalB.compareTo(totalA);
          if (totalComp != 0) return totalComp;
          
          final dateA = a.createdAt ?? DateTime.now();
          final dateB = b.createdAt ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        allLoaded = parsed;
      }

      // Filter locally based on search query
      final search = state.searchQuery.trim().toLowerCase();
      List<ParticipantData> filtered = allLoaded;
      if (search.isNotEmpty) {
        filtered = allLoaded.where((p) {
          final nameMatch = (p.fullName ?? '').toLowerCase().contains(search);
          final profMatch = (p.profession ?? '').toLowerCase().contains(search);
          return nameMatch || profMatch;
        }).toList();
      }

      final nextOffset = isRefresh ? 0 : state.offset;
      final int endIndex = (nextOffset + limit) > filtered.length ? filtered.length : (nextOffset + limit);
      final pageItems = filtered.sublist(nextOffset, endIndex);
      
      final updatedParticipants = isRefresh ? pageItems : [...state.participants, ...pageItems];

      state = state.copyWith(
        allParticipants: allLoaded,
        participants: updatedParticipants,
        loading: false,
        loadingMore: false,
        offset: endIndex,
        hasMore: endIndex < filtered.length,
      );
    } catch (e) {
      state = state.copyWith(loading: false, loadingMore: false);
    }
  }

  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    loadParticipants(isRefresh: true, forceFetch: false);
  }
}

final participantsNotifierProvider = NotifierProvider<ParticipantsNotifier, ParticipantsState>(() {
  return ParticipantsNotifier();
});

class ParticipantsScreen extends ConsumerStatefulWidget {
  const ParticipantsScreen({super.key});

  @override
  ConsumerState<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends ConsumerState<ParticipantsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(participantsNotifierProvider.notifier).loadParticipants(isRefresh: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(participantsNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : AppTheme.primaryNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Katılımcılar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // Header description + search bar container
          Container(
            width: double.infinity,
            color: isDark ? Colors.grey[900] : Colors.white,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tartışma, danışma ve anketlere katılan tüm üyeler',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      width: 0.8,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      ref.read(participantsNotifierProvider.notifier).setSearchQuery(val.trim().toLowerCase());
                    },
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      icon: Icon(Icons.search_rounded, color: isDark ? Colors.grey[400] : Colors.grey[500], size: 20),
                      hintText: 'common_search_hint'.tr(),
                      hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Participant list
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : state.participants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'chat_no_results'.tr(),
                              style: TextStyle(color: Colors.grey[500], fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: state.participants.length + (state.loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == state.participants.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final participant = state.participants[index];
                          return _buildParticipantCard(context, participant, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard(BuildContext context, ParticipantData participant, bool isDark) {
    final initial = (participant.fullName ?? '?').isNotEmpty ? participant.fullName![0].toUpperCase() : '?';
    final isOnline = participant.id.hashCode % 3 != 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => context.push('/participant-detail/${participant.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with online status dot
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: participant.avatarUrl != null ? NetworkImage(participant.avatarUrl!) : null,
                    backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                    child: participant.avatarUrl == null
                        ? Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryNavy,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.grey[900]! : Colors.white,
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              
              // Name and Title/Profession
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            NameFormatter.format(participant.fullName),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.primaryNavy,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (participant.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: AppTheme.actionBlue, size: 14),
                        ],
                        if (participant.highestLevel != 'bronze') ...[
                          const SizedBox(width: 4),
                          LevelBadge(levelKey: participant.highestLevel, size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    ProfessionLabel(
                      professionId: participant.profession,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Stats
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatBadge(Icons.chat_bubble_outline_rounded, Colors.blue, participant.discussionCount),
                  const SizedBox(width: 6),
                  _buildStatBadge(Icons.psychology_alt_rounded, Colors.deepPurple, participant.consultationCount),
                  const SizedBox(width: 6),
                  _buildStatBadge(Icons.poll_rounded, Colors.indigo, participant.surveyCount),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, Color color, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
