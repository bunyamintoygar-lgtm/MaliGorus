import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'home_provider.dart';
import 'main_shell.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/app_config_provider.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/discussion_model.dart';
import '../credits/credit_gift_provider.dart';
import '../../data/supabase/credit_service.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/level_model.dart';
import '../../data/models/listing_model.dart';
import '../../core/widgets/profession_label.dart';
import '../../core/utils/name_formatter.dart';
import '../../core/widgets/level_badge.dart';
import '../../core/utils/listing_utils.dart';
import '../../core/widgets/unified_header.dart';
import '../credits/level_details_dialog.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('home_logout_title'.tr()),
        content: Text('home_logout_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('home_logout_action'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: homeState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('error_loading'.tr(args: [err.toString()]))),
        data: (state) => RefreshIndicator(
          onRefresh: () => ref.read(homeProvider.notifier).loadHomeData(),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverUnifiedHeader(profile: state.profile, isAdmin: state.profile?.isAdmin ?? false),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0, bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kredi Kartı
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _buildPremiumCreditCard(context, ref, state.profile, isIntegrated: false),
                      ),

                      const SizedBox(height: 24),

                      // Hızlı Aksiyonlar (Tartış, Danış, Anket, İlan)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _buildQuickActions(context, ref),
                      ),

                      const SizedBox(height: 24),

                      // Hediye Bildirimi
                      Consumer(
                        builder: (context, ref, child) {
                          final pendingGiftAsync = ref.watch(pendingGiftProvider);
                          return pendingGiftAsync.when(
                            data: (gift) {
                              if (gift == null) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: _buildCreditGiftNotification(context, ref, gift),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          );
                        },
                      ),

                      const SizedBox(height: 28),

                      // Bildirimler
                      if (state.totalNotifications > 0) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildSectionHeader(
                            'home_notifications'.tr(),
                            Icons.notifications_rounded,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildNotificationsSection(context, state),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Son Anketler
                      if (state.latestSurveys.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildSectionHeader('home_latest_surveys'.tr(), Icons.poll_rounded, Colors.indigo),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: state.latestSurveys.asMap().entries.map((entry) {
                              final isLast = entry.key == state.latestSurveys.length - 1;
                              return Padding(
                                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                                child: _buildLatestSurveyCard(context, ref, entry.value),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Son Tartışmalar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _buildSectionHeader('home_latest_discussions'.tr(), Icons.forum_rounded, Colors.purple),
                      ),
                      const SizedBox(height: 12),
                      if (state.latestDiscussions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildEmptyState('home_no_discussions'.tr(), Icons.forum_outlined),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: state.latestDiscussions.map((d) => _buildDiscussionCard(context, d)).toList(),
                          ),
                        ),

                      const SizedBox(height: 28),
                      // Son Danışmalar
                      if (state.latestConsultations.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildSectionHeader('home_latest_consultations'.tr(), Icons.psychology_alt_rounded, Colors.orange),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: state.latestConsultations.map((d) => _buildDiscussionCard(context, d)).toList(),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Son İlanlar
                      if (state.latestListings.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildSectionHeader('home_latest_listings'.tr(), Icons.work_outline_rounded, Colors.green),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: state.latestListings.map<Widget>((l) {
                              final config = ref.read(appConfigProvider).value;
                              final categories = config?['listing_categories'] as List<dynamic>? ?? [];
                              return _buildListingCard(context, l, categories);
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────── KREDİ KARTI ──────────
  Widget _buildPremiumCreditCard(BuildContext context, WidgetRef ref, ProfileModel? profile, {bool isIntegrated = false}) {
    final balance = profile?.creditBalance ?? 0;
    final levelConfig = ref.watch(levelConfigProvider);
    
    // Mevcut seviye bilgilerini bul
    final currentLevel = levelConfig.maybeWhen(
      data: (levels) => levels.firstWhere(
        (l) {
          final k = l.key.toLowerCase();
          final search = (profile?.highestLevel ?? 'bronze').toLowerCase();
          return k == search || 
                 (k == 'bronze' && search == 'bronz') ||
                 (k == 'silver' && search == 'gümüş') ||
                 (k == 'gold' && search == 'altın') ||
                 (k == 'platinum' && search == 'platin');
        },
        orElse: () => levels.first,
      ),
      orElse: () => null,
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isIntegrated 
          ? LinearGradient(
              colors: [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : const LinearGradient(
              colors: [Color(0xFF2c3e50), Color(0xFF3498db)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
        borderRadius: BorderRadius.circular(24),
        border: isIntegrated ? Border.all(color: Colors.white.withValues(alpha: 0.2)) : null,
        boxShadow: isIntegrated ? [] : [
          BoxShadow(
            color: const Color(0xFF3498db).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('home_current_credits'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Sol İkon: Mevcut Seviye İkonu
                        Text(
                          currentLevel?.icon ?? '🛡️',
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$balance',
                          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, height: 1.0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  SizedBox(
                    width: 125, // Sabit genişlik ile butonları eşitle
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/credit-earn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2c3e50),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.emoji_events_rounded, size: 16),
                      label: Text('home_earn_credits'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Mevcut Seviye Butonu (Üstteki ile aynı uzunlukta ve benzer stilde)
                  SizedBox(
                    width: 125,
                    child: TextButton(
                      onPressed: () {
                        final levels = levelConfig.value;
                        if (levels != null && currentLevel != null) {
                          final currentIndex = levels.indexOf(currentLevel);
                          LevelDetailsDialog.show(
                            context,
                            profile: profile,
                            levels: levels,
                            currentIndex: currentIndex,
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white30),
                        ),
                      ),
                      child: Text(
                        currentLevel?.label.split(' ')[0] ?? 'home_level'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ────────── HIZLI AKSİYONLAR ──────────
  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickActionItem(
            context,
            ref,
            icon: Icons.chat_bubble_rounded,
            color: Colors.blue,
            title: 'Tartış',
            description: 'Fikir alışverişi yap',
            tabIndex: 1,
          ),
          _buildQuickActionItem(
            context,
            ref,
            icon: Icons.psychology_alt_rounded,
            color: Colors.deepPurple,
            title: 'Danış',
            description: 'Uzman görüşü al',
            tabIndex: 2,
          ),
          _buildQuickActionItem(
            context,
            ref,
            icon: Icons.bar_chart_rounded,
            color: Colors.lightBlue,
            title: 'Anketler',
            description: 'Katıl, katkı sağla',
            tabIndex: 3,
          ),
          _buildQuickActionItem(
            context,
            ref,
            icon: Icons.work_rounded,
            color: Colors.tealAccent[700]!,
            title: 'İlanlar',
            description: 'İş & Proje fırsatları',
            tabIndex: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(
    BuildContext context, 
    WidgetRef ref, {
    required IconData icon, 
    required Color color, 
    required String title, 
    required String description,
    required int tabIndex,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => ref.read(mainTabIndexProvider.notifier).setTab(tabIndex),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 10, color: Colors.grey[500], height: 1.2),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  // ────────── SECTION HEADER ──────────
  Widget _buildSectionHeader(String title, IconData icon, Color color, {int? badge}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy)),
        if (badge != null && badge > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  // ────────── GÜNÜN ANKETİ ──────────
  Widget _buildLatestSurveyCard(BuildContext context, WidgetRef ref, dynamic survey) {
    return GestureDetector(
      onTap: () {
        // Anketler sekmesine geçiş (index 3)
        ref.read(mainTabIndexProvider.notifier).setTab(3);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.indigo[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.indigo[100]!),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withValues(alpha: 0.08),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.actionBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.new_releases_rounded, size: 14, color: AppTheme.actionBlue),
                      const SizedBox(width: 4),
                      Text('home_new_survey'.tr(), style: const TextStyle(color: AppTheme.actionBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Spacer(),
                if (survey.expiresAt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'home_days_left'.tr(args: [(survey.expiresAt!.difference(DateTime.now()).inDays + 1).toString()]),
                      style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              survey.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.primaryNavy, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${survey.options.length} seçenek',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text('home_click_to_participate'.tr(), style: const TextStyle(color: AppTheme.actionBlue, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.actionBlue),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ────────── BİLDİRİMLER ──────────
  Widget _buildNotificationsSection(BuildContext context, HomeState state) {
    return Column(
      children: [
        // Yeni Duyurular (En üstte)
        ...state.latestAnnouncements.map((announcement) => _AnnouncementCard(announcement: announcement)),
        // Konulara gelen cevap bildirimleri
        ...state.myReplies.take(5).map((reply) => _buildReplyNotification(context, reply)),
        // Okunmamış mesaj bildirimleri
        ...state.unreadMessages.take(5).map((msg) => _buildMessageNotification(context, msg)),
      ],
    );
  }

  Widget _buildReplyNotification(BuildContext context, Map<String, dynamic> reply) {
    final profile = reply['profiles'] as Map<String, dynamic>?;
    final discussion = reply['discussions'] as Map<String, dynamic>?;
    final replierName = NameFormatter.format(profile?['full_name']);
    final topicTitle = discussion?['title'] ?? 'home_topic'.tr();
    final topicType = discussion?['type'] == 'danisma' ? 'home_type_consultation'.tr() : 'home_type_discussion'.tr();
    final topicId = discussion?['id'];

    return GestureDetector(
      onTap: () {
        if (topicId != null) {
          // Tartışma/Danışma detay ekranına git
          context.push('/discussion/detail', extra: DiscussionModel(
            id: topicId,
            authorId: discussion?['author_id'] ?? '',
            type: discussion?['type'] ?? 'tartisma',
            title: topicTitle,
            body: '',
            createdAt: DateTime.now(),
          ));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange[50]!),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.orange[50],
              backgroundImage: profile?['avatar_url'] != null ? NetworkImage(profile!['avatar_url']) : null,
              child: profile?['avatar_url'] == null
                  ? Text(replierName[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700]))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: AppTheme.primaryNavy, height: 1.4),
                      children: [
                        TextSpan(
                          text: replierName, 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                        ),
                        if (profile?['highest_level'] != null)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: LevelBadge(levelKey: profile!['highest_level'], size: 12),
                            ),
                          ),
                        TextSpan(
                          text: 'home_replied_to_topic'.tr(args: [topicType]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"$topicTitle"',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageNotification(BuildContext context, Map<String, dynamic> msg) {
    final profile = msg['profiles'] as Map<String, dynamic>?;
    final senderName = NameFormatter.format(profile?['full_name']);
    final profession = profile?['profession'];
    final senderId = msg['sender_id'] as String;
    final unreadCount = msg['unread_count'] ?? 1;
    final avatarUrl = profile?['avatar_url'];

    return GestureDetector(
      onTap: () {
        context.push('/chat/detail', extra: {
          'userId': senderId,
          'userName': senderName,
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue[50]!),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.actionBlue.withValues(alpha: 0.1),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(senderName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.actionBlue))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          senderName, 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile?['highest_level'] != null) ...[
                        const SizedBox(width: 4),
                        LevelBadge(levelKey: profile!['highest_level'], size: 12),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  ProfessionLabel(
                    professionId: profession,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.actionBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'home_unread_messages'.tr(args: [unreadCount.toString()]),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ────────── TARTIŞMA KARTLARI ──────────
  Widget _buildDiscussionCard(BuildContext context, DiscussionModel discussion) {
    return GestureDetector(
      onTap: () => context.push('/discussion/detail', extra: discussion),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
              backgroundImage: discussion.authorAvatarUrl != null ? NetworkImage(discussion.authorAvatarUrl!) : null,
              child: discussion.authorAvatarUrl == null
                  ? Text(
                      (discussion.authorName ?? 'common_user'.tr())[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    discussion.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                discussion.formattedAuthorName,
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
                      const SizedBox(width: 12),
                      if (discussion.replyCount > 0) ...[
                        Icon(Icons.comment_outlined, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text('${discussion.replyCount}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ────────── İLAN KARTLARI ──────────
  Widget _buildListingCard(BuildContext context, ListingModel listing, List<dynamic> categories) {
    // Kategoriye özel ikon ve rengi bul
    final categoryData = categories.firstWhere(
      (c) => c is Map && c['value'] == listing.category,
      orElse: () => null,
    );

    final iconName = categoryData?['icon'];
    final colorHex = categoryData?['color'];
    final themeColor = ListingUtils.getColor(colorHex);

    return GestureDetector(
      onTap: () => context.push('/listing-detail', extra: listing),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                ListingUtils.getIconData(iconName), 
                color: themeColor, 
                size: 24
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.location ?? 'listings_no_location'.tr(),
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (categoryData != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            categoryData['label'] ?? '',
                            style: TextStyle(
                              color: themeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ────────── HEDİYE BİLDİRİMİ ──────────
  Widget _buildCreditGiftNotification(BuildContext context, WidgetRef ref, Map<String, dynamic> gift) {
    final sender = gift['sender'] as Map<String, dynamic>?;
    final senderName = NameFormatter.format(sender?['full_name']);
    final profession = sender?['profession'] ?? '';
    final amount = gift['amount'] ?? 0;
    final senderId = gift['sender_id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.creditGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.creditGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.creditGold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: AppTheme.creditGold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                        Text(
                          'gift_title'.tr(),
                          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange[900], fontSize: 13),
                        ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 14, color: AppTheme.primaryNavy, height: 1.4),
                        children: [
                          TextSpan(text: senderName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const TextSpan(text: ' ('),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: ProfessionLabel(
                              professionId: profession,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ),
                          const TextSpan(text: ')'),
                          TextSpan(text: 'gift_received_msg'.tr(args: [amount.toString()]), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.creditGold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    await ref.read(creditServiceProvider).markGiftAsViewed(gift['id']);
                    ref.invalidate(pendingGiftProvider);
                  },
                  child: Text('common_close'.tr(), style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    context.push('/profile/other/$senderId');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.creditGold,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('profile_view'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ────────── BOŞ DURUM ──────────
  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatefulWidget {
  final Map<String, dynamic> announcement;
  const _AnnouncementCard({required this.announcement});

  @override
  State<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<_AnnouncementCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.announcement['title'] ?? '';
    final body = widget.announcement['body'] ?? '';
    final date = widget.announcement['created_at'] != null
        ? DateFormat('dd.MM HH:mm').format(DateTime.parse(widget.announcement['created_at']))
        : '';

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isExpanded 
                ? [Colors.purple[800]!, Colors.purple[600]!]
                : [Colors.purple[700]!, Colors.purple[500]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.2),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'home_announcement_badge'.tr(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            date,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: _isExpanded ? 3 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                ),
              ],
            ),
            if (_isExpanded) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: Colors.white24, height: 1),
              ),
              Text(
                body,
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
