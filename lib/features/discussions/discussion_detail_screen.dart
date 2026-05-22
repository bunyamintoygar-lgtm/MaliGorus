import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/discussion_model.dart';
import '../../data/repositories/discussion_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/profession_label.dart';
import '../../core/widgets/level_badge.dart';
import '../home/home_provider.dart';
import '../../core/providers/app_config_provider.dart';
import '../../features/profile/profile_provider.dart';
import '../../core/services/moderation_service.dart';
import '../../core/utils/moderation_ui.dart';

class DiscussionDetailScreen extends ConsumerStatefulWidget {
  final DiscussionModel discussion;

  const DiscussionDetailScreen({super.key, required this.discussion});

  @override
  ConsumerState<DiscussionDetailScreen> createState() => _DiscussionDetailScreenState();
}

class _DiscussionDetailScreenState extends ConsumerState<DiscussionDetailScreen> {
  late DiscussionModel _discussion;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  String? _editingReplyId;

  // Pagination State
  List<ReplyModel> _replies = [];
  bool _isLoadingReplies = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  bool _hasMore = true;
  String? _error;
  String _sortBy = 'created_at';
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _discussion = widget.discussion;
    _loadInitialReplies();
    // İzlenme sayısını artır
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discussionRepositoryProvider).incrementViewCount(widget.discussion.id);
    });
  }

  @override
  void didUpdateWidget(covariant DiscussionDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.discussion.id != widget.discussion.id) {
      _discussion = widget.discussion;
      _loadInitialReplies();
    }
  }

  Future<void> _loadInitialReplies() async {
    setState(() {
      _isLoadingReplies = true;
      _error = null;
      _currentPage = 0;
      _hasMore = true;
    });

    try {
      final repository = ref.read(discussionRepositoryProvider);
      
      List<ReplyModel> items;
      if (widget.discussion.type == 'tartisma') {
        items = await repository.getReplies(widget.discussion.id, page: 0, pageSize: 20, sortBy: _sortBy, ascending: _ascending);
      } else {
        items = await repository.getReplies(widget.discussion.id, sortBy: _sortBy, ascending: _ascending);
      }
      
      if (mounted) {
        setState(() {
          _replies = items;
          _isLoadingReplies = false;
          if (widget.discussion.type == 'tartisma') {
            _hasMore = items.length >= 20;
          } else {
            _hasMore = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingReplies = false;
        });
      }
    }
  }

  Future<void> _loadMoreReplies() async {
    if (_isLoadingMore || !_hasMore || widget.discussion.type != 'tartisma') return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final repository = ref.read(discussionRepositoryProvider);
      final nextPage = _currentPage + 1;
      final nextItems = await repository.getReplies(widget.discussion.id, page: nextPage, pageSize: 20, sortBy: _sortBy, ascending: _ascending);

      if (mounted) {
        if (nextItems.isEmpty) {
          setState(() {
            _hasMore = false;
            _isLoadingMore = false;
          });
        } else {
          setState(() {
            _replies.addAll(nextItems);
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

  void _startEditingReply(ReplyModel reply) {
    setState(() {
      _editingReplyId = reply.id;
      _replyController.text = reply.body;
    });
    _focusNode.requestFocus();
  }

  void _cancelEditing() {
    setState(() {
      _editingReplyId = null;
      _replyController.clear();
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _deleteReply(String replyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('discussions_reply_delete_title'.tr()),
        content: Text('discussions_reply_delete_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('common_cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('common_delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final (success, _) = await ref.read(discussionRepositoryProvider).deleteReply(replyId, widget.discussion.id);
      if (success && context.mounted) {
        _loadInitialReplies();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('discussions_reply_deleted'.tr())));
      }
    }
  }

  void _confirmDeleteDiscussion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('discussions_delete_title'.tr()),
        content: Text('discussions_delete_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('common_cancel'.tr())),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(discussionRepositoryProvider).deleteDiscussion(widget.discussion.id);
              if (success && context.mounted) {
                context.pop(true);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('discussions_delete_success'.tr())));
              }
            },
            child: Text('common_delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivateDiscussion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('discussions_deactivate_title'.tr()),
        content: Text('discussions_deactivate_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('common_cancel'.tr())),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(discussionRepositoryProvider).deactivateDiscussion(widget.discussion.id);
              if (success && context.mounted) {
                context.pop(true);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('discussions_deactivate_success'.tr())));
              }
            },
            child: Text('discussions_deactivate'.tr(), style: const TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _confirmActivateDiscussion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('discussions_activate_title'.tr()),
        content: Text('discussions_activate_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('common_cancel'.tr())),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(discussionRepositoryProvider).activateDiscussion(widget.discussion.id);
              if (success && context.mounted) {
                context.pop(true);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('discussions_activate_success'.tr())));
              }
            },
            child: Text('discussions_activate'.tr(), style: const TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReply() async {
    if (_replyController.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    // AI Moderasyonu
    final isSafe = await ModerationUI.check(
      context, 
      ref.read(moderationServiceProvider), 
      _replyController.text.trim()
    );

    if (!isSafe) {
      if (mounted) setState(() => _isSending = false);
      return;
    }
    
    if (_editingReplyId != null) {
      final success = await ref.read(discussionRepositoryProvider).updateReply(_editingReplyId!, _replyController.text.trim());
      if (mounted) {
        setState(() => _isSending = false);
        if (success) {
          _cancelEditing();
          _loadInitialReplies();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('discussions_reply_updated'.tr())));
        }
      }
    } else {
      final (success, earnedAmount, newLevel) = await ref.read(discussionRepositoryProvider).addReply(
        widget.discussion.id,
        _replyController.text.trim(),
      );

      if (mounted) {
        setState(() => _isSending = false);
        if (success) {
          _replyController.clear();
          _loadInitialReplies();
          
          String message = 'discussions_reply_published'.tr();
          if (earnedAmount > 0) {
            message = 'discussions_reply_success_credit'.tr(args: [earnedAmount.toString()]);
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );

          // Seviye atlama kontrolü ve UI güncelleme için veriyi yenile
          ref.invalidate(homeProvider);
          ref.invalidate(profileProvider);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final discussion = _discussion;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    
    // Toplam satır sayısı: Ana konu (1) + Başlık (1) + Cevaplar (N) + Loading Indicator (1)
    final int baseItemsCount = 2;
    final int listCount = baseItemsCount + _replies.length + (_hasMore && widget.discussion.type == 'tartisma' ? 1 : 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('discussions_detail_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
            ),
          ),
        ),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadInitialReplies,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                cacheExtent: 2000,
                itemCount: listCount,
                itemBuilder: (context, index) {
                  // Ana konu ve detaylar
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _buildMainPost(discussion),
                    );
                  }

                  // "Cevaplar" başlığı
                  if (index == 1) {
                    return _buildRepliesHeader();
                  }

                  // Yükleme durumu / Hata / Boş durumu
                  if (_isLoadingReplies && index == 2) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (_error != null && index == 2) {
                    return Text('error_loading'.tr(args: [_error!]));
                  }

                  if (!_isLoadingReplies && _replies.isEmpty && index == 2) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text('discussions_no_replies'.tr(), style: const TextStyle(color: Colors.grey)),
                      ),
                    );
                  }

                  // Cevap listesinin indeksini hesapla
                  final replyIndex = index - baseItemsCount;

                  // Cevap Öğeleri
                  if (replyIndex >= 0 && replyIndex < _replies.length) {
                    // Sayfalama Erken Tetikleme (sondan 3. öğe)
                    if (replyIndex >= _replies.length - 3 && replyIndex < _replies.length) {
                      if (_hasMore && !_isLoadingMore && widget.discussion.type == 'tartisma') {
                        Future.microtask(() => _loadMoreReplies());
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildReplyItem(_replies[replyIndex], _replies),
                    );
                  }

                  // Sayfalama Loading Indicator
                  if (replyIndex == _replies.length) {
                    return SizedBox(
                      height: 100,
                      child: _isLoadingMore 
                          ? const Center(child: CircularProgressIndicator()) 
                          : const SizedBox.shrink(),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildMainPost(DiscussionModel discussion) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/profile/${discussion.authorId}'),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey[100],
                      backgroundImage: (discussion.authorAvatarUrl != null && discussion.authorAvatarUrl!.isNotEmpty) 
                        ? NetworkImage(discussion.authorAvatarUrl!) 
                        : null,
                      child: (discussion.authorAvatarUrl == null || discussion.authorAvatarUrl!.isEmpty)
                        ? Icon(
                            discussion.isAnonymous ? Icons.person : Icons.person, 
                            color: AppTheme.primaryNavy,
                            size: 24,
                          )
                        : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              discussion.isAnonymous ? 'discussions_anonymous_user'.tr() : discussion.formattedAuthorName, 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                            ),
                            if (!discussion.isAnonymous && discussion.authorHighestLevel != null) ...[
                              const SizedBox(width: 6),
                              LevelBadge(levelKey: discussion.authorHighestLevel!, size: 14),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (!discussion.isAnonymous)
                              ProfessionLabel(
                                professionId: discussion.authorProfession,
                                style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                              )
                            else
                              Text(
                                'discussions_anonymous_info'.tr(),
                                style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            Text(
                              ' • ${_getTimeAgo(discussion.createdAt)}',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onPressed: () => _showDiscussionActions(discussion),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            discussion.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, height: 1.3),
          ),
          const SizedBox(height: 12),
          Text(
            discussion.body,
            style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey[700]),
          ),
          const SizedBox(height: 20),
          // İnce ve net istatistikler satırı (Stats Row)
          Row(
            children: [
              Icon(Icons.thumb_up_alt_outlined, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                '${discussion.likeCount} Beğeni',
                style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              Container(width: 3, height: 3, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[400])),
              const SizedBox(width: 12),
              Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                '${discussion.replyCount} Cevap',
                style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              Container(width: 3, height: 3, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[400])),
              const SizedBox(width: 12),
              Icon(Icons.visibility_outlined, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                '${discussion.viewCount} Görüntüleme',
                style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F3F5)),
          const SizedBox(height: 12),
          // Premium Aksiyon Butonları (Action Row)
          Row(
            children: [
              _buildActionButton(
                icon: discussion.isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                label: discussion.isLiked ? 'Beğenildi' : 'Beğen',
                isSelected: discussion.isLiked,
                color: Colors.grey[700]!,
                onTap: _handleLike,
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Cevapla',
                isSelected: false,
                color: Colors.grey[700]!,
                onTap: () {
                  _focusNode.requestFocus();
                },
              ),
              const Spacer(),
              if (userId != discussion.authorId)
                _buildActionButton(
                  icon: Icons.report_problem_outlined,
                  label: 'Bildir',
                  isSelected: false,
                  color: Colors.redAccent,
                  onTap: () {
                    context.push('/report', extra: {
                      'reportedId': discussion.authorId,
                      'reportedTitle': discussion.title,
                      'contentType': 'discussion',
                      'contentId': discussion.id,
                      'contentBody': discussion.body,
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleLike() async {
    final oldDiscussion = _discussion;
    
    // UI'da hemen güncelle (Optimistic UI)
    setState(() {
      _discussion = oldDiscussion.copyWith(
        isLiked: !oldDiscussion.isLiked,
        likeCount: oldDiscussion.isLiked ? oldDiscussion.likeCount - 1 : oldDiscussion.likeCount + 1,
      );
    });

    try {
      final success = await ref.read(discussionRepositoryProvider).toggleLike(_discussion.id);
      if (mounted) {
        if (success != _discussion.isLiked) {
           setState(() {
             _discussion = _discussion.copyWith(isLiked: success);
           });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _discussion = oldDiscussion;
        });
      }
    }
  }

  Widget _buildMetricItem(IconData icon, String value, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.actionBlue.withValues(alpha: 0.08) 
              : Colors.grey[100]!.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppTheme.actionBlue.withValues(alpha: 0.2) 
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              size: 18, 
              color: isSelected ? AppTheme.actionBlue : color
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.actionBlue : color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) return '${difference.inDays} gün önce';
    if (difference.inHours > 0) return '${difference.inHours} saat önce';
    if (difference.inMinutes > 0) return '${difference.inMinutes} dk önce';
    return 'Az önce';
  }

  void _showDiscussionActions(DiscussionModel discussion) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = discussion.authorId == userId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner) ...[
              if (_replies.isEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Düzenle'),
                  onTap: () {
                    context.pop();
                    context.push('/create-discussion', extra: discussion);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Sil', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    context.pop();
                    _confirmDeleteDiscussion();
                  },
                ),
              ] else ...[
                if (discussion.status != 'closed')
                  ListTile(
                    leading: const Icon(Icons.block_outlined, color: Colors.orange),
                    title: const Text('Yayından Kaldır'),
                    onTap: () {
                      context.pop();
                      _confirmDeactivateDiscussion();
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                    title: const Text('Tekrar Yayınla'),
                    onTap: () {
                      context.pop();
                      _confirmActivateDiscussion();
                    },
                  ),
              ],
            ] else ...[
              ListTile(
                leading: const Icon(Icons.report_outlined, color: Colors.red),
                title: const Text('Bildir'),
                onTap: () {
                  context.pop();
                  context.push('/report', extra: {
                    'reportedId': discussion.authorId,
                    'reportedTitle': discussion.title,
                    'contentType': 'discussion',
                    'contentId': discussion.id,
                    'contentBody': discussion.body,
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReplyItem(ReplyModel reply, List<ReplyModel> allReplies) {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/profile/${reply.authorId}'),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[100],
                      backgroundImage: (reply.authorAvatarUrl != null && reply.authorAvatarUrl!.isNotEmpty) 
                        ? NetworkImage(reply.authorAvatarUrl!) 
                        : null,
                      child: (reply.authorAvatarUrl == null || reply.authorAvatarUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 18, color: AppTheme.primaryNavy) 
                        : null,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(reply.formattedAuthorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            if (reply.authorHighestLevel != null) ...[
                              const SizedBox(width: 6),
                              LevelBadge(levelKey: reply.authorHighestLevel!, size: 11),
                            ],
                            if (reply.authorId == widget.discussion.authorId) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.actionBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Yazar', style: TextStyle(color: AppTheme.actionBlue, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            ProfessionLabel(
                              professionId: reply.authorProfession,
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            ),
                            Text(
                              ' • ${_getTimeAgo(reply.createdAt)}',
                              style: TextStyle(color: Colors.grey[400], fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 20),
                onPressed: () => _showReplyActions(reply),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reply.body,
            style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[800]),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricItem(
                reply.isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined, 
                reply.likeCount.toString(), 
                reply.isLiked ? AppTheme.actionBlue : Colors.grey[600]!,
                onTap: () => _handleReplyLike(reply),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleReplyLike(ReplyModel reply) async {
    final repository = ref.read(discussionRepositoryProvider);
    final oldReply = reply;
    final isLiked = !reply.isLiked;
    final newCount = isLiked ? reply.likeCount + 1 : reply.likeCount - 1;

    // UI'da hemen güncelle
    setState(() {
      final index = _replies.indexWhere((r) => r.id == reply.id);
      if (index != -1) {
        _replies[index] = reply.copyWith(isLiked: isLiked, likeCount: newCount);
      }
    });

    try {
      final success = await repository.toggleReplyLike(reply.id);
      if (mounted && success != isLiked) {
        // Eğer backend sonucu farklıysa güncelle
        setState(() {
          final index = _replies.indexWhere((r) => r.id == reply.id);
          if (index != -1) {
            _replies[index] = _replies[index].copyWith(isLiked: success);
          }
        });
      }
    } catch (e) {
      // Hata durumunda geri al
      if (mounted) {
        setState(() {
          final index = _replies.indexWhere((r) => r.id == reply.id);
          if (index != -1) {
            _replies[index] = oldReply;
          }
        });
      }
    }
  }

  void _showReplyActions(ReplyModel reply) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = reply.authorId == userId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Düzenle'),
                onTap: () {
                  context.pop();
                  _startEditingReply(reply);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Sil', style: TextStyle(color: Colors.red)),
                onTap: () {
                  context.pop();
                  _deleteReply(reply.id);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.report_outlined, color: Colors.red),
                title: const Text('Bildir'),
                onTap: () {
                  context.pop();
                  context.push('/report', extra: {
                    'reportedId': reply.authorId,
                    'reportedTitle': reply.body.length > 50 ? '${reply.body.substring(0, 50)}...' : reply.body,
                    'contentType': 'discussion_reply',
                    'contentId': reply.id,
                    'contentBody': reply.body,
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRepliesHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 8),
      child: Row(
        children: [
          Text(
            'Yanıtlar (${_replies.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            initialValue: _sortBy,
            onSelected: (value) {
              setState(() {
                if (value == 'created_at') {
                  _sortBy = 'created_at';
                  _ascending = false;
                } else if (value == 'like_count') {
                  _sortBy = 'like_count';
                  _ascending = false;
                }
              });
              _loadInitialReplies();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'created_at',
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 18, color: _sortBy == 'created_at' ? AppTheme.actionBlue : Colors.grey),
                    const SizedBox(width: 8),
                    Text('En Yeni', style: TextStyle(color: _sortBy == 'created_at' ? AppTheme.actionBlue : Colors.black)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'like_count',
                child: Row(
                  children: [
                    Icon(Icons.favorite_border, size: 18, color: _sortBy == 'like_count' ? AppTheme.actionBlue : Colors.grey),
                    const SizedBox(width: 8),
                    Text('En Popüler', style: TextStyle(color: _sortBy == 'like_count' ? AppTheme.actionBlue : Colors.black)),
                  ],
                ),
              ),
            ],
            child: Row(
              children: [
                Text(
                  _sortBy == 'created_at' ? 'En Yeni' : 'En Popüler',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[600], size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    if (widget.discussion.status == 'closed') {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          color: Colors.grey[50],
          child: Center(
            child: Text(
              'discussions_status_closed_info'.tr(),
              style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13),
            ),
          ),
        ),
      );
    }
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_editingReplyId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, size: 16, color: AppTheme.actionBlue),
                    const SizedBox(width: 8),
                    Text('discussions_editing'.tr(), style: const TextStyle(color: AppTheme.actionBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, size: 16), onPressed: _cancelEditing),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'discussions_write_reply'.tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    maxLines: 4,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: AppTheme.primaryNavy,
                  child: IconButton(
                    icon: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendReply,
                  ),
                ),
              ],
            ),
          ],
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
            color: AppTheme.actionBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.actionBlue.withValues(alpha: 0.1)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.actionBlue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
