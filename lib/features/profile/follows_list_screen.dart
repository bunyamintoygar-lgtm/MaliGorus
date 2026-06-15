import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/level_badge.dart';
import '../../core/providers/app_config_provider.dart';
import '../../data/models/profile_model.dart';
import '../../core/utils/level_permissions.dart';
import '../home/home_provider.dart';
import 'profile_provider.dart';
import 'follower_provider.dart';
import '../../data/repositories/follower_repository.dart';

class FollowsListScreen extends ConsumerStatefulWidget {
  final String userId;
  final String initialTab; // 'followers' or 'following'

  const FollowsListScreen({
    super.key,
    required this.userId,
    required this.initialTab,
  });

  @override
  ConsumerState<FollowsListScreen> createState() => _FollowsListScreenState();
}

class _FollowsListScreenState extends ConsumerState<FollowsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name_asc'; // 'name_asc', 'name_desc', 'newest'
  Timer? _debounceTimer;

  // Pagination states
  List<ProfileModel> _followers = [];
  int _followersPage = 0;
  bool _loadingFollowers = false;
  bool _loadingMoreFollowers = false;
  bool _hasMoreFollowers = true;

  List<ProfileModel> _following = [];
  int _followingPage = 0;
  bool _loadingFollowing = false;
  bool _loadingMoreFollowing = false;
  bool _hasMoreFollowing = true;

  static const int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == 'following' ? 1 : 0,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _searchController.addListener(_onSearchChanged);

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFollowers(clear: true);
      _loadFollowing(clear: true);
    });
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.trim();
      if (query != _searchQuery) {
        setState(() {
          _searchQuery = query;
        });
        _loadFollowers(clear: true);
        _loadFollowing(clear: true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFollowers({bool clear = false}) async {
    if (clear) {
      setState(() {
        _followersPage = 0;
        _followers = [];
        _hasMoreFollowers = true;
        _loadingFollowers = true;
      });
    } else {
      if (_loadingFollowers || _loadingMoreFollowers || !_hasMoreFollowers) return;
      setState(() {
        _loadingMoreFollowers = true;
      });
    }

    try {
      final repo = ref.read(followerRepositoryProvider);
      final newItems = await repo.getFollowersListPaginated(
        userId: widget.userId,
        page: _followersPage,
        pageSize: _pageSize,
        searchQuery: _searchQuery,
        sortBy: _sortBy,
      );

      if (mounted) {
        setState(() {
          _followers.addAll(newItems);
          _followersPage++;
          _hasMoreFollowers = newItems.length == _pageSize;
          _loadingFollowers = false;
          _loadingMoreFollowers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingFollowers = false;
          _loadingMoreFollowers = false;
        });
      }
    }
  }

  Future<void> _loadFollowing({bool clear = false}) async {
    if (clear) {
      setState(() {
        _followingPage = 0;
        _following = [];
        _hasMoreFollowing = true;
        _loadingFollowing = true;
      });
    } else {
      if (_loadingFollowing || _loadingMoreFollowing || !_hasMoreFollowing) return;
      setState(() {
        _loadingMoreFollowing = true;
      });
    }

    try {
      final repo = ref.read(followerRepositoryProvider);
      final newItems = await repo.getFollowingListPaginated(
        userId: widget.userId,
        page: _followingPage,
        pageSize: _pageSize,
        searchQuery: _searchQuery,
        sortBy: _sortBy,
      );

      if (mounted) {
        setState(() {
          _following.addAll(newItems);
          _followingPage++;
          _hasMoreFollowing = newItems.length == _pageSize;
          _loadingFollowing = false;
          _loadingMoreFollowing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingFollowing = false;
          _loadingMoreFollowing = false;
        });
      }
    }
  }

  String _getProfessionLabel(ProfileModel profile, AsyncValue<Map<String, dynamic>> configAsync) {
    return configAsync.maybeWhen(
      data: (config) {
        final professionsRaw = config['professions'] ?? config['profession'];
        List<dynamic> professions = [];
        if (professionsRaw is List) {
          professions = professionsRaw;
        } else if (professionsRaw is Map) {
          professions = professionsRaw.values.toList();
        }
        
        if (professions.isEmpty) return profile.profession ?? '-';
 
        for (var p in professions) {
          if (p is Map) {
            final id = (p['id'] ?? p['ID'] ?? p['value'] ?? '').toString().trim().toUpperCase();
            final currentProf = profile.profession?.trim().toUpperCase() ?? '';
            if (id == currentProf && id.isNotEmpty) {
              return (p['label'] ?? p['name'] ?? p['title'] ?? id).toString();
            }
          }
        }
        return profile.profession ?? '-';
      },
      orElse: () => profile.profession ?? '-',
    );
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Sıralama Seçenekleri',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.sort_by_alpha, color: _sortBy == 'name_asc' ? const Color(0xFF4A3AFF) : Colors.grey),
                title: const Text('Alfabetik (A-Z)'),
                trailing: _sortBy == 'name_asc' ? const Icon(Icons.check, color: Color(0xFF4A3AFF)) : null,
                onTap: () {
                  setState(() => _sortBy = 'name_asc');
                  _loadFollowers(clear: true);
                  _loadFollowing(clear: true);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.sort_by_alpha, color: _sortBy == 'name_desc' ? const Color(0xFF4A3AFF) : Colors.grey),
                title: const Text('Alfabetik (Z-A)'),
                trailing: _sortBy == 'name_desc' ? const Icon(Icons.check, color: Color(0xFF4A3AFF)) : null,
                onTap: () {
                  setState(() => _sortBy = 'name_desc');
                  _loadFollowers(clear: true);
                  _loadFollowing(clear: true);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.calendar_today, color: _sortBy == 'newest' ? const Color(0xFF4A3AFF) : Colors.grey),
                title: const Text('En Son Kayıt Olanlar'),
                trailing: _sortBy == 'newest' ? const Icon(Icons.check, color: Color(0xFF4A3AFF)) : null,
                onTap: () {
                  setState(() => _sortBy = 'newest');
                  _loadFollowers(clear: true);
                  _loadFollowing(clear: true);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOptionsMenu(BuildContext context, ProfileModel profile, String professionLabel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline, color: AppTheme.primaryNavy),
                title: const Text('Profili Gör'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/profile/${profile.id}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline, color: AppTheme.actionBlue),
                title: const Text('Mesaj Gönder'),
                onTap: () {
                  Navigator.pop(context);
                  final myLevel = ref.read(homeProvider).value?.profile?.highestLevel;
                  final levels = ref.read(levelConfigProvider).value ?? [];
                  if (!LevelPermissions.hasPermission(myLevel, AppPermission.sendDirectMessage, levels)) {
                    LevelPermissions.showAccessDeniedDialog(context, AppPermission.sendDirectMessage);
                    return;
                  }
                  context.push('/chat/detail', extra: {
                    'userId': profile.id,
                    'userName': profile.displayName,
                    'userAvatar': profile.avatarUrl,
                    'userTitle': professionLabel,
                    'userHighestLevel': profile.highestLevel,
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(authorProfileProvider(widget.userId));
    final configAsync = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _tabController.index == 0 ? 'Takipçiler' : 'Takip Edilenler',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('error_loading'.tr(args: [err.toString()]))),
        data: (targetProfile) {
          if (targetProfile == null) {
            return const Center(child: Text('Kullanıcı bulunamadı.'));
          }

          final targetProfession = _getProfessionLabel(targetProfile, configAsync);

          return Column(
            children: [
              // Mockup style user profile overview header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: targetProfile.avatarUrl != null
                              ? NetworkImage(targetProfile.avatarUrl!)
                              : null,
                          backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                          child: targetProfile.avatarUrl == null
                              ? Text(
                                  targetProfile.displayName.isNotEmpty
                                      ? targetProfile.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryNavy,
                                  ),
                                )
                              : null,
                        ),
                        // Online status dot
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: targetProfile.id.hashCode % 3 != 0 ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                targetProfile.displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                              const SizedBox(width: 6),
                              LevelBadge(levelKey: targetProfile.highestLevel, size: 14),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            targetProfession.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.actionBlue,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Consumer(
                            builder: (context, ref, child) {
                              final countsAsync = ref.watch(followCountsProvider(widget.userId));
                              return countsAsync.when(
                                data: (counts) {
                                  return Row(
                                    children: [
                                      Text(
                                        '${counts.followersCount}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.actionBlue,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Takipçi',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '|',
                                        style: TextStyle(
                                          color: Colors.grey[300],
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${counts.followingCount}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.actionBlue,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Takip Edilen',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                                loading: () => const SizedBox(height: 16),
                                error: (_, __) => const SizedBox(height: 16),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF4A3AFF),
                labelColor: const Color(0xFF4A3AFF),
                unselectedLabelColor: Colors.grey[600],
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                tabs: const [
                  Tab(text: 'Takipçiler'),
                  Tab(text: 'Takip Edilenler'),
                ],
              ),
              const Divider(height: 1),

              // Search & Sort Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: _tabController.index == 0 ? 'Takipçi ara...' : 'Takip edilen ara...',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => _showSortMenu(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              'Sırala',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey[600]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Tab View Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUsersList(isFollowersTab: true),
                    _buildUsersList(isFollowersTab: false),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUsersList({required bool isFollowersTab}) {
    final configAsync = ref.watch(appConfigProvider);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final isLoading = isFollowersTab ? _loadingFollowers : _loadingFollowing;
    final items = isFollowersTab ? _followers : _following;
    final hasMore = isFollowersTab ? _hasMoreFollowers : _hasMoreFollowing;
    final loadMoreFn = isFollowersTab ? _loadFollowers : _loadFollowing;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          loadMoreFn();
        }
        return true;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic total count text matching mockup: "Toplam X takipçi"
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0, top: 4.0),
            child: Consumer(
              builder: (context, ref, child) {
                final countsAsync = ref.watch(followCountsProvider(widget.userId));
                return countsAsync.when(
                  data: (counts) {
                    final totalCount = isFollowersTab ? counts.followersCount : counts.followingCount;
                    return Text(
                      isFollowersTab 
                          ? 'Toplam $totalCount takipçi'
                          : 'Toplam $totalCount takip edilen',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500],
                      ),
                    );
                  },
                  loading: () => Text(
                    isFollowersTab ? 'Toplam - takipçi' : 'Toplam - takip edilen',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                    ),
                  ),
                  error: (_, __) => Text(
                    isFollowersTab ? 'Toplam - takipçi' : 'Toplam - takip edilen',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'Kayıt bulunamadı.',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: items.length + (hasMore ? 1 : 0),
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A3AFF)),
                              ),
                            ),
                          ),
                        );
                      }

                      final profile = items[index];
                      final profession = _getProfessionLabel(profile, configAsync);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            // Avatar with online status
                            GestureDetector(
                              onTap: () => context.push('/profile/${profile.id}'),
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: profile.avatarUrl != null
                                        ? NetworkImage(profile.avatarUrl!)
                                        : null,
                                    backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                                    child: profile.avatarUrl == null
                                        ? Text(
                                            profile.displayName.isNotEmpty
                                                ? profile.displayName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryNavy,
                                            ),
                                          )
                                        : null,
                                  ),
                                  // Status indicator dot
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: profile.id.hashCode % 3 != 0 ? Colors.green : Colors.grey,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Name and profession info
                            Expanded(
                              child: GestureDetector(
                                onTap: () => context.push('/profile/${profile.id}'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          profile.displayName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryNavy,
                                          ),
                                        ),
                                        if (profile.isVerified) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified, size: 14, color: Colors.blue),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      profession,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Action button & menu on the right
                            if (profile.id != currentUserId) ...[
                              Consumer(
                                builder: (context, ref, child) {
                                  final isFollowingAsync = ref.watch(isFollowingProvider(profile.id));
                                  return isFollowingAsync.when(
                                    data: (isFollowing) {
                                      if (isFollowing) {
                                        // "Takip Ediliyor" Button - light blue fill with check icon
                                        return SizedBox(
                                          height: 32,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFEFF3FF),
                                              foregroundColor: const Color(0xFF4A3AFF),
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed: () async {
                                              final repo = ref.read(followerRepositoryProvider);
                                              await repo.unfollowUser(profile.id);
                                              ref.invalidate(isFollowingProvider(profile.id));
                                              ref.invalidate(followCountsProvider(widget.userId));
                                              _loadFollowers(clear: true);
                                              _loadFollowing(clear: true);
                                              if (currentUserId != null) {
                                                ref.invalidate(followCountsProvider(currentUserId));
                                                ref.invalidate(followingListProvider(currentUserId));
                                              }
                                            },
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check, size: 14),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Takip Ediliyor',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      } else {
                                        // "Takip Et" Button - outline button with border
                                        return SizedBox(
                                          height: 32,
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF4A3AFF),
                                              side: const BorderSide(color: Color(0xFF4A3AFF)),
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed: () async {
                                              final repo = ref.read(followerRepositoryProvider);
                                              await repo.followUser(profile.id);
                                              ref.invalidate(isFollowingProvider(profile.id));
                                              ref.invalidate(followCountsProvider(widget.userId));
                                              _loadFollowers(clear: true);
                                              _loadFollowing(clear: true);
                                              if (currentUserId != null) {
                                                ref.invalidate(followCountsProvider(currentUserId));
                                                ref.invalidate(followingListProvider(currentUserId));
                                              }
                                            },
                                            child: const Text(
                                              'Takip Et',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    loading: () => const SizedBox(
                                      width: 80,
                                      height: 32,
                                      child: Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    ),
                                    error: (_, __) => const SizedBox.shrink(),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.more_horiz, color: Colors.grey[500]),
                                onPressed: () => _showOptionsMenu(context, profile, profession),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
