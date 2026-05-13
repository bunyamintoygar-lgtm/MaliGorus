import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/level_badge.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/chat_repository.dart';
import '../../core/widgets/unified_header.dart';
import '../home/home_provider.dart';
import '../home/main_shell.dart';
import '../profile/profile_provider.dart';
import '../../core/utils/name_formatter.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, unread, pending, completed
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _hasMore = true;
    });

    try {
      final repository = ref.read(chatRepositoryProvider);
      final items = await repository.getChatList(
        page: 0, 
        pageSize: 20, 
        searchQuery: _searchQuery
      );
      
      if (mounted) {
        final repository = ref.read(chatRepositoryProvider);
        final blockedIds = await repository.getBlockedUserIds();
        final clearDates = await repository.getChatClearDates();

        setState(() {
          _chats = items.where((chat) {
            final partnerId = chat['partner_id'];
            
            // 1. Engelliyse gizle
            if (blockedIds.contains(partnerId)) return false;

            // 2. Temizlendiyse ve yeni mesaj yoksa gizle
            if (clearDates.containsKey(partnerId)) {
              final lastMsgTimeStr = chat['last_message_time'] as String?;
              if (lastMsgTimeStr != null) {
                final lastMsgTime = DateTime.parse(lastMsgTimeStr).toLocal();
                final clearDate = clearDates[partnerId]!.toLocal();
                if (lastMsgTime.isBefore(clearDate)) return false;
              }
            }
            
            return true;
          }).toList();
          
          _isLoading = false;
          _hasMore = items.length >= 20;
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
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final repository = ref.read(chatRepositoryProvider);
      final nextPage = _currentPage + 1;
      final nextItems = await repository.getChatList(
        page: nextPage, 
        pageSize: 20, 
        searchQuery: _searchQuery
      );

      if (mounted) {
        if (nextItems.isEmpty) {
          setState(() {
            _hasMore = false;
            _isLoadingMore = false;
          });
        } else {
          final repository = ref.read(chatRepositoryProvider);
          final blockedIds = await repository.getBlockedUserIds();
          final clearDates = await repository.getChatClearDates();

          final filteredItems = nextItems.where((chat) {
            final partnerId = chat['partner_id'];
            if (blockedIds.contains(partnerId)) return false;
            if (clearDates.containsKey(partnerId)) {
              final lastMsgTimeStr = chat['last_message_time'] as String?;
              if (lastMsgTimeStr != null) {
                final lastMsgTime = DateTime.parse(lastMsgTimeStr).toLocal();
                final clearDate = clearDates[partnerId]!.toLocal();
                if (lastMsgTime.isBefore(clearDate)) return false;
              }
            }
            return true;
          }).toList();

          setState(() {
            _chats.addAll(filteredItems);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          UnifiedHeader(profile: ref.watch(homeProvider).value?.profile),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadInitialData,
              child: CustomScrollView(
                slivers: [
                  // Başlık ve Yeni Mesaj Butonu
                  SliverToBoxAdapter(
                    child: _buildTitleSection(),
                  ),

                  // Arama Çubuğu
                  SliverToBoxAdapter(
                    child: _buildSearchBar(),
                  ),


                  // Mesaj Listesi
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: _isLoading 
                        ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                        : _error != null
                            ? SliverFillRemaining(child: Center(child: Text('common_error_occurred'.tr(args: [_error ?? '']))))
                            : _chats.isEmpty
                                ? SliverFillRemaining(child: _buildEmptyState())
                                : _buildSliverList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'messages'.tr(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A237E),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'chat_subtitle'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'chat_search_hint'.tr(),
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
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
              'chat_no_results'.tr(),
              style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Illustration
              Image.asset(
                'assets/icons/message_buble_icon.png',
                height: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Henüz bir mesajınız yok',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A237E),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Meslektaşlarınızla iletişime geçerek\nsorularınıza hızlıca çözüm bulun.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              
              // Primary Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/create-discussion');
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 22, color: Colors.white),
                  label: const Text(
                    'Yeni Tartışma Başlat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'veya',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                ],
              ),
              const SizedBox(height: 24),
              
              // Secondary Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(mainTabIndexProvider.notifier).setTab(2);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[200]!, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 22, color: Color(0xFF1A237E)),
                      const SizedBox(width: 12),
                      const Text(
                        'Uzman & Meslektaşları Keşfet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A237E), // Dark Navy
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Tip Container
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF4F7FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF2196F3), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5),
                            children: const [
                              TextSpan(
                                text: 'İpucu: ',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text: 'Danışma',
                                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2196F3)),
                              ),
                              TextSpan(
                                text: ' bölümünden uzmanlara sorularınızı yöneltebilirsiniz.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildSliverList() {
    // Filtreleme mantığı
    var filteredChats = _chats;
    if (_selectedFilter == 'unread') {
      filteredChats = _chats.where((c) => (c['unread_count'] ?? 0) > 0).toList();
    }
    // 'pending' ve 'completed' için veri modelinde statü alanı olması gerekir, 
    // şu an için boş liste dönebilirler veya tümünü gösterebilirler.

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == filteredChats.length) {
            return _isLoadingMore 
                ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())) 
                : const SizedBox.shrink();
          }

          if (index >= filteredChats.length - 3 && index < filteredChats.length && _hasMore && !_isLoadingMore) {
            Future.microtask(() => _loadMore());
          }

          return _buildChatCard(filteredChats[index]);
        },
        childCount: filteredChats.length + (_hasMore ? 1 : 0),
      ),
    );
  }

  Widget _buildChatCard(Map<String, dynamic> chat) {
    final partnerName = NameFormatter.format(chat['partner_name']);
    final partnerAvatar = chat['partner_avatar'];
    final lastMessage = chat['last_message_body'] ?? '';
    final unreadCount = chat['unread_count'] ?? 0;
    
    String timeText = '';
    if (chat['last_message_time'] != null) {
      final date = DateTime.parse(chat['last_message_time']).toLocal();
      final now = DateTime.now();
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        timeText = DateFormat('HH:mm').format(date);
      } else if (now.difference(date).inDays < 2) {
        timeText = 'common_yesterday'.tr();
      } else {
        timeText = 'common_days_ago'.tr(args: [now.difference(date).inDays.toString()]);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          await context.push('/chat/detail', extra: {
            'userId': chat['partner_id'],
            'userName': partnerName,
            'userAvatar': partnerAvatar,
            'userTitle': chat['partner_title'],
          });
          _loadInitialData(); // Geri dönüldüğünde listeyi tazele
        },
        onLongPress: () => _showDeleteDialog(chat),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: partnerAvatar != null ? NetworkImage(partnerAvatar) : null,
                    backgroundColor: const Color(0xFFE8EAF6),
                    child: partnerAvatar == null 
                        ? const Icon(Icons.person, color: Color(0xFF1A237E), size: 28)
                        : null,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // İçerik
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Consumer(
                            builder: (context, ref, child) {
                              final profileAsync = ref.watch(authorProfileProvider(chat['partner_id']));
                              return Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      partnerName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF263238)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  profileAsync.when(
                                    data: (profile) => (profile?.highestLevel != null)
                                        ? const Padding(
                                            padding: EdgeInsets.only(left: 6),
                                            child: Icon(Icons.shield_outlined, size: 14, color: Color(0xFFB0BEC5)),
                                          )
                                        : const SizedBox.shrink(),
                                    loading: () => const SizedBox.shrink(),
                                    error: (_, _) => const SizedBox.shrink(),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lastMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.3),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(timeText, style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        Row(
                          children: [
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Color(0xFF2196F3), shape: BoxShape.circle),
                                child: Text(
                                  unreadCount.toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              )
                            else
                              Icon(Icons.done_all_rounded, size: 16, color: Colors.grey[400]),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> chat) {
    bool blockUser = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('chat_delete_title'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('chat_delete_confirm'.tr(args: [chat['partner_name']])),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text('chat_block_user'.tr(), style: const TextStyle(fontSize: 14)),
                value: blockUser,
                activeColor: AppTheme.actionBlue,
                onChanged: (val) => setDialogState(() => blockUser = val ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common_cancel'.tr(), style: const TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final repo = ref.read(chatRepositoryProvider);
                if (blockUser) {
                  await repo.blockUser(chat['partner_id']);
                }
                final success = await repo.deleteChat(chat['partner_id']);
                if (success) {
                  _loadInitialData(); // Listeyi yenile
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('chat_delete_error'.tr())),
                    );
                  }
                }
              },
              child: Text('common_delete'.tr(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
