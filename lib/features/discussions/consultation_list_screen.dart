import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/discussion_model.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/discussion_repository.dart';
import '../../core/widgets/unified_header.dart';
import '../../core/widgets/level_badge.dart';
import '../../core/providers/app_config_provider.dart';
import '../home/home_provider.dart';


class ConsultationListScreen extends ConsumerStatefulWidget {
  const ConsultationListScreen({super.key});

  @override
  ConsumerState<ConsultationListScreen> createState() => _ConsultationListScreenState();
}

class _ConsultationListScreenState extends ConsumerState<ConsultationListScreen> {
  List<DiscussionModel> _discussions = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  String _selectedStatus = 'tumu'; // tumu, yanitlandi, yanitlanmadi, benimkiler
  String? _selectedCategory;
  bool _isSearching = false;

  // FAB State
  bool _isFabExtended = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 50 && _isFabExtended) {
      setState(() => _isFabExtended = false);
    }
  }


  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _hasMore = true;
    });

    try {
      final repository = ref.read(discussionRepositoryProvider);
      final items = await repository.getDiscussions(
        'danisma', 
        page: 0, 
        searchQuery: _searchQuery,
        status: _selectedStatus,
        category: _selectedCategory,
      );
      
      if (mounted) {
        setState(() {
          _discussions = items;
          _isLoading = false;
          _hasMore = items.length >= 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final repository = ref.read(discussionRepositoryProvider);
      final nextItems = await repository.getDiscussions(
        'danisma', 
        page: nextPage, 
        searchQuery: _searchQuery,
        status: _selectedStatus,
        category: _selectedCategory,
      );
      
      if (mounted) {
        if (nextItems.isEmpty) {
          setState(() {
            _hasMore = false;
            _isLoadingMore = false;
          });
        } else {
          setState(() {
            _discussions.addAll(nextItems);
            _currentPage = nextPage;
            _isLoadingMore = false;
            _hasMore = nextItems.length >= 20;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final profile = homeState.value?.profile;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
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
                    _buildCreateConsultationCard(),
                    const SizedBox(height: 32),
                    _buildCategoriesSection(),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        if (!_isSearching)
                          Expanded(
                            child: Text(
                              'Öne Çıkan Danışmalar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: 'Danışma ara...',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(fontSize: 14),
                                ),
                                style: const TextStyle(fontSize: 14),
                                onChanged: (value) {
                                  _debounce?.cancel();
                                  _debounce = Timer(const Duration(milliseconds: 500), () {
                                    setState(() => _searchQuery = value);
                                    _loadInitialData();
                                  });
                                },
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _isSearching ? Icons.close_rounded : Icons.search_rounded,
                            color: AppTheme.actionBlue,
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() {
                              _isSearching = !_isSearching;
                              if (!_isSearching) {
                                _searchController.clear();
                                _searchQuery = '';
                                _loadInitialData();
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.actionBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.filter_list_rounded, color: AppTheme.actionBlue, size: 20),
                          ),
                          onSelected: (value) {
                            setState(() => _selectedStatus = value);
                            _loadInitialData();
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'benimkiler', child: Text('Sadece Bana Ait Kayıtlar')),
                            const PopupMenuItem(value: 'tumu', child: Text('Tümü')),
                            const PopupMenuItem(value: 'yanitlanmadi', child: Text('Çözüm Bekleyenler')),
                            const PopupMenuItem(value: 'yanitlandi', child: Text('Çözülenler')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
            else if (_discussions.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _discussions.length) {
                        if (_hasMore && !_isLoadingMore) {
                          Future.microtask(() => _loadMore());
                        }
                        return _isLoadingMore 
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              ) 
                            : const SizedBox(height: 80);
                      }
                      return _buildDiscussionCard(context, _discussions[index]);
                    },
                    childCount: _discussions.length + (_hasMore ? 1 : 1),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ────────── UNIFIED HEADER ──────────

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'discussions_consultation'.tr(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryNavy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'consultation_subtitle'.tr(),
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCreateConsultationCard() {
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
            child: const Icon(Icons.chat_bubble_rounded, color: AppTheme.actionBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'discussions_ask_question'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                Text(
                  'consultation_subtitle_create'.tr(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final result = await context.push('/create-consultation');
              if (result == true) _loadInitialData();
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

  Widget _buildCategoriesSection() {
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      data: (config) {
        final List<dynamic> rawCategories = config['consultation_categories'] ?? [];
        if (rawCategories.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danışma Kategorileri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: rawCategories.length,
                itemBuilder: (context, index) {
                  final cat = rawCategories[index] as Map<String, dynamic>;
                  final name = cat['label'] ?? '';
                  final iconName = cat['icon'] ?? 'category';
                  final catValue = cat['value']?.toString();
                  final isSelected = _selectedCategory == catValue;
                  
                  // Simple icon mapping
                  IconData iconData;
                  Color iconColor;
                  switch(iconName) {
                    case 'percent': iconData = Icons.percent; iconColor = Colors.blue; break;
                    case 'calculator': iconData = Icons.calculate; iconColor = Colors.green; break;
                    case 'fact_check': iconData = Icons.fact_check; iconColor = Colors.purple; break;
                    case 'gavel': iconData = Icons.gavel; iconColor = Colors.orange; break;
                    case 'groups': iconData = Icons.groups; iconColor = Colors.teal; break;
                    case 'event_available': iconData = Icons.event_available; iconColor = Colors.indigo; break;
                    default: iconData = Icons.category; iconColor = Colors.grey;
                  }

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedCategory = null;
                        } else {
                          _selectedCategory = catValue;
                        }
                      });
                      _loadInitialData();
                    },
                    child: Container(
                      width: 90,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.actionBlue.withValues(alpha: 0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppTheme.actionBlue : Colors.grey[100]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(iconData, color: iconColor, size: 22),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.bold,
                              fontSize: 13,
                              color: isSelected ? AppTheme.actionBlue : AppTheme.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.psychology_alt_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'discussions_empty'.tr(args: ['discussions_consultation'.tr()]),
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscussionCard(BuildContext context, DiscussionModel discussion) {
    final bool isResolved = discussion.isResolved || discussion.status == 'closed' || discussion.replyCount >= 3;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          await context.push('/discussion/detail', extra: discussion);
          _loadInitialData();
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: (!discussion.isAnonymous && discussion.authorAvatarUrl != null) 
                              ? NetworkImage(discussion.authorAvatarUrl!) 
                              : null,
                          backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                          child: (discussion.isAnonymous || discussion.authorAvatarUrl == null)
                              ? const Icon(Icons.person, color: AppTheme.primaryNavy, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    discussion.isAnonymous ? 'discussions_anonymous_user'.tr() : discussion.formattedAuthorName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                                  ),
                                  if (!discussion.isAnonymous && discussion.authorHighestLevel != null) ...[
                                    const SizedBox(width: 4),
                                    LevelBadge(levelKey: discussion.authorHighestLevel!, size: 10),
                                  ],
                                ],
                              ),
                              Text(
                                _getTimeAgo(discussion.createdAt),
                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isResolved ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isResolved ? 'Çözüldü' : 'Çözüm Bekliyor',
                      style: TextStyle(
                        color: isResolved ? Colors.green[700] : Colors.orange[700],
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                discussion.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.primaryNavy, height: 1.3),
              ),
              const SizedBox(height: 8),
              Text(
                discussion.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text('${discussion.replyCount} yanıt', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const SizedBox(width: 16),
                  Icon(Icons.visibility_outlined, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text('${discussion.viewCount} görüntüleme', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const Spacer(),
                  if (discussion.category != null)
                    _buildCategoryBadge(discussion.category!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String categoryValue) {
    final configAsync = ref.watch(appConfigProvider);
    
    return configAsync.when(
      data: (config) {
        final List<dynamic> rawCategories = config['consultation_categories'] ?? [];
        String label = categoryValue;
        
        for (var cat in rawCategories) {
          if (cat is Map && cat['value'] == categoryValue) {
            label = cat['label'] ?? categoryValue;
            break;
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.actionBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.actionBlue.withValues(alpha: 0.1)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.actionBlue,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.actionBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppTheme.actionBlue, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) return 'common_days_ago'.tr(args: [diff.inDays.toString()]);
    if (diff.inHours > 0) return 'common_hours_ago'.tr(args: [diff.inHours.toString()]);
    if (diff.inMinutes > 0) return 'common_minutes_ago'.tr(args: [diff.inMinutes.toString()]);
    return 'common_just_now'.tr();
  }
}
