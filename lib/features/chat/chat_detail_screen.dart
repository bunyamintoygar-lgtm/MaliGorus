import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/supabase/credit_service.dart';
import '../home/home_provider.dart';
import '../profile/profile_provider.dart';
import '../../core/utils/name_formatter.dart';
import '../../core/widgets/level_badge.dart';
import '../../core/services/moderation_service.dart';
import '../../core/utils/moderation_ui.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? otherUserTitle;
  final String? otherUserHighestLevel;

  const ChatDetailScreen({
    super.key, 
    this.otherUserId = 'placeholder_id',
    this.otherUserName = 'common_user',
    this.otherUserAvatar,
    this.otherUserTitle,
    this.otherUserHighestLevel,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _isMuted = false;
  
  RealtimeChannel? _channel;

  List<String> _blockedUserIds = [];
  DateTime? _clearDate;

  late final String? _myId;
  
  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id;
    _initChat();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initChat() async {
    await _loadBlocks();
    await _loadClearDate();
    await _loadMuteStatus();
    await _loadMessages(true);
    _subscribeToRealtime();
    // Mesajları okundu olarak işaretle
    ref.read(chatRepositoryProvider).markMessagesAsRead(widget.otherUserId);
  }

  Future<void> _loadBlocks() async {
    final repo = ref.read(chatRepositoryProvider);
    final blocks = await repo.getBlockedUserIds();
    if (mounted) {
      setState(() {
        _blockedUserIds = blocks;
      });
    }
  }

  Future<void> _loadClearDate() async {
    final repo = ref.read(chatRepositoryProvider);
    _clearDate = await repo.getChatClearDate(widget.otherUserId);
  }

  Future<void> _loadMuteStatus() async {
    final repo = ref.read(chatRepositoryProvider);
    final status = await repo.isUserMuted(widget.otherUserId);
    if (mounted) setState(() => _isMuted = status);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _channel?.unsubscribe();
    _messageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // reverse: true kullanıldığı için listenin sonu maxScrollExtent'tir.
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadMessages(false);
      }
    }
  }

  Future<void> _loadMessages(bool isRefresh) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _messages.clear();
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final repo = ref.read(chatRepositoryProvider);
      var newMessages = await repo.getMessages(
        widget.otherUserId, 
        page: _currentPage, 
        pageSize: _pageSize, 
      );

      // Engellenen kullanıcıdan gelen mesajları filtrele
      // VE temizleme tarihinden önceki mesajları filtrele
      newMessages = newMessages.where((msg) {
        final senderId = msg['sender_id'];
        final isMe = senderId == _myId;
        
        // Eğer mesaj benden değilse ve gönderen kişi engelliyse filtrele
        final isBlocked = !isMe && _blockedUserIds.contains(senderId);
        if (isBlocked) return false;

        if (_clearDate != null && msg['created_at'] != null) {
          final msgDate = DateTime.parse(msg['created_at'] as String);
          if (msgDate.isBefore(_clearDate!)) return false;
        }
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _messages = newMessages;
          } else {
            _messages.addAll(newMessages);
          }

          if (newMessages.length < _pageSize) {
            _hasMore = false;
          }
          
          _currentPage++;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _subscribeToRealtime() {
    final repo = ref.read(chatRepositoryProvider);
    _channel = repo.subscribeToMessages((payload) {
      final senderId = payload['sender_id'];
      final receiverId = payload['receiver_id'];
      
      // Eğer mesaj benden çıkmışsa, zaten manuel olarak ekledik, mükerrer olmasın
      if (senderId == _myId) return;

      // Eğer gönderen kişi benden başkasıysa ve engelliyse mesajı yok say
      if (_blockedUserIds.contains(senderId)) return;
      
      // Sadece bu iki kişi arasındaki mesajları listeye ekle
      if ((senderId == _myId && receiverId == widget.otherUserId) ||
          (senderId == widget.otherUserId && receiverId == _myId)) {
        
        if (mounted) {
          setState(() {
            _messages.insert(0, payload);
          });
        }
      }
    });
  }

  void _onSend() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      // AI Moderasyonu ile mesajın veritabanına hiç gitmeden engellenmesi
      final isSafe = await ModerationUI.check(
        context, 
        ref.read(moderationServiceProvider), 
        body
      );

      if (!isSafe) {
        setState(() {
          _isSending = false;
        });
        return;
      }

      final creditService = ref.read(creditServiceProvider);
      final (amountProcessed, _) = await creditService.processCreditAction(
        actionKey: 'chat_message',
        description: 'chat_credit_description'.tr(),
      );

      if (amountProcessed == null) {
        setState(() {
          _isSending = false;
        });
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('credit_insufficient_title'.tr()),
              content: Text('chat_insufficient_credit'.tr()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('common_cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/credit-earn');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.actionBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('credit_earn_title'.tr()),
                ),
              ],
            ),
          );
        }
        return;
      }

      await ref.read(chatRepositoryProvider).sendMessage(widget.otherUserId, body);
      
      // Mesajı anında ekrana ekle (Realtime'ı beklemeden)
      if (mounted) {
        setState(() {
          _messages.insert(0, {
            'sender_id': _myId,
            'receiver_id': widget.otherUserId,
            'body': body,
            'created_at': DateTime.now().toIso8601String(),
          });
        });
      }

      _messageController.clear();
      
      // Kredi düştüğü için ana ekran verilerini yenile
      ref.invalidate(homeProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common_error'.tr() + ': ' + e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }


  Future<void> _toggleMute() async {
    final repo = ref.read(chatRepositoryProvider);
    bool success;
    if (_isMuted) {
      success = await repo.unmuteUser(widget.otherUserId);
    } else {
      success = await repo.muteUser(widget.otherUserId);
    }

    if (success && context.mounted) {
      setState(() => _isMuted = !_isMuted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isMuted ? 'chat_notifications_off'.tr() : 'chat_notifications_on'.tr()),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: InkWell(
          onTap: () async {
            await context.push('/profile/${widget.otherUserId}');
            _loadBlocks(); // Profil sayfasından dönüldüğünde blok durumunu tazele
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18, 
                backgroundImage: widget.otherUserAvatar != null ? NetworkImage(widget.otherUserAvatar!) : null,
                backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                child: widget.otherUserAvatar == null 
                    ? Text(
                        (widget.otherUserName == 'common_user' ? 'common_user'.tr() : NameFormatter.format(widget.otherUserName))[0].toUpperCase(), 
                        style: const TextStyle(fontSize: 14, color: AppTheme.primaryNavy, fontWeight: FontWeight.bold)
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final profileAsync = ref.watch(authorProfileProvider(widget.otherUserId));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.otherUserName == 'common_user' ? 'common_user'.tr() : NameFormatter.format(widget.otherUserName), 
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), 
                                overflow: TextOverflow.ellipsis
                              ),
                            ),
                            profileAsync.when(
                              data: (profile) => (profile?.highestLevel != null)
                                  ? Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: LevelBadge(levelKey: profile!.highestLevel, size: 12),
                                    )
                                  : const SizedBox.shrink(),
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        if (widget.otherUserTitle != null && widget.otherUserTitle!.isNotEmpty)
                          Text(
                            widget.otherUserTitle!,
                            style: TextStyle(fontSize: 11, color: Colors.blueGrey[100], fontWeight: FontWeight.normal),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isMuted ? Icons.notifications_off_outlined : Icons.notifications_none),
            tooltip: _isMuted ? 'chat_unmute'.tr() : 'chat_mute'.tr(),
            onPressed: _toggleMute,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Mesajları alttan yukarı dizecek
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Sayfa sonuna gelindiğinde (en üste kaydırıldığında) loading göster
                      if (index == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      
                      final msg = _messages[index];
                      final isMe = msg['sender_id'] == _myId;
                      return _buildChatBubble(msg['body'], isMe, msg['created_at']);
                    },
                  ),
          ),
          if (_blockedUserIds.contains(widget.otherUserId))
            Container(
              width: double.infinity,
              color: Colors.red[50],
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.block, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'chat_user_blocked_warning'.tr(),
                      style: TextStyle(color: Colors.red[700], fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref.read(chatRepositoryProvider).unblockUser(widget.otherUserId);
                      _loadBlocks();
                    },
                    child: Text('profile_unblock_user'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          _buildMessageInput(enabled: !_blockedUserIds.contains(widget.otherUserId)),
        ],
      ),
    );
  }


  Widget _buildChatBubble(String text, bool isMe, String? createdAtStr) {
    String timeText = '';
    if (createdAtStr != null) {
      final date = DateTime.parse(createdAtStr).toLocal();
      timeText = DateFormat('HH:mm').format(date);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.actionBlue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          alignment: WrapAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 4, bottom: 4),
              child: Text(
                text,
                style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
              ),
            ),
            if (timeText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  timeText,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black45,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput({bool enabled = true}) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(color: Colors.white),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: enabled,
                decoration: InputDecoration(
                  hintText: enabled ? 'chat_input_hint'.tr() : 'profile_blocked_user'.tr(),
                  filled: true,
                  fillColor: enabled ? Colors.grey[100] : Colors.grey[200],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: enabled ? AppTheme.actionBlue : Colors.grey,
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: enabled ? _onSend : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
