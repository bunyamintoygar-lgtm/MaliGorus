import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/discussion_model.dart';
import '../../data/repositories/discussion_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/profession_label.dart';
import '../home/home_provider.dart';
import 'discussion_provider.dart';
import '../../core/widgets/level_badge.dart';
import '../../core/utils/level_permissions.dart';
import '../../core/providers/app_config_provider.dart';
import '../../features/profile/profile_provider.dart';
import '../../core/services/moderation_service.dart';
import '../../core/utils/moderation_ui.dart';

class ConsultationDetailScreen extends ConsumerStatefulWidget {
  final DiscussionModel discussion;

  const ConsultationDetailScreen({super.key, required this.discussion});

  @override
  ConsumerState<ConsultationDetailScreen> createState() => _ConsultationDetailScreenState();
}

class _ConsultationDetailScreenState extends ConsumerState<ConsultationDetailScreen> {
  late DiscussionModel _discussion;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  String? _editingReplyId;
  
  // Local Like State for Replies (Optimistic UI)
  final Map<String, bool> _localReplyLikes = {};
  final Map<String, int> _localReplyLikeCounts = {};
  String _sortBy = 'created_at';

  List<ReplyModel> _parentReplies(List<ReplyModel> all) => all.where((r) => r.parentId == null).toList();
  List<ReplyModel> _childReplies(List<ReplyModel> all) => all.where((r) => r.parentId != null).toList();



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
  void initState() {
    super.initState();
    _discussion = widget.discussion;
    // İzlenme sayısını artır
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discussionRepositoryProvider).incrementViewCount(widget.discussion.id);
    });
  }

  @override
  void didUpdateWidget(covariant ConsultationDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.discussion.id != widget.discussion.id) {
      _discussion = widget.discussion;
    }
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
        ref.invalidate(discussionRepliesProvider(widget.discussion.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingReplyId == replyId 
              ? 'discussions_reply_delete_cancel'.tr() 
              : 'discussions_reply_deleted'.tr()),
          ),
        );
      }
    }
  }

  void _handleAuthorAction(bool hasReplies, String status) {
    if (status == 'closed') {
      _confirmActivateDiscussion();
    } else if (hasReplies) {
      _confirmDeactivateDiscussion();
    } else {
      _confirmDeleteDiscussion();
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
          ref.invalidate(discussionRepliesProvider(widget.discussion.id));
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
          ref.invalidate(discussionRepliesProvider(widget.discussion.id));
          
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
    final repliesAsync = ref.watch(discussionRepliesProvider(widget.discussion.id));
    final discussion = _discussion;
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('discussions_consultation_detail'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  repliesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Text('error_loading'.tr(args: [err.toString()])),
                    data: (replies) {
                      final sortedReplies = List<ReplyModel>.from(replies);
                      if (_sortBy == 'like_count') {
                        sortedReplies.sort((a, b) => (b.likeCount).compareTo(a.likeCount));
                      } else {
                        sortedReplies.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMainPost(discussion, sortedReplies),
                          const SizedBox(height: 32),
                          if (discussion.status == 'closed')
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange[100]!),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_outline, color: Colors.orange),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'discussions_status_closed_info'.tr(),
                                      style: TextStyle(color: Colors.orange[900], fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _buildRepliesHeader(sortedReplies.length),
                          const SizedBox(height: 16),
                          if (sortedReplies.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Text('discussions_no_replies'.tr(), style: const TextStyle(color: Colors.grey)),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _parentReplies(sortedReplies).length,
                              separatorBuilder: (_, _) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final parent = _parentReplies(sortedReplies)[index];
                                final children = _childReplies(sortedReplies).where((r) => r.parentId == parent.id).toList();
  
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildReplyItem(parent, sortedReplies),
                                    if (children.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 24, top: 12),
                                        child: Column(
                                          children: children.map((child) => Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: _buildReplyItem(child, sortedReplies, isChild: true),
                                          )).toList(),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (discussion.status == 'active')
            repliesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (replies) => _buildReplyInput(discussion, replies),
            )
          else
            SafeArea(
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
            ),
        ],
      ),
    );
  }

  Widget _buildMainPost(DiscussionModel discussion, List<ReplyModel> replies) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = discussion.authorId == userId;
    final hasReplies = replies.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: discussion.isAnonymous 
                  ? null 
                  : () => context.push('/profile/${discussion.authorId}'),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                      backgroundImage: (!discussion.isAnonymous && discussion.authorAvatarUrl != null && discussion.authorAvatarUrl!.isNotEmpty) 
                        ? NetworkImage(discussion.authorAvatarUrl!) 
                        : null,
                      child: (discussion.isAnonymous || discussion.authorAvatarUrl == null || discussion.authorAvatarUrl!.isEmpty)
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (discussion.isResolved || discussion.status == 'closed' || replies.isNotEmpty) ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  (discussion.isResolved || discussion.status == 'closed' || replies.length >= 3) ? 'Çözüldü' : 'Çözüm Bekliyor',
                  style: TextStyle(
                    color: (discussion.isResolved || discussion.status == 'closed' || replies.length >= 3) ? Colors.green[700] : Colors.orange[700],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onPressed: () => _showDiscussionActions(discussion, hasReplies),
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
          const SizedBox(height: 16),
          _buildCategoryBadge(discussion.category ?? 'diger'),
          if (discussion.attachmentUrls.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFF1F3F5)),
            const SizedBox(height: 16),
            Text(
              'discussions_attachments'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 12),
            ...discussion.attachmentUrls.map((url) {
              final fileName = url.split('/').last.split('?').first;
              final fileType = fileName.split('.').last.toUpperCase();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      fileType == 'PDF' ? Icons.picture_as_pdf : Icons.insert_drive_file,
                      color: fileType == 'PDF' ? Colors.redAccent : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, size: 18, color: AppTheme.actionBlue),
                      onPressed: () => launchUrl(Uri.parse(url)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
          // İnce ve net istatistikler satırı (Stats Row)
          Row(
            children: [
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
                      'contentType': 'consultation',
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

  void _showDiscussionActions(DiscussionModel discussion, bool hasReplies) {
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
              if (!hasReplies) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Düzenle'),
                  onTap: () {
                    context.pop();
                    context.push('/create-consultation', extra: discussion);
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
              if (!discussion.isAnonymous)
                ListTile(
                  leading: const Icon(Icons.message_outlined, color: AppTheme.actionBlue),
                  title: const Text('Mesaj Gönder'),
                  onTap: () {
                    context.pop();
                    context.push('/chat/detail', extra: {
                      'userId': discussion.authorId,
                      'userName': discussion.authorName,
                      'userAvatar': discussion.authorAvatarUrl,
                      'userTitle': discussion.authorProfession,
                      'userHighestLevel': discussion.authorHighestLevel,
                    });
                  },
                ),
              ListTile(
                leading: const Icon(Icons.report_outlined, color: Colors.red),
                title: const Text('Bildir'),
                onTap: () {
                  context.pop();
                  context.push('/report', extra: {
                    'reportedId': discussion.authorId,
                    'reportedTitle': discussion.title,
                    'contentType': 'consultation',
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

  Widget _buildReplyItem(ReplyModel reply, List<ReplyModel> replies, {bool isChild = false}) {
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
                      radius: isChild ? 16 : 18,
                      backgroundColor: Colors.grey[100],
                      backgroundImage: (reply.authorAvatarUrl != null && reply.authorAvatarUrl!.isNotEmpty) 
                        ? NetworkImage(reply.authorAvatarUrl!) 
                        : null,
                      child: (reply.authorAvatarUrl == null || reply.authorAvatarUrl!.isEmpty)
                        ? Icon(Icons.person, size: isChild ? 16 : 18, color: AppTheme.primaryNavy) 
                        : null,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(reply.formattedAuthorName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isChild ? 12 : 13)),
                            if (reply.authorHighestLevel != null) ...[
                              const SizedBox(width: 4),
                              LevelBadge(levelKey: reply.authorHighestLevel!, size: isChild ? 10 : 12),
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
                              style: TextStyle(color: Colors.grey[500], fontSize: isChild ? 10 : 11),
                            ),
                            Text(
                              ' • ${_getTimeAgo(reply.createdAt)}',
                              style: TextStyle(color: Colors.grey[400], fontSize: isChild ? 10 : 11),
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

        ],
      ),
    );
  }

  Future<void> _handleReplyLike(ReplyModel reply) async {
    final repository = ref.read(discussionRepositoryProvider);
    final isLiked = !(_localReplyLikes[reply.id] ?? reply.isLiked);
    final currentCount = _localReplyLikeCounts[reply.id] ?? reply.likeCount;
    final newCount = isLiked ? currentCount + 1 : currentCount - 1;

    // UI'da hemen güncelle
    setState(() {
      _localReplyLikes[reply.id] = isLiked;
      _localReplyLikeCounts[reply.id] = newCount;
    });

    try {
      final success = await repository.toggleReplyLike(reply.id);
      if (mounted && success != isLiked) {
        setState(() {
          _localReplyLikes[reply.id] = success;
        });
      }
    } catch (e) {
      // Hata durumunda local state'den kaldır (veritabanından tekrar gelene kadar)
      if (mounted) {
        setState(() {
          _localReplyLikes.remove(reply.id);
          _localReplyLikeCounts.remove(reply.id);
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
                    'contentType': 'consultation_reply',
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

  Widget _buildReplyInput(DiscussionModel discussion, List<ReplyModel> replies) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final isAuthor = discussion.authorId == userId;
    final expertReplies = replies.where((r) => r.authorId != discussion.authorId && r.parentId == null).toList();
    final latestReplyAuthorId = replies.isNotEmpty ? replies.last.authorId : null;

    final homeState = ref.watch(homeProvider);
    final isVerified = homeState.value?.profile?.isVerified ?? false;

    String? disabledReason;
    if (_editingReplyId == null) {
      final myTopLevelReply = replies.any((r) => r.authorId == userId && r.parentId == null);
      final myLevel = homeState.value?.profile?.highestLevel;

      final levels = ref.read(levelConfigProvider).value ?? [];
      if (!isAuthor && !isVerified) {
        disabledReason = 'discussions_error_expert_only'.tr();
      } else if (!isAuthor && !LevelPermissions.hasPermission(myLevel, AppPermission.replyToConsultation, levels)) {
        disabledReason = 'discussions_error_level_low'.tr();
      } else if (!isAuthor && myTopLevelReply) {
        disabledReason = 'discussions_expert_already_answered'.tr();
      } else if (isAuthor && expertReplies.isEmpty) {
        disabledReason = 'discussions_wait_expert'.tr();
      } else if (!isAuthor && latestReplyAuthorId == userId) {
        disabledReason = 'discussions_wait_author'.tr();
      } else if (!isAuthor && expertReplies.length >= discussion.replyLimit) {
        final alreadyParticipated = expertReplies.any((r) => r.authorId == userId);
        if (!alreadyParticipated) {
          disabledReason = 'discussions_limit_reached'.tr();
        }
      }
    }

    if (disabledReason != null) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          color: Colors.grey[50],
          child: Center(child: Text(disabledReason, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13))),
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
                    Text(
                      'discussions_editing'.tr(),
                      style: const TextStyle(color: AppTheme.actionBlue, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: _cancelEditing,
                    ),
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

  Widget _buildRepliesHeader(int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Row(
        children: [
          Text(
            'Yanıtlar ($count)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            initialValue: _sortBy,
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'created_at',
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: AppTheme.actionBlue),
                    const SizedBox(width: 8),
                    Text('En Yeni', style: const TextStyle(color: AppTheme.actionBlue)),
                  ],
                ),
              ),
            ],
            child: Row(
              children: [
                Text(
                  'En Yeni',
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
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
