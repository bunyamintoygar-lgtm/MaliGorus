import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/survey_repository.dart';
import '../../data/models/survey_model.dart';
import '../home/home_provider.dart';

import '../../core/widgets/unified_header.dart';
import '../../core/utils/level_permissions.dart';
import '../../core/providers/app_config_provider.dart';
import '../../data/models/profile_model.dart';

class SurveyListScreen extends ConsumerStatefulWidget {
  const SurveyListScreen({super.key});

  @override
  ConsumerState<SurveyListScreen> createState() => _SurveyListScreenState();
}

class _SurveyListScreenState extends ConsumerState<SurveyListScreen> {
  List<SurveyModel> _surveys = [];
  Map<String, String> _myVotes = {}; // {surveyId: optionId}
  bool _isLoading = true;
  bool _isLoadMoreRunning = false;
  bool _hasMore = true;
  String? _error;
  int _currentPage = 0;
  final int _pageSize = 15;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // FAB State
  bool _isFabExtended = false;
  int _selectedTabIndex = 0; // 0: Aktif, 1: Tamamlananlar
  bool _showSearch = false;
  String _selectedFilter = 'all'; // all, mine, voted, unvoted

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_loadMore);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 50 && _isFabExtended) {
      setState(() => _isFabExtended = false);
    }
  }


  Future<void> _loadData({String? search}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _hasMore = true;
    });

    try {
      final repo = ref.read(surveyRepositoryProvider);
      final myVotes = await repo.getMyVotes();
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      final items = await repo.getSurveys(
        search: search,
        from: 0,
        to: _pageSize - 1,
        authorId: _selectedFilter == 'mine' ? currentUserId : null,
        votedIds: (_selectedFilter == 'voted' || _selectedFilter == 'unvoted') ? myVotes.keys.toList() : null,
        onlyVoted: _selectedFilter == 'voted',
        onlyUnvoted: _selectedFilter == 'unvoted',
      );
      
      if (mounted) {
        setState(() {
          _surveys = items;
          _myVotes = myVotes;
          _isLoading = false;
          if (items.length < _pageSize) _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadMoreRunning || !_hasMore) return;

    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      setState(() => _isLoadMoreRunning = true);

      try {
        _currentPage++;
        final from = _currentPage * _pageSize;
        final to = from + _pageSize - 1;

        final repo = ref.read(surveyRepositoryProvider);
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        
        final newItems = await repo.getSurveys(
          search: _searchController.text,
          from: from,
          to: to,
          authorId: _selectedFilter == 'mine' ? currentUserId : null,
          votedIds: (_selectedFilter == 'voted' || _selectedFilter == 'unvoted') ? _myVotes.keys.toList() : null,
          onlyVoted: _selectedFilter == 'voted',
          onlyUnvoted: _selectedFilter == 'unvoted',
        );

        if (mounted) {
          if (newItems.isEmpty) {
            setState(() {
              _hasMore = false;
              _isLoadMoreRunning = false;
            });
          } else {
            setState(() {
              _surveys.addAll(newItems);
              _isLoadMoreRunning = false;
              if (newItems.length < _pageSize) _hasMore = false;
            });
          }
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadMoreRunning = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadData(search: query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final profile = homeState.value?.profile;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () => _loadData(search: _searchController.text),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverUnifiedHeader(profile: profile),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitleSection(),
                    const SizedBox(height: 24),
                    _buildCreateSurveyCard(),
                    const SizedBox(height: 32),
                    _buildTabsSection(),
                    if (_showSearch) ...[
                      const SizedBox(height: 16),
                      _buildSearchBar(),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(child: Text('error_loading'.tr(args: [_error!]))),
              )
            else if (_surveys.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _surveys.length) {
                        if (_hasMore && !_isLoadMoreRunning) {
                          Future.microtask(() => _loadMore());
                        }
                        return _isLoadMoreRunning 
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              ) 
                            : const SizedBox(height: 80);
                      }
                      
                      final survey = _surveys[index];
                      // Tab filtresi
                      if (_selectedTabIndex == 1 && !survey.isExpired) return const SizedBox.shrink();
                      if (_selectedTabIndex == 0 && survey.isExpired) return const SizedBox.shrink();

                      return _SurveyCard(
                        survey: survey,
                        initialVotedOptionId: _myVotes[survey.id],
                        onVoteSuccess: () {
                          ref.read(homeProvider.notifier).loadHomeData();
                        },
                      );
                    },
                    childCount: _surveys.length + (_hasMore ? 1 : 0),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }



  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Anketler',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryNavy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'surveys_subtitle'.tr(),
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCreateSurveyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.actionBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bar_chart_rounded, color: AppTheme.actionBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'surveys_create_title'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                Text(
                  'surveys_subtitle_create'.tr(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final userLevel = ref.read(homeProvider).value?.profile?.highestLevel;
              final levels = ref.read(levelConfigProvider).value ?? [];
              if (!LevelPermissions.hasPermission(userLevel, AppPermission.createSurvey, levels)) {
                LevelPermissions.showAccessDeniedDialog(context, AppPermission.createSurvey);
                return;
              }

              final result = await context.push('/create-survey');
              if (result == true) {
                _loadData(search: _searchController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.actionBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('common_publish'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsSection() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildTabItem('surveys_active_tabs'.tr(), 0),
              _buildTabItem('surveys_completed_tabs'.tr(), 1),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showSearch = !_showSearch),
                icon: Icon(
                  _showSearch ? Icons.close : Icons.search, 
                  color: _showSearch ? AppTheme.actionBlue : Colors.grey, 
                  size: 20
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              PopupMenuButton<String>(
                initialValue: _selectedFilter,
                onSelected: (value) {
                  setState(() => _selectedFilter = value);
                  _loadData(search: _searchController.text);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'all', child: Text('listings_all'.tr())),
                  PopupMenuItem(value: 'mine', child: Text('discussions_filter_mine'.tr())),
                  PopupMenuItem(value: 'voted', child: Text('discussions_filter_replied'.tr())),
                  PopupMenuItem(value: 'unvoted', child: Text('surveys_filter_unvoted'.tr())),
                ],
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.tune_rounded, 
                      color: _selectedFilter != 'all' ? Colors.redAccent : Colors.grey, 
                      size: 20
                    ),
                    if (_selectedFilter != 'all')
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: isSelected 
              ? const Border(bottom: BorderSide(color: AppTheme.actionBlue, width: 2)) 
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppTheme.actionBlue : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'common_search_hint'.tr(),
          prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _loadData();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.poll_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'surveys_empty_state'.tr(),
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _SurveyCard extends ConsumerStatefulWidget {
  final SurveyModel survey;
  final String? initialVotedOptionId;
  final VoidCallback onVoteSuccess;

  const _SurveyCard({
    required this.survey,
    this.initialVotedOptionId,
    required this.onVoteSuccess,
  });

  @override
  ConsumerState<_SurveyCard> createState() => _SurveyCardState();
}

class _SurveyCardState extends ConsumerState<_SurveyCard> {
  late SurveyModel _survey;
  String? _votedOptionId;
  String? _selectedOptionId;
  bool _isSaving = false;
  bool _isExpanded = false;
  bool _isDescExpanded = false;

  @override
  void initState() {
    super.initState();
    _survey = widget.survey;
    _votedOptionId = widget.initialVotedOptionId;
    _isExpanded = _votedOptionId != null;
  }

  Future<void> _handleVote() async {
    if (_selectedOptionId == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final success = await ref.read(surveyRepositoryProvider).voteSurvey(
        _survey,
        _selectedOptionId!,
      );

      if (success) {
        // Güncel anket verisini getir
        final updatedSurvey = await ref.read(surveyRepositoryProvider).getSurvey(_survey.id);
        
        if (mounted) {
          setState(() {
            if (updatedSurvey != null) _survey = updatedSurvey;
            _votedOptionId = _selectedOptionId;
            _isSaving = false;
            _isExpanded = true;
          });
          
          widget.onVoteSuccess();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('surveys_vote_success_credit'.tr())),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('common_error'.tr())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _getRemainingTime(DateTime? expiresAt) {
    if (expiresAt == null) return 'surveys_unlimited'.tr();
    final now = DateTime.now();
    final difference = expiresAt.difference(now);

    if (difference.isNegative) return 'surveys_expired'.tr();

    final days = difference.inDays;
    final hours = difference.inHours % 24;

    if (days > 0) {
      return 'surveys_time_left_days'.tr(args: [days.toString(), hours.toString()]);
    } else if (hours > 0) {
      return 'surveys_time_left_hours'.tr(args: [hours.toString()]);
    } else {
      final minutes = difference.inMinutes;

      return 'surveys_time_left_minutes'.tr(args: [minutes.toString()]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVoted = _votedOptionId != null;
    final isExpired = _survey.isExpired;
    final showResults = hasVoted || isExpired;
    final totalVotes = _survey.options.fold<int>(0, (sum, opt) => sum + opt.votes);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isAuthor = _survey.authorId == currentUserId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey[50]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Badges
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasVoted 
                            ? Colors.green[50] 
                            : isExpired 
                                ? Colors.orange[50] 
                                : AppTheme.actionBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle, 
                            size: 6, 
                            color: hasVoted 
                                ? Colors.green 
                                : isExpired 
                                    ? Colors.orange 
                                    : AppTheme.actionBlue
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasVoted 
                                ? 'surveys_status_voted'.tr() 
                                : isExpired 
                                    ? 'surveys_status_completed'.tr() 
                                    : 'surveys_status_new'.tr(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: hasVoted 
                                  ? Colors.green[700] 
                                  : isExpired 
                                      ? Colors.orange[700] 
                                      : AppTheme.actionBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isAuthor) ...[
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () {
                          context.push('/report', extra: {
                            'reportedId': _survey.authorId,
                            'reportedTitle': _survey.title,
                            'contentType': 'survey',
                            'contentId': _survey.id,
                            'contentBody': _survey.description ?? '',
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.report_problem_outlined, size: 14, color: Colors.redAccent),
                        label: const Text('Bildir', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getRemainingTime(_survey.expiresAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Title & Description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _survey.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryNavy.withValues(alpha: 0.9),
                    height: 1.3,
                  ),
                ),
                if (_survey.description != null && _survey.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _isDescExpanded = !_isDescExpanded),
                    child: Text(
                      _survey.description!,
                      maxLines: _isDescExpanded ? null : 2,
                      overflow: _isDescExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 3. Options Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _survey.options.map((opt) {
                final double percent = totalVotes == 0 ? 0 : (opt.votes / totalVotes);
                final bool isSelected = _selectedOptionId == opt.id || _votedOptionId == opt.id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: showResults ? null : () => setState(() => _selectedOptionId = opt.id),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.actionBlue.withValues(alpha: 0.04) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppTheme.actionBlue : Colors.grey[200]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  opt.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? AppTheme.actionBlue : AppTheme.primaryNavy.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                              if (showResults)
                                Text(
                                  '%${(percent * 100).toInt()}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? AppTheme.actionBlue : Colors.grey[400],
                                  ),
                                ),
                            ],
                          ),
                          if (showResults) ...[
                            const SizedBox(height: 8),
                            Stack(
                              children: [
                                Container(
                                  height: 6,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 600),
                                  height: 6,
                                  width: MediaQuery.of(context).size.width * percent * 0.7, // Slightly narrower
                                  decoration: BoxDecoration(
                                    color: AppTheme.actionBlue.withValues(alpha: isSelected ? 1.0 : 0.4),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 4. Action Button Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (!hasVoted && !isExpired)
                  SizedBox(
                    width: 160,
                    child: _selectedOptionId != null
                      ? ElevatedButton(
                          onPressed: _isSaving ? null : _handleVote,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.actionBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('surveys_save_vote'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        )
                      : OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('surveys_select_option'.tr()),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.actionBlue,
                            side: BorderSide(color: AppTheme.actionBlue.withValues(alpha: 0.1), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('surveys_participate'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                  ),
                
                // Pushes the participant count to the far right
                const Spacer(),
                
                // Participant Count
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$totalVotes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            color: AppTheme.primaryNavy
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.people_outline_rounded, size: 14, color: Colors.grey),
                      ],
                    ),
                    Text(
                      'katılımcı',
                      style: TextStyle(
                        fontSize: 10, 
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
