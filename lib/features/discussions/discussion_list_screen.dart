import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/unified_header.dart';
import '../../core/widgets/level_badge.dart';
import '../../core/utils/level_permissions.dart';
import '../../core/providers/app_config_provider.dart';
import '../../data/models/discussion_model.dart';
import '../../data/repositories/discussion_repository.dart';
import '../home/home_provider.dart';

class DiscussionListScreen extends ConsumerStatefulWidget {
  const DiscussionListScreen({super.key});

  @override
  ConsumerState<DiscussionListScreen> createState() => _DiscussionListScreenState();
}
class _DiscussionListScreenState extends ConsumerState<DiscussionListScreen> {
  List<DiscussionModel> _discussions = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _error;

  // Search State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'hepsi';
  String _status = 'tumu';
  Timer? _debounce;
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
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _hasMore = true;
    });

    try {
      final repository = ref.read(discussionRepositoryProvider);
      final items = await repository.getDiscussions('tartisma', 
        page: 0, 
        searchQuery: _searchQuery,
        category: _selectedCategory,
        status: _status,
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
      final nextItems = await repository.getDiscussions('tartisma', 
        page: nextPage, 
        searchQuery: _searchQuery,
        category: _selectedCategory,
        status: _status,
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != query) {
        setState(() => _searchQuery = query);
        _loadInitialData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider).value;
    final profile = homeState?.profile;

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
                    _buildCreateDiscussionCard(),
                    const SizedBox(height: 32),
                    _buildCategoriesSection(),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        if (!_isSearching)
                          Expanded(
                            child: Text(
                              'Öne Çıkan Tartışmalar',
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
                                  hintText: 'Tartışma ara...',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(fontSize: 14),
                                ),
                                style: const TextStyle(fontSize: 14),
                                onChanged: _onSearchChanged,
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
                            setState(() => _status = value);
                            _loadInitialData();
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'benimkiler', child: Text('Sadece Bana Ait Kayıtlar')),
                            const PopupMenuItem(value: 'tumu', child: Text('Tümü')),
                            const PopupMenuItem(value: 'cevapladiklarim', child: Text('Cevapladıklarım')),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                      
                      final discussion = _discussions[index];
                      return _buildDiscussionCard(
                        context, 
                        discussion, 
                        key: ValueKey(discussion.id),
                      );
                    },
                    childCount: _discussions.length + (_hasMore ? 1 : 0),
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
          'discussions'.tr(),
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
        ),
        const SizedBox(height: 4),
        Text(
          'discussions_subtitle'.tr(),
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildCreateDiscussionCard() {
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
            child: const Icon(Icons.forum_rounded, color: AppTheme.actionBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yeni Tartışma Başlat',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                Text(
                  'Meslektaşlarınla fikir alışverişinde bulun',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _createNewDiscussion,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.actionBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Başlat', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      data: (config) {
        final List<dynamic> rawCategories = config['discussion_categories'] ?? [];
        if (rawCategories.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tartışma Kategorileri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryNavy,
              ),
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
                  
                  // Robust and flexible category-to-icon matching based on label/value names
                  final lowerValue = (catValue ?? '').toLowerCase();
                  final lowerLabel = name.toLowerCase();

                  IconData iconData;
                  Color iconColor;

                  if (lowerValue.contains('gelir') || lowerLabel.contains('gelir')) {
                    iconData = Icons.calculate_rounded;
                    iconColor = Colors.green;
                  } else if (lowerValue.contains('kurum') || lowerLabel.contains('kurum')) {
                    iconData = Icons.business_rounded;
                    iconColor = Colors.blue;
                  } else if (lowerValue.contains('kdv') || lowerValue.contains('katma') || lowerLabel.contains('kdv') || lowerLabel.contains('katma')) {
                    iconData = Icons.percent_rounded;
                    iconColor = Colors.redAccent;
                  } else if (lowerValue.contains('özel') || lowerValue.contains('tüketim') || lowerValue.contains('otv') || lowerValue.contains('ötv') || lowerLabel.contains('özel') || lowerLabel.contains('tüketim') || lowerLabel.contains('ötv')) {
                    iconData = Icons.receipt_long_rounded;
                    iconColor = Colors.amber[700]!;
                  } else if (lowerValue.contains('sgk') || lowerValue.contains('sosyal') || lowerValue.contains('hukuk') || lowerLabel.contains('sgk') || lowerLabel.contains('sosyal') || lowerLabel.contains('hukuk')) {
                    iconData = Icons.groups_rounded;
                    iconColor = Colors.teal;
                  } else if (lowerValue.contains('muhasebe') || lowerLabel.contains('muhasebe')) {
                    iconData = Icons.fact_check_rounded;
                    iconColor = Colors.purple;
                  } else if (lowerValue.contains('donem') || lowerValue.contains('dönem') || lowerLabel.contains('donem') || lowerLabel.contains('dönem')) {
                    iconData = Icons.event_available_rounded;
                    iconColor = Colors.indigo;
                  } else if (lowerValue.contains('mevzuat') || lowerLabel.contains('mevzuat')) {
                    iconData = Icons.gavel_rounded;
                    iconColor = Colors.orange;
                  } else {
                    switch(iconName) {
                      case 'percent': iconData = Icons.percent; iconColor = Colors.blue; break;
                      case 'calculator': iconData = Icons.calculate; iconColor = Colors.green; break;
                      case 'fact_check': iconData = Icons.fact_check; iconColor = Colors.purple; break;
                      case 'gavel': iconData = Icons.gavel; iconColor = Colors.orange; break;
                      case 'groups': iconData = Icons.groups; iconColor = Colors.teal; break;
                      case 'event_available': iconData = Icons.event_available; iconColor = Colors.indigo; break;
                      default: iconData = Icons.category_rounded; iconColor = Colors.grey;
                    }
                  }

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected || catValue == 'hepsi') {
                          _selectedCategory = 'hepsi';
                        } else {
                          _selectedCategory = catValue ?? 'hepsi';
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

  Future<void> _createNewDiscussion() async {
    final userLevel = ref.read(homeProvider).value?.profile?.highestLevel;
    final levels = ref.read(levelConfigProvider).value ?? [];
    if (!LevelPermissions.hasPermission(userLevel, AppPermission.createDiscussion, levels)) {
      LevelPermissions.showAccessDeniedDialog(context, AppPermission.createDiscussion);
      return;
    }
    
    final result = await context.push('/create-discussion');
    if (result == true) {
      _loadInitialData();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            'discussions_empty'.tr(args: ['discussions'.tr()]),
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscussionCard(BuildContext context, DiscussionModel discussion, {Key? key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[100]!),
      ),
      child: InkWell(
        onTap: () async {
          await context.push('/discussion/detail', extra: discussion);
          _loadInitialData();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: discussion.authorAvatarUrl != null ? NetworkImage(discussion.authorAvatarUrl!) : null,
                    backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.05),
                    child: discussion.authorAvatarUrl == null 
                        ? Text(discussion.formattedAuthorName[0], style: TextStyle(fontSize: 10, color: AppTheme.primaryNavy))
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            discussion.formattedAuthorName,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[800]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (discussion.authorHighestLevel != null) ...[
                          const SizedBox(width: 4),
                          LevelBadge(levelKey: discussion.authorHighestLevel!, size: 10),
                        ],
                      ],
                    ),
                  ),
                  if (discussion.category != null)
                    _buildCategoryBadge(discussion.category!)
                  else
                    const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                discussion.title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.4, color: AppTheme.primaryNavy),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                discussion.body,
                style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        discussion.isLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_outlined, 
                        size: 16, 
                        color: discussion.isLiked ? AppTheme.actionBlue : Colors.grey[400]
                      ),
                      const SizedBox(width: 4),
                      Text('${discussion.likeCount} Beğeni', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(width: 12),
                      Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text('${discussion.replyCount} Cevap', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(width: 12),
                      Icon(Icons.visibility_outlined, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text('${discussion.viewCount} İzlenme', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                  Text(
                    _formatDate(discussion.lastActivityAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
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
        final List<dynamic> rawCategories = config['discussion_categories'] ?? [];
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
            color: AppTheme.actionBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.actionBlue,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
  
  Widget _buildCategoryFilter() {
    final List<Map<String, String>> filters = [
      {'value': 'tumu', 'label': 'discussions_filter_all'.tr()},
      {'value': 'benimkiler', 'label': 'discussions_filter_mine'.tr()},
      {'value': 'cevapladiklarim', 'label': 'discussions_filter_replied'.tr()},
    ];
    
    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _status == filter['value'];
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() => _status = filter['value']!);
                _loadInitialData();
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.actionBlue : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  filter['label']!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return DateFormat('dd.MM.yyyy').format(date);
    } else if (difference.inDays >= 1) {
      return 'common_days_ago'.tr(args: [difference.inDays.toString()]);
    } else if (difference.inHours >= 1) {
      return 'common_hours_ago'.tr(args: [difference.inHours.toString()]);
    } else if (difference.inMinutes >= 1) {
      return 'common_minutes_ago'.tr(args: [difference.inMinutes.toString()]);
    } else {
      return 'common_just_now'.tr();
    }
  }
}
