import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../data/repositories/chat_repository.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoading && _hasMore) {
        _loadBlockedUsers(loadMore: true);
      }
    }
  }

  Future<void> _loadBlockedUsers({bool loadMore = false, String? query}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (!loadMore) {
        _currentPage = 0;
        _blockedUsers = [];
        _hasMore = true;
      }
    });

    final results = await ref.read(chatRepositoryProvider).getBlockedUsers(
      searchQuery: query ?? _searchController.text,
      page: _currentPage,
      pageSize: _pageSize,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (results.length < _pageSize) {
          _hasMore = false;
        }
        _blockedUsers.addAll(results);
        _currentPage++;
      });
    }
  }

  Future<void> _unblockUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('profile_unblock_user'.tr()),
        content: Text('profile_unblock_confirm'.tr(args: [userName])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text('profile_unblock_user'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref.read(chatRepositoryProvider).unblockUser(userId);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile_unblocked_success'.tr(args: [userName]))),
        );
        _loadBlockedUsers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('profile_blocked_users'.tr()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'admin_users_search'.tr(),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                _loadBlockedUsers(query: value);
              },
            ),
          ),
          Expanded(
            child: _blockedUsers.isEmpty && !_isLoading
                ? Center(child: Text('profile_no_blocked_users'.tr()))
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _blockedUsers.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      if (index == _blockedUsers.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final user = _blockedUsers[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: user['user_avatar'] != null 
                              ? NetworkImage(user['user_avatar']) 
                              : null,
                          child: user['user_avatar'] == null 
                              ? Text(user['user_name'][0].toUpperCase()) 
                              : null,
                        ),
                        title: Text(user['user_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: user['user_title'] != null ? Text(user['user_title']) : null,
                        trailing: TextButton(
                          onPressed: () => _unblockUser(user['user_id'], user['user_name']),
                          child: Text('profile_unblock_user'.tr(), style: const TextStyle(color: Colors.red)),
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
