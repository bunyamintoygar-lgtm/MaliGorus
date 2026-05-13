import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/unified_header.dart';
import '../../core/providers/app_config_provider.dart';
import '../../data/repositories/listing_repository.dart';
import '../../data/models/listing_model.dart';
import '../../core/utils/level_permissions.dart';
import '../home/home_provider.dart';

class ListingsScreen extends ConsumerStatefulWidget {
  const ListingsScreen({super.key});

  @override
  ConsumerState<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends ConsumerState<ListingsScreen> {
  String _selectedCategory = 'hepsi';
  String _filterType = 'all'; // 'all', 'mine', 'applied'
  final String? _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  // Search State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  // Pagination State
  List<ListingModel> _listings = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  bool _hasMore = true;
  String? _error;

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
      final repository = ref.read(listingRepositoryProvider);
      List<ListingModel> items = [];

      if (_filterType == 'mine') {
        if (_currentUserId != null) {
          items = await repository.getListingsByUser(_currentUserId!);
        }
      } else if (_filterType == 'applied') {
        if (_currentUserId != null) {
          items = await repository.getListingsByApplicant(_currentUserId!);
        }
      } else {
        items = await repository.getListings(
          page: 0, 
          pageSize: 20, 
          category: _selectedCategory, 
          searchQuery: _searchQuery
        );
      }
      
      if (mounted) {
        setState(() {
          _listings = items;
          _isLoading = false;
          _hasMore = _filterType == 'all' && items.length >= 20;
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
    if (_isLoadingMore || !_hasMore || _filterType != 'all') return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final repository = ref.read(listingRepositoryProvider);
      final nextPage = _currentPage + 1;
      final nextItems = await repository.getListings(page: nextPage, pageSize: 20, category: _selectedCategory, searchQuery: _searchQuery);

      if (mounted) {
        if (nextItems.isEmpty) {
          setState(() {
            _hasMore = false;
            _isLoadingMore = false;
          });
        } else {
          setState(() {
            _listings.addAll(nextItems);
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
    final homeState = ref.watch(homeProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          UnifiedHeader(profile: homeState.value?.profile),
          _buildSubHeader(),
          Expanded(
            child: _buildListContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'listings_title'.tr(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'listings_subtitle'.tr(),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  final userLevel = ref.read(homeProvider).value?.profile?.highestLevel;
                  final levels = ref.read(levelConfigProvider).value ?? [];
                  if (!LevelPermissions.hasPermission(userLevel, AppPermission.createListing, levels)) {
                    LevelPermissions.showAccessDeniedDialog(context, AppPermission.createListing);
                    return;
                  }
                  context.push('/create-listing');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.actionBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text('listings_new'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Search & Filter Row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'common_search_hint'.tr(),
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _showCategoryFilter,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, color: AppTheme.actionBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'listings_filter'.tr(),
                        style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Activity Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('common_all'.tr(), 'all'),
                _buildFilterChip('discussions_filter_mine'.tr(), 'mine'),
                _buildFilterChip('listings_filter_applied'.tr(), 'applied'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final isActive = _filterType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _filterType = type);
        _loadInitialData();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.actionBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5)],
          border: Border.all(color: isActive ? AppTheme.actionBlue : Colors.grey[200]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showCategoryFilter() {
    final config = ref.read(appConfigProvider).value;
    final rawCategories = config?['listing_categories'] ?? config?['listing-categories'] ?? [];
    final List<Map<String, String>> categories = [
      {'value': 'hepsi', 'label': 'listings_all_categories'.tr()},
      ...List<Map<String, dynamic>>.from(rawCategories).map((c) => Map<String, String>.from(c)),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Text('listings_select_category'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            ...categories.map((c) => ListTile(
              title: Text(c['label']!, style: TextStyle(
                fontWeight: _selectedCategory == c['value'] ? FontWeight.bold : FontWeight.normal,
                color: _selectedCategory == c['value'] ? AppTheme.actionBlue : Colors.black87,
              )),
              trailing: _selectedCategory == c['value'] ? Icon(Icons.check_circle, color: AppTheme.actionBlue) : null,
              onTap: () {
                setState(() => _selectedCategory = c['value']!);
                _loadInitialData();
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildListContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(child: Text('error_loading'.tr(args: [_error!])));
    }
    
    if (_listings.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        cacheExtent: 2000,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
        itemCount: _listings.length + (_hasMore ? 1 : 0),
        findChildIndexCallback: (Key key) {
          if (key is ValueKey<String>) {
            final String id = key.value;
            final index = _listings.indexWhere((l) => l.id == id);
            return index >= 0 ? index : null;
          }
          return null;
        },
        itemBuilder: (context, index) {
          // Erken tetikleme: Kullanıcı dibe vurmadan 3 öğe önce
          if (index >= _listings.length - 3 && index < _listings.length) {
            if (_hasMore && !_isLoadingMore) {
              Future.microtask(() => _loadMore());
            }
          }

          if (index == _listings.length) {
            return SizedBox(
              height: 100,
              child: _isLoadingMore 
                  ? const Center(child: CircularProgressIndicator()) 
                  : const SizedBox.shrink(),
            );
          }

          final item = _listings[index];

          return _buildListingCard(
            context, 
            item,
            key: ValueKey(item.id),
          );
        },
      ),
    );
  }

  Widget _buildListingCard(BuildContext context, ListingModel item, {Key? key}) {
    final bool isOwner = item.authorId == _currentUserId;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.actionBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getCategoryLabel(item.category),
                  style: TextStyle(color: AppTheme.actionBlue, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                _formatDate(item.createdAt),
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            item.title,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.primaryNavy),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          // Company & Location Row
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildCardMetadata(Icons.business_rounded, item.formattedAuthorName),
              _buildCardMetadata(Icons.location_on_outlined, item.location ?? 'listings_location_unknown'.tr()),
            ],
          ),
          const SizedBox(height: 12),
          // Description (2 lines)
          if (item.description != null && item.description!.isNotEmpty)
            Text(
              item.description!,
              style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 20),
          // Bottom Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/listing-detail', extra: item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('listings_view_apply'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              if (isOwner) ...[
                const SizedBox(width: 8),
                _buildOwnerAction(Icons.edit_outlined, Colors.blue, () => context.push('/create-listing', extra: item)),
                const SizedBox(width: 8),
                _buildOwnerAction(Icons.delete_outline, Colors.red, () => _showDeleteDialog(context, item)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardMetadata(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildOwnerAction(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  String _getCategoryLabel(String? categoryValue) {
    final config = ref.read(appConfigProvider).value;
    final rawCategories = config?['listing_categories'] ?? config?['listing-categories'] ?? [];
    for (var cat in rawCategories) {
      if (cat['value'] == categoryValue) return cat['label'] ?? categoryValue ?? '';
    }
    return categoryValue ?? 'listings_category_job'.tr();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return 'time_ago_min'.tr(args: [diff.inMinutes.toString()]);
    if (diff.inHours < 24) return 'time_ago_hour'.tr(args: [diff.inHours.toString()]);
    if (diff.inDays < 7) return 'time_ago_day'.tr(args: [diff.inDays.toString()]);
    return DateFormat('dd.MM.yyyy').format(date);
  }


  void _showDeleteDialog(BuildContext context, ListingModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('common_delete'.tr()),
        content: Text('discussions_delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common_cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(listingRepositoryProvider).deleteListing(item.id);
              if (success) {
                _loadInitialData(); // Silinince listeyi yenile
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('common_success'.tr())),
                  );
                }
              }
            },
            child: Text('common_delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Sonuç bulunamadı',
              style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    String title = 'Kayıt Bulunamadı';
    String subtitle = 'Arama kriterlerinize uygun bir ilan bulunamadı veya henüz bir ilan eklenmemiş.';

    if (_filterType == 'applied') {
      subtitle = 'Henüz başvurduğunuz bir ilana rastlanmadı.';
    } else if (_filterType == 'mine') {
      subtitle = 'Henüz oluşturduğunuz bir ilan bulunmuyor.';
    }

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icons/no_record_board_icon.png',
                height: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryNavy,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final userLevel = ref.read(homeProvider).value?.profile?.highestLevel;
                    final levels = ref.read(levelConfigProvider).value ?? [];
                    if (!LevelPermissions.hasPermission(userLevel, AppPermission.createListing, levels)) {
                      LevelPermissions.showAccessDeniedDialog(context, AppPermission.createListing);
                      return;
                    }
                    context.push('/create-listing');
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 22, color: Colors.white),
                  label: Text(
                    'listings_new'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.actionBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
