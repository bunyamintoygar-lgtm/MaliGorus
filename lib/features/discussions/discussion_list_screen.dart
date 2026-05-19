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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(),
                  if (_isSearching) ...[
                    _buildSearchAndFilter(),
                    const SizedBox(height: 16),
                  ],
                  _buildCategoryFilter(),
                  const SizedBox(height: 8),
                ],
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
                padding: const EdgeInsets.symmetric(vertical: 8),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
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
            ),
          ),
          Row(
            children: [
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
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _createNewDiscussion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.actionBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 22),
                label: Text('discussions_start_discussion'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'discussions_search_hint'.tr(),
                prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.actionBlue, width: 1.5),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () => _showFilterBottomSheet(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Icon(Icons.tune_rounded, color: Colors.grey[600], size: 22),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    final configAsync = ref.read(appConfigProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return configAsync.when(
          data: (config) {
            final List<dynamic> rawCategories = config['discussion_categories'] ?? [];
            final List<Map<String, String>> categories = [
              {'value': 'hepsi', 'label': 'discussions_all_categories'.tr()}
            ];
            
            for (var item in rawCategories) {
              if (item is Map) {
                categories.add({
                  'value': item['value']?.toString() ?? '',
                  'label': item['label']?.toString() ?? '',
                });
              }
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'discussions_filter_by_category'.tr(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected = _selectedCategory == cat['value'];
                        
                        return ListTile(
                          title: Text(
                            cat['label']!,
                            style: TextStyle(
                              color: isSelected ? AppTheme.actionBlue : AppTheme.primaryNavy,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: isSelected ? Icon(Icons.check_circle, color: AppTheme.actionBlue) : null,
                          onTap: () {
                            setState(() => _selectedCategory = cat['value']!);
                            _loadInitialData();
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
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
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
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
                  Text(
                    _formatDate(discussion.lastActivityAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
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
                      Text('${discussion.likeCount}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(width: 12),
                      Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text('${discussion.replyCount}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(width: 12),
                      Icon(Icons.visibility_outlined, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text('${discussion.viewCount}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                  if (discussion.category != null)
                    _buildCategoryBadge(discussion.category!)
                  else
                    const SizedBox.shrink(),
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
