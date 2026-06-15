import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/level_badge.dart';
import '../../core/widgets/profession_label.dart';
import '../../core/utils/name_formatter.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/discussion_model.dart';
import '../../data/repositories/discussion_repository.dart';
import '../profile/follower_provider.dart';
import '../../data/repositories/follower_repository.dart';

class VotedSurveyData {
  final String id;
  final String title;
  final DateTime votedAt;

  VotedSurveyData({required this.id, required this.title, required this.votedAt});
}

class ParticipantDetailScreen extends ConsumerStatefulWidget {
  final String userId;

  const ParticipantDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<ParticipantDetailScreen> createState() => _ParticipantDetailScreenState();
}

class _ParticipantDetailScreenState extends ConsumerState<ParticipantDetailScreen> {
  ProfileModel? _profile;
  bool _loadingProfile = true;

  int _discussionsCount = 0;
  int _consultationsCount = 0;
  int _surveysCount = 0;

  int _selectedTab = 0; // 0: Tartışmalar, 1: Danışmalar, 2: Anketler

  // Opened Discussions
  final List<DiscussionModel> _openedDiscussions = [];
  int _openedDiscussionsPage = 0;
  bool _loadingOpenedDiscussions = true;
  bool _loadingMoreOpenedDiscussions = false;
  bool _hasMoreOpenedDiscussions = true;

  // Replied Discussions
  List<String> _repliedDiscussionIds = [];
  final List<DiscussionModel> _repliedDiscussions = [];
  int _repliedDiscussionsPage = 0;
  bool _loadingRepliedDiscussions = true;
  bool _loadingMoreRepliedDiscussions = false;
  bool _hasMoreRepliedDiscussions = true;

  // Opened Consultations
  final List<DiscussionModel> _openedConsultations = [];
  int _openedConsultationsPage = 0;
  bool _loadingOpenedConsultations = true;
  bool _loadingMoreOpenedConsultations = false;
  bool _hasMoreOpenedConsultations = true;

  // Replied Consultations
  List<String> _repliedConsultationIds = [];
  final List<DiscussionModel> _repliedConsultations = [];
  int _repliedConsultationsPage = 0;
  bool _loadingRepliedConsultations = true;
  bool _loadingMoreRepliedConsultations = false;
  bool _hasMoreRepliedConsultations = true;

  // Voted Surveys
  final List<VotedSurveyData> _votedSurveys = [];
  int _votedSurveysPage = 0;
  bool _loadingVotedSurveys = true;
  bool _loadingMoreVotedSurveys = false;
  bool _hasMoreVotedSurveys = true;

  @override
  void initState() {
    super.initState();
    _loadProfileAndCounts();
    _loadOpenedDiscussions();
    _loadOpenedConsultations();
    _initRepliedAndLoadFirstPage();
    _loadVotedSurveys();
  }

  Future<void> _loadProfileAndCounts() async {
    setState(() => _loadingProfile = true);
    final client = Supabase.instance.client;
    try {
      final profileResponse = await client
          .from('profiles')
          .select('''
            *,
            discussions(id, type),
            discussion_replies(discussion_id, discussions(type)),
            survey_votes(survey_id)
          ''')
          .eq('id', widget.userId)
          .single();

      final profile = ProfileModel.fromJson(profileResponse);

      final discussionsList = profileResponse['discussions'] as List<dynamic>? ?? [];
      final repliesList = profileResponse['discussion_replies'] as List<dynamic>? ?? [];
      final votesList = profileResponse['survey_votes'] as List<dynamic>? ?? [];

      // Unique Tartışma IDs (opened or replied)
      final openedTartisma = discussionsList
          .where((d) => d['type'] == 'tartisma')
          .map((d) => d['id'] as String);
      final repliedTartisma = repliesList
          .where((r) => r['discussions'] != null && r['discussions']['type'] == 'tartisma')
          .map((r) => r['discussion_id'] as String);
      final uniqueTartisma = <String>{...openedTartisma, ...repliedTartisma};

      // Unique Danışma IDs (opened or replied)
      final openedDanisma = discussionsList
          .where((d) => d['type'] == 'danisma')
          .map((d) => d['id'] as String);
      final repliedDanisma = repliesList
          .where((r) => r['discussions'] != null && r['discussions']['type'] == 'danisma')
          .map((r) => r['discussion_id'] as String);
      final uniqueDanisma = <String>{...openedDanisma, ...repliedDanisma};

      final surveyCount = votesList.map((v) => v['survey_id'] as String).toSet().length;

      setState(() {
        _profile = profile;
        _discussionsCount = uniqueTartisma.length;
        _consultationsCount = uniqueDanisma.length;
        _surveysCount = surveyCount;
        _loadingProfile = false;
      });
    } catch (e) {
      setState(() {
        _loadingProfile = false;
      });
    }
  }

  Future<void> _loadOpenedDiscussions({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _loadingMoreOpenedDiscussions = true);
    } else {
      setState(() => _loadingOpenedDiscussions = true);
    }

    try {
      final client = Supabase.instance.client;
      final from = _openedDiscussionsPage * 5;
      final to = from + 4;

      final response = await client
          .from('discussions')
          .select('*, profiles!author_id(*)')
          .eq('author_id', widget.userId)
          .eq('type', 'tartisma')
          .order('created_at', ascending: false)
          .range(from, to);

      final List list = response as List;
      final parsed = list.map((e) => DiscussionModel.fromJson(e)).toList();

      setState(() {
        _openedDiscussions.addAll(parsed);
        _openedDiscussionsPage++;
        _hasMoreOpenedDiscussions = parsed.length == 5;
        _loadingOpenedDiscussions = false;
        _loadingMoreOpenedDiscussions = false;
      });
    } catch (e) {
      setState(() {
        _loadingOpenedDiscussions = false;
        _loadingMoreOpenedDiscussions = false;
      });
    }
  }

  Future<void> _loadOpenedConsultations({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _loadingMoreOpenedConsultations = true);
    } else {
      setState(() => _loadingOpenedConsultations = true);
    }

    try {
      final client = Supabase.instance.client;
      final from = _openedConsultationsPage * 5;
      final to = from + 4;

      final response = await client
          .from('discussions')
          .select('*, profiles!author_id(*)')
          .eq('author_id', widget.userId)
          .eq('type', 'danisma')
          .order('created_at', ascending: false)
          .range(from, to);

      final List list = response as List;
      final parsed = list.map((e) => DiscussionModel.fromJson(e)).toList();

      setState(() {
        _openedConsultations.addAll(parsed);
        _openedConsultationsPage++;
        _hasMoreOpenedConsultations = parsed.length == 5;
        _loadingOpenedConsultations = false;
        _loadingMoreOpenedConsultations = false;
      });
    } catch (e) {
      setState(() {
        _loadingOpenedConsultations = false;
        _loadingMoreOpenedConsultations = false;
      });
    }
  }

  Future<void> _initRepliedAndLoadFirstPage() async {
    await _loadRepliedIds();
    _loadRepliedDiscussions();
    _loadRepliedConsultations();
  }

  Future<void> _loadRepliedIds() async {
    final client = Supabase.instance.client;
    try {
      final response = await client
          .from('discussion_replies')
          .select('discussion_id, discussions!inner(type)')
          .eq('author_id', widget.userId);

      final List list = response as List;
      final Set<String> repliedDiscSet = {};
      final Set<String> repliedConsSet = {};

      for (var item in list) {
        final dId = item['discussion_id'] as String;
        final disc = item['discussions'] as Map<String, dynamic>?;
        if (disc != null) {
          final type = disc['type'] as String?;
          if (type == 'tartisma') {
            repliedDiscSet.add(dId);
          } else if (type == 'danisma') {
            repliedConsSet.add(dId);
          }
        }
      }

      setState(() {
        _repliedDiscussionIds = repliedDiscSet.toList();
        _repliedConsultationIds = repliedConsSet.toList();
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadRepliedDiscussions({bool loadMore = false}) async {
    if (_repliedDiscussionIds.isEmpty) {
      setState(() {
        _loadingRepliedDiscussions = false;
        _loadingMoreRepliedDiscussions = false;
        _hasMoreRepliedDiscussions = false;
      });
      return;
    }

    if (loadMore) {
      setState(() => _loadingMoreRepliedDiscussions = true);
    } else {
      setState(() => _loadingRepliedDiscussions = true);
    }

    try {
      final client = Supabase.instance.client;
      final start = _repliedDiscussionsPage * 5;
      final end = min((_repliedDiscussionsPage + 1) * 5, _repliedDiscussionIds.length);

      if (start >= _repliedDiscussionIds.length) {
        setState(() {
          _hasMoreRepliedDiscussions = false;
          _loadingRepliedDiscussions = false;
          _loadingMoreRepliedDiscussions = false;
        });
        return;
      }

      final slice = _repliedDiscussionIds.sublist(start, end);
      final response = await client
          .from('discussions')
          .select('*, profiles!author_id(*)')
          .inFilter('id', slice);

      final List list = response as List;
      final parsed = list.map((e) => DiscussionModel.fromJson(e)).toList();

      setState(() {
        _repliedDiscussions.addAll(parsed);
        _repliedDiscussionsPage++;
        _hasMoreRepliedDiscussions = end < _repliedDiscussionIds.length;
        _loadingRepliedDiscussions = false;
        _loadingMoreRepliedDiscussions = false;
      });
    } catch (e) {
      setState(() {
        _loadingRepliedDiscussions = false;
        _loadingMoreRepliedDiscussions = false;
      });
    }
  }

  Future<void> _loadRepliedConsultations({bool loadMore = false}) async {
    if (_repliedConsultationIds.isEmpty) {
      setState(() {
        _loadingRepliedConsultations = false;
        _loadingMoreRepliedConsultations = false;
        _hasMoreRepliedConsultations = false;
      });
      return;
    }

    if (loadMore) {
      setState(() => _loadingMoreRepliedConsultations = true);
    } else {
      setState(() => _loadingRepliedConsultations = true);
    }

    try {
      final client = Supabase.instance.client;
      final start = _repliedConsultationsPage * 5;
      final end = min((_repliedConsultationsPage + 1) * 5, _repliedConsultationIds.length);

      if (start >= _repliedConsultationIds.length) {
        setState(() {
          _hasMoreRepliedConsultations = false;
          _loadingRepliedConsultations = false;
          _loadingMoreRepliedConsultations = false;
        });
        return;
      }

      final slice = _repliedConsultationIds.sublist(start, end);
      final response = await client
          .from('discussions')
          .select('*, profiles!author_id(*)')
          .inFilter('id', slice);

      final List list = response as List;
      final parsed = list.map((e) => DiscussionModel.fromJson(e)).toList();

      setState(() {
        _repliedConsultations.addAll(parsed);
        _repliedConsultationsPage++;
        _hasMoreRepliedConsultations = end < _repliedConsultationIds.length;
        _loadingRepliedConsultations = false;
        _loadingMoreRepliedConsultations = false;
      });
    } catch (e) {
      setState(() {
        _loadingRepliedConsultations = false;
        _loadingMoreRepliedConsultations = false;
      });
    }
  }

  Future<void> _loadVotedSurveys({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _loadingMoreVotedSurveys = true);
    } else {
      setState(() => _loadingVotedSurveys = true);
    }

    try {
      final client = Supabase.instance.client;
      final from = _votedSurveysPage * 5;
      final to = from + 4;

      final response = await client
          .from('survey_votes')
          .select('created_at, surveys!inner(id, title)')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false)
          .range(from, to);

      final List list = response as List;
      final parsed = list.map((item) {
        final survey = item['surveys'] as Map<String, dynamic>;
        final votedAt = DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now();
        return VotedSurveyData(
          id: survey['id'] as String,
          title: survey['title'] as String,
          votedAt: votedAt,
        );
      }).toList();

      setState(() {
        _votedSurveys.addAll(parsed);
        _votedSurveysPage++;
        _hasMoreVotedSurveys = parsed.length == 5;
        _loadingVotedSurveys = false;
        _loadingMoreVotedSurveys = false;
      });
    } catch (e) {
      setState(() {
        _loadingVotedSurveys = false;
        _loadingMoreVotedSurveys = false;
      });
    }
  }

  void _navigateToDiscussionDetail(DiscussionModel disc) {
    context.push('/discussion/detail', extra: disc);
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      if (difference.inDays >= 30) {
        final months = (difference.inDays / 30).floor();
        return '$months ay önce';
      }
      return '${difference.inDays} gün önce';
    }
    if (difference.inHours > 0) return '${difference.inHours} saat önce';
    if (difference.inMinutes > 0) return '${difference.inMinutes} dk önce';
    return 'Az önce';
  }

  @override
  Widget build(BuildContext context) {
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
          'Katılımcı Detayı',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? Center(child: Text('common_error'.tr()))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildProfileHeader(context, _profile!, isDark),
                      const SizedBox(height: 8),
                      _buildTabBar(isDark),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildSelectedTabContent(isDark),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, ProfileModel profile, bool isDark) {
    final initial = (profile.fullName ?? '?').isNotEmpty ? profile.fullName![0].toUpperCase() : '?';
    final isOnline = profile.id.hashCode % 3 != 0;

    return Container(
      width: double.infinity,
      color: isDark ? Colors.grey[900] : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => context.push('/profile/${profile.id}'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                      backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                      child: profile.avatarUrl == null
                          ? Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryNavy,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.grey[900]! : Colors.white,
                          width: 3.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name and Verified Icon
          GestureDetector(
            onTap: () => context.push('/profile/${profile.id}'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      NameFormatter.format(profile.fullName),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.primaryNavy,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (profile.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: AppTheme.actionBlue, size: 20),
                  ],
                  if (profile.highestLevel != 'bronze') ...[
                    const SizedBox(width: 6),
                    LevelBadge(levelKey: profile.highestLevel, size: 20),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Profession Label
          ProfessionLabel(
            professionId: profile.profession,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // Followers & Following counts
          Consumer(
            builder: (context, ref, child) {
              final countsAsync = ref.watch(followCountsProvider(profile.id));
              return countsAsync.when(
                data: (counts) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => context.push('/profile/${profile.id}/follows?tab=followers'),
                        child: Text(
                          '${counts.followersCount} Takipçi',
                          style: const TextStyle(
                            color: AppTheme.actionBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '|',
                        style: TextStyle(color: Colors.grey[300]),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => context.push('/profile/${profile.id}/follows?tab=following'),
                        child: Text(
                          '${counts.followingCount} Takip Edilen',
                          style: const TextStyle(
                            color: AppTheme.actionBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 18),
                error: (_, __) => const SizedBox(height: 18),
              );
            },
          ),
          
          if (Supabase.instance.client.auth.currentUser?.id != profile.id) ...[
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                final isFollowingAsync = ref.watch(isFollowingProvider(profile.id));
                return isFollowingAsync.when(
                  data: (isFollowing) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollowing
                                ? (isDark ? Colors.grey[800] : Colors.grey[200])
                                : const Color(0xFF4A3AFF),
                            foregroundColor: isFollowing
                                ? (isDark ? Colors.white : Colors.grey[800])
                                : Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isFollowing
                                  ? BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)
                                  : BorderSide.none,
                            ),
                          ),
                          onPressed: () async {
                            final repo = ref.read(followerRepositoryProvider);
                            if (isFollowing) {
                              await repo.unfollowUser(profile.id);
                            } else {
                              await repo.followUser(profile.id);
                            }
                            ref.invalidate(isFollowingProvider(profile.id));
                            ref.invalidate(followCountsProvider(profile.id));
                            final myId = Supabase.instance.client.auth.currentUser?.id;
                            if (myId != null) {
                              ref.invalidate(followCountsProvider(myId));
                              ref.invalidate(followingListProvider(myId));
                            }
                            ref.invalidate(followersListProvider(profile.id));
                          },
                          icon: Icon(
                            isFollowing ? Icons.check : Icons.add,
                            size: 18,
                          ),
                          label: Text(
                            isFollowing ? 'Takip Ediliyor' : 'Takip Et',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Takip ederek yeni paylaşımlarını akışında görebilirsin.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ],
          const SizedBox(height: 24),

          // Stats Counters Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCounter('Tartışma', _discussionsCount, Colors.blue),
              _buildVerticalDivider(isDark),
              _buildStatCounter('Danışma', _consultationsCount, Colors.deepPurple),
              _buildVerticalDivider(isDark),
              _buildStatCounter('Anket', _surveysCount, Colors.indigo),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCounter(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(bool isDark) {
    return Container(
      height: 32,
      width: 1,
      color: isDark ? Colors.grey[800] : Colors.grey[200],
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[900] : Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTabButton(0, 'Tartışmalar', isDark)),
              Expanded(child: _buildTabButton(1, 'Danışmalar', isDark)),
              Expanded(child: _buildTabButton(2, 'Anketler', isDark)),
            ],
          ),
          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200], thickness: 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, bool isDark) {
    final isSelected = _selectedTab == index;
    final activeColor = isDark ? Colors.white : AppTheme.primaryNavy;
    final inactiveColor = isDark ? Colors.grey[600] : Colors.grey[400];

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppTheme.actionBlue : Colors.transparent,
              width: 2.0,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? activeColor : inactiveColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent(bool isDark) {
    switch (_selectedTab) {
      case 0:
        return Column(
          children: [
            _buildTimelineSection(
              title: 'Açtığı Tartışmalar',
              icon: Icons.chat_bubble_outline_rounded,
              items: _openedDiscussions,
              isLoading: _loadingOpenedDiscussions,
              isLoadingMore: _loadingMoreOpenedDiscussions,
              hasMore: _hasMoreOpenedDiscussions,
              onLoadMore: () => _loadOpenedDiscussions(loadMore: true),
              emptyMessage: 'Henüz tartışma açılmadı.',
              isDark: isDark,
              itemBuilder: (item, isLast) {
                final d = item as DiscussionModel;
                return _buildTimelineItem(
                  title: d.title ?? '',
                  timeAgo: d.createdAt != null ? _getTimeAgo(d.createdAt!) : '',
                  category: d.category,
                  isLast: isLast,
                  isDark: isDark,
                  onTap: () => _navigateToDiscussionDetail(d),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildTimelineSection(
              title: 'Cevap Verdiği Tartışmalar',
              icon: Icons.comment_outlined,
              items: _repliedDiscussions,
              isLoading: _loadingRepliedDiscussions,
              isLoadingMore: _loadingMoreRepliedDiscussions,
              hasMore: _hasMoreRepliedDiscussions,
              onLoadMore: () => _loadRepliedDiscussions(loadMore: true),
              emptyMessage: 'Henüz tartışma cevaplanmadı.',
              isDark: isDark,
              itemBuilder: (item, isLast) {
                final d = item as DiscussionModel;
                return _buildTimelineItem(
                  title: d.title ?? '',
                  timeAgo: d.createdAt != null ? _getTimeAgo(d.createdAt!) : '',
                  category: d.category,
                  isLast: isLast,
                  isDark: isDark,
                  onTap: () => _navigateToDiscussionDetail(d),
                );
              },
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            _buildTimelineSection(
              title: 'Danışma Soruları',
              icon: Icons.psychology_alt_rounded,
              items: _openedConsultations,
              isLoading: _loadingOpenedConsultations,
              isLoadingMore: _loadingMoreOpenedConsultations,
              hasMore: _hasMoreOpenedConsultations,
              onLoadMore: () => _loadOpenedConsultations(loadMore: true),
              emptyMessage: 'Henüz danışma sorusu açılmadı.',
              isDark: isDark,
              itemBuilder: (item, isLast) {
                final d = item as DiscussionModel;
                return _buildTimelineItem(
                  title: d.title ?? '',
                  timeAgo: d.createdAt != null ? _getTimeAgo(d.createdAt!) : '',
                  category: d.category,
                  isLast: isLast,
                  isDark: isDark,
                  onTap: () => _navigateToDiscussionDetail(d),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildTimelineSection(
              title: 'Danışma Cevapları',
              icon: Icons.forum_rounded,
              items: _repliedConsultations,
              isLoading: _loadingRepliedConsultations,
              isLoadingMore: _loadingMoreRepliedConsultations,
              hasMore: _hasMoreRepliedConsultations,
              onLoadMore: () => _loadRepliedConsultations(loadMore: true),
              emptyMessage: 'Henüz danışma cevaplanmadı.',
              isDark: isDark,
              itemBuilder: (item, isLast) {
                final d = item as DiscussionModel;
                return _buildTimelineItem(
                  title: d.title ?? '',
                  timeAgo: d.createdAt != null ? _getTimeAgo(d.createdAt!) : '',
                  category: d.category,
                  isLast: isLast,
                  isDark: isDark,
                  onTap: () => _navigateToDiscussionDetail(d),
                );
              },
            ),
          ],
        );
      case 2:
        return _buildTimelineSection(
          title: 'Anketlere Katılımı',
          icon: Icons.poll_rounded,
          items: _votedSurveys,
          isLoading: _loadingVotedSurveys,
          isLoadingMore: _loadingMoreVotedSurveys,
          hasMore: _hasMoreVotedSurveys,
          onLoadMore: () => _loadVotedSurveys(loadMore: true),
          emptyMessage: 'Henüz ankete katılım sağlanmadı.',
          isDark: isDark,
          itemBuilder: (item, isLast) {
            final s = item as VotedSurveyData;
            return _buildSurveyTimelineItem(
              title: s.title,
              timeAgo: _getTimeAgo(s.votedAt),
              isLast: isLast,
              isDark: isDark,
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTimelineSection({
    required String title,
    required IconData icon,
    required List<dynamic> items,
    required bool isLoading,
    required bool isLoadingMore,
    required bool hasMore,
    required VoidCallback onLoadMore,
    required Widget Function(dynamic item, bool isLast) itemBuilder,
    required String emptyMessage,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Row(
          children: [
            Icon(icon, color: isDark ? Colors.white70 : AppTheme.primaryNavy, size: 22),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.primaryNavy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // List items
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 24),
            child: Text(
              emptyMessage,
              style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontSize: 13),
            ),
          )
        else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final isLast = index == items.length - 1;
              return itemBuilder(items[index], isLast);
            },
          ),

          // Load More button
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 24),
              child: TextButton.icon(
                onPressed: isLoadingMore ? null : onLoadMore,
                icon: isLoadingMore
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                label: const Text(
                  'Daha çok göster',
                  style: TextStyle(
                    color: AppTheme.actionBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String timeAgo,
    String? category,
    required bool isLast,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Timeline Graphic
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.actionBlue.withValues(alpha: 0.8),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[500],
                          ),
                        ),
                        if (category != null && category.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.actionBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.actionBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyTimelineItem({
    required String title,
    required String timeAgo,
    required bool isLast,
    required bool isDark,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Timeline Graphic
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.poll_rounded, color: Colors.green, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Katıldı • $timeAgo',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
