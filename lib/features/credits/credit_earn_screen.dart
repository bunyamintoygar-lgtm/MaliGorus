import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'credit_provider.dart';
import '../home/home_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/supabase/credit_service.dart';
import 'package:go_router/go_router.dart';
import '../home/main_shell.dart';
import 'review_dialog.dart';
import 'refer_friend_dialog.dart';
import 'share_link_dialog.dart';
import '../../data/services/iap_service.dart';
import '../../data/models/profile_model.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/repositories/referral_repository.dart';
import 'package:flutter/services.dart';

class CreditEarnScreen extends ConsumerStatefulWidget {
  const CreditEarnScreen({super.key});

  @override
  ConsumerState<CreditEarnScreen> createState() => _CreditEarnScreenState();
}

class _CreditEarnScreenState extends ConsumerState<CreditEarnScreen> {
  Map<String, dynamic>? _creditPrices;
  bool _loadingPrices = true;
  String? _referralCode;
  bool _loadingReferralCode = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadPrices(),
      _loadReferralCode(),
    ]);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      final state = ref.read(creditLogsProvider);
      if (!state.loading && !state.loadingMore && state.hasMore) {
        ref.read(creditLogsProvider.notifier).loadLogs(isRefresh: false);
      }
    }
  }

  Future<void> _loadPrices() async {
    try {
      final prices = await ref.read(creditServiceProvider).getCreditPrices();
      if (mounted) {
        setState(() {
          _creditPrices = prices;
          _loadingPrices = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPrices = false);
    }
  }

  Future<void> _loadReferralCode() async {
    try {
      final code = await ref.read(referralRepositoryProvider).getMyReferralCode();
      if (mounted) {
        setState(() {
          _referralCode = code;
          _loadingReferralCode = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingReferralCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final logsState = ref.watch(creditLogsProvider);
    final marketEnabled = ref.watch(marketEnabledProvider).value ?? false;
    final statsAsync = ref.watch(creditStatsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Minimalist Header
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFF1a237e),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text('credit_earn_title'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            actions: [
              IconButton(
                onPressed: () => _showCreditsInfo(context),
                icon: const Icon(Icons.info_outline_rounded),
              ),
            ],
          ),
          // Premium Balance & Info Section
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPremiumBalanceCard(context, ref, homeState.value?.profile, statsAsync),
                const SizedBox(height: 16),
                _buildAboutCreditsCard(context),
                const SizedBox(height: 24),

                // --- BÖLÜM 1: Kredi Kazanma Yöntemleri ---
                _buildSectionTitle('credits_earn_methods'.tr(), Icons.emoji_events_rounded, Colors.orange),
                const SizedBox(height: 12),
                _loadingPrices
                    ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                    : _buildEarnMethods(marketEnabled),

                const SizedBox(height: 24),

                // --- BÖLÜM 2: Kredi Paketleri ---
                _buildCreditPackages(ref),

                const SizedBox(height: 16),
                _buildReferralCard(),
                _buildSpendMethods(marketEnabled),

                const SizedBox(height: 32),

                // --- BÖLÜM 3: Geçmiş İşlemler ---
                _buildSectionTitle(
                  'credits_history'.tr(), 
                  Icons.history_rounded, 
                  Colors.blueGrey,
                  onViewAll: () => context.push('/credits/history'),
                ),
                const SizedBox(height: 12),
                _buildLogsList(logsState, limit: 3),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLogsList(CreditLogsState state, {int? limit}) {
    final allLogs = state.logs;
    final logs = limit != null ? allLogs.take(limit).toList() : allLogs;

    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (logs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('credits_no_transactions'.tr(), style: TextStyle(color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ...logs.map((log) => _buildLogItem(log)),
          if (limit == null) ...[
            if (state.loadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            if (!state.hasMore && logs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'credits_all_listed'.tr(),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final amount = (log['amount'] ?? 0) as int;
    final action = (log['action'] ?? '') as String;
    final createdAt = log['created_at'] as String?;
    final isEarn = amount >= 0;
    
    final color = isEarn ? Colors.green : Colors.red;
    final prefix = isEarn ? '+' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getLogIconColor(action).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getLogIcon(action), color: _getLogIconColor(action), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getLogActionTitle(action, log['description']),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatLogDateTime(createdAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '$prefix$amount',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color, {VoidCallback? onViewAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy)),
          if (onViewAll != null) ...[
            const Spacer(),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                'common_all'.tr(),
                style: const TextStyle(
                  color: AppTheme.actionBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEarnMethods(bool marketEnabled) {
    final methods = <Map<String, dynamic>>[
      {
        'key': 'survey_vote',
        'title': 'credits_method_survey_vote'.tr(),
        'description': 'credits_method_survey_vote_desc'.tr(),
        'icon': Icons.poll_rounded,
        'color': Colors.blue,
      },
      {
        'key': 'discussion_reply',
        'title': 'credits_method_discussion_reply'.tr(),
        'description': 'credits_method_discussion_reply_desc'.tr(),
        'icon': Icons.forum_rounded,
        'color': Colors.purple,
      },
      {
        'key': 'consultation_reply',
        'title': 'credits_method_consultation_reply'.tr(),
        'description': 'credits_method_consultation_reply_desc'.tr(),
        'icon': Icons.psychology_alt_rounded,
        'color': Colors.teal,
      },
      {
        'key': 'app_review',
        'title': 'credits_method_app_review'.tr(),
        'description': 'credits_method_app_review_desc'.tr(),
        'icon': Icons.rate_review_rounded,
        'color': Colors.amber,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ...methods.map((m) => _buildMethodCard(m, isEarn: true)),
        ],
      ),
    );
  }

  Widget _buildSpendMethods(bool marketEnabled) {
    // Harcama yöntemleri
    final spendMethods = <Map<String, dynamic>>[
      {
        'key': 'survey_create',
        'title': 'credits_method_survey_create'.tr(),
        'description': 'credits_method_survey_create_desc'.tr(),
        'icon': Icons.add_chart_rounded,
        'color': Colors.red,
      },
      {
        'key': 'listing_create',
        'title': 'credits_method_listing_create'.tr(),
        'description': 'credits_method_listing_create_desc'.tr(),
        'icon': Icons.post_add_rounded,
        'color': Colors.red,
      },
      {
        'key': 'discussion_create',
        'title': 'credits_method_discussion_create'.tr(),
        'description': 'credits_method_discussion_create_desc'.tr(),
        'icon': Icons.forum_outlined,
        'color': Colors.orange,
      },
      {
        'key': 'consultation_ask',
        'title': 'credits_method_consultation_ask'.tr(),
        'description': 'credits_method_consultation_ask_desc'.tr(),
        'icon': Icons.psychology_outlined,
        'color': Colors.deepOrange,
      },
      if (marketEnabled)
        {
          'key': 'promotion_buy',
          'title': 'credits_method_market'.tr(),
          'description': 'credits_method_market_desc'.tr(),
          'icon': Icons.card_giftcard_rounded,
          'color': Colors.indigo,
        },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('credits_spend_methods'.tr(), style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          ...spendMethods.map((m) => _buildMethodCard(m, isEarn: false)),
        ],
      ),
    );
  }

  Widget _buildReferralCard() {
    if (_loadingReferralCode) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
      );
    }

    final referralLink = _referralCode != null 
        ? 'https://maligorus.com/?ref=$_referralCode'
        : 'https://maligorus.com';

    final hasCode = _referralCode != null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'credits_referral_title'.tr(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'credits_referral_subtitle'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.actionBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    referralLink,
                    style: const TextStyle(
                      color: AppTheme.actionBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _copyLink(referralLink),
                  child: const Icon(
                    Icons.copy_rounded,
                    color: AppTheme.actionBlue,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasCode ? () => Share.share('MaliGörüş uygulamasına katıl, birlikte kazanalım! $referralLink') : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: AppTheme.actionBlue.withValues(alpha: 0.3)),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Linki Paylaş', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasCode ? () => Share.share('MaliGörüş uygulamasına katıl, birlikte kazanalım! $referralLink') : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: AppTheme.actionBlue.withValues(alpha: 0.3)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Davet Et', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyLink(String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('credits_link_copied'.tr()),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMethodCard(Map<String, dynamic> method, {required bool isEarn}) {
    final amount = _creditPrices?[method['key']] ?? 0;
    final color = method['color'] as Color;

    return InkWell(
      onTap: () {
        final key = method['key'] as String;
        switch (key) {
          case 'survey_vote':
            ref.read(mainTabIndexProvider.notifier).setTab(3);
            context.pop();
            break;
          case 'discussion_reply':
            ref.read(mainTabIndexProvider.notifier).setTab(1);
            context.pop();
            break;
          case 'consultation_reply':
            ref.read(mainTabIndexProvider.notifier).setTab(2);
            context.pop();
            break;
          case 'survey_create':
            context.push('/create-survey');
            break;
          case 'listing_create':
            context.push('/create-listing');
            break;
          case 'promotion_buy':
            context.push('/promotions/market');
            break;
          case 'chat_message':
            ref.read(mainTabIndexProvider.notifier).setTab(5); // Chat tab
            context.pop();
            break;
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(method['icon'] as IconData, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(method['description'] as String, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isEarn ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isEarn ? '+$amount' : '$amount',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isEarn ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditPackages(WidgetRef ref) {
    final iapState = ref.watch(iapProvider);
    final homeState = ref.watch(homeProvider).value;
    final profile = homeState?.profile;

    if (profile == null) return const SizedBox.shrink();

    final fallbackProducts = [
      ProductDetails(
        id: 'credit_100',
        title: '100 Kredi Paketi',
        description: 'Acil sorular ve anket oylaması için ideal başlangıç paketi.',
        price: '₺34.99',
        rawPrice: 34.99,
        currencyCode: 'TRY',
        currencySymbol: '₺',
      ),
      ProductDetails(
        id: 'credit_250',
        title: '250 Kredi Paketi',
        description: 'Geniş kapsamlı anketler ve tartışma başlatma için ideal.',
        price: '₺79.99',
        rawPrice: 79.99,
        currencyCode: 'TRY',
        currencySymbol: '₺',
      ),
      ProductDetails(
        id: 'credit_500',
        title: '500 Kredi Paketi',
        description: 'Uzman danışma ve detaylı analizler için en uygun paket.',
        price: '₺149.99',
        rawPrice: 149.99,
        currencyCode: 'TRY',
        currencySymbol: '₺',
      ),
      ProductDetails(
        id: 'credit_1000',
        title: '1000 Kredi Paketi',
        description: 'Çok sayıda anket oylama ve uzman danışması için avantajlı paket.',
        price: '₺279.99',
        rawPrice: 279.99,
        currencyCode: 'TRY',
        currencySymbol: '₺',
      ),
      ProductDetails(
        id: 'mg_credit_5000',
        title: '5000 Kredi Paketi',
        description: 'Gold üyelik seviyesine anında yükselin ve tüm avantajları açın.',
        price: '₺1199.99',
        rawPrice: 1199.99,
        currencyCode: 'TRY',
        currencySymbol: '₺',
      ),
      ProductDetails(
        id: 'credit_10000',
        title: '10000 Kredi Paketi',
        description: 'Platinum üyelik seviyesi ve sınırsız danışmanlık fırsatları.',
        price: '₺1999.99',
        rawPrice: 1999.99,
        currencyCode: 'TRY',
        currencySymbol: '₺',
      ),
    ];

    Widget buildList(List<ProductDetails> products) {
      final productsToShow = products.isNotEmpty ? products : fallbackProducts;
      final sortedProducts = List<ProductDetails>.from(productsToShow)..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('credits_buy_packages_title'.tr(), Icons.shopping_bag_rounded, Colors.purple),
            const SizedBox(height: 16),

            // --- Paket Listesi ---
            ...sortedProducts.map((product) => _buildMinimalistPackageCard(product, ref, profile)),
          ],
        ),
      );
    }

    return iapState.when(
      data: (products) => buildList(products),
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
      error: (err, stack) => buildList([]),
    );
  }

  Widget _buildLevelProgressCard(ProfileModel profile) {
    final credits = profile.creditBalance;
    final level = profile.highestLevel.toLowerCase();
    
    String title = '';
    String subtitle = '';
    double progress = 0;
    Color color = AppTheme.actionBlue;

    if (level == 'gold') {
      title = 'credits_level_gold'.tr();
      subtitle = 'credits_level_max_msg'.tr();
      progress = 1.0;
      color = Colors.orange;
    } else if (level == 'silver') {
      title = 'credits_level_silver'.tr();
      final diff = 5000 - credits;
      subtitle = 'credits_level_remaining'.tr(args: ['Gold', diff > 0 ? diff.toString() : '0']);
      progress = (credits / 5000).clamp(0.0, 1.0);
      color = AppTheme.creditGold;
    } else {
      title = 'credits_level_silver_target'.tr();
      final diff = 1000 - credits;
      subtitle = 'credits_level_remaining'.tr(args: ['Silver', diff > 0 ? diff.toString() : '0']);
      progress = (credits / 1000).clamp(0.0, 1.0);
      color = Colors.blueGrey;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                ],
              ),
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalistPackageCard(ProductDetails product, WidgetRef ref, ProfileModel profile) {
    final level = profile.highestLevel.toLowerCase();
    final isPopular = product.id.contains('1000') && level == 'bronze'; 
    final String description = _getSmartDescription(product.id, profile);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isPopular ? AppTheme.actionBlue.withValues(alpha: 0.5) : Colors.grey[100]!, width: isPopular ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      product.title.split('(').first.trim(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.primaryNavy),
                    ),
                    if (isPopular)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.actionBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text('credits_popular_caps'.tr(), style: const TextStyle(color: AppTheme.actionBlue, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                product.price,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => ref.read(iapProvider.notifier).buyProduct(product),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text('common_buy'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getSmartDescription(String productId, ProfileModel profile) {
    final level = profile.highestLevel.toLowerCase();
    
    if (productId.contains('10000')) {
      return 'credits_desc_elite'.tr();
    }
    if (productId.contains('5000')) {
      return level != 'gold' ? 'credits_desc_gold_instant'.tr() : 'credits_desc_gold_continue'.tr();
    }
    if (productId.contains('1000')) {
      return level == 'bronze' ? 'credits_desc_silver_instant'.tr() : 'credits_desc_silver_continue'.tr();
    }
    if (productId.contains('500')) {
      return 'credits_desc_analysis'.tr();
    }
    if (productId.contains('250')) {
      return 'credits_desc_ideal'.tr();
    }
    return 'credits_desc_urgent'.tr();
  }

  Widget _buildAboutCreditsCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.help_outline_rounded, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Krediler Hakkında',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Krediler ile uygulama içinde daha fazla etkileşimde bulunabilir, sorularınıza yanıt alabilir ve güçlü bir uzman ağıyla birlikte çalışabilirsiniz.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () => _showCreditsInfo(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Kredi nasıl kazanılır ve harcanır?',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.blue.withValues(alpha: 0.8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBalanceCard(BuildContext context, WidgetRef ref, ProfileModel? profile, AsyncValue<Map<String, int>> statsAsync) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a237e), Color(0xFF3949ab)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1a237e).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            // Süsleme Halkaları
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'credits_current_balance'.tr(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: AppTheme.creditGold, size: 32),
                            const SizedBox(width: 10),
                            Text(
                              '${profile?.creditBalance ?? 0}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // İstatistikler
                        statsAsync.when(
                          data: (stats) => Column(
                            children: [
                              _buildStatRow(
                                icon: Icons.stars_rounded,
                                label: 'credits_earnings'.tr(),
                                value: stats['earned'] ?? 0,
                                color: AppTheme.creditGold,
                              ),
                              const SizedBox(height: 10),
                              _buildStatRow(
                                icon: Icons.outbox_rounded,
                                label: 'credits_spendings'.tr(),
                                value: -(stats['spent'] ?? 0),
                                color: Colors.redAccent[100]!,
                              ),
                            ],
                          ),
                          loading: () => const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2))),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  
                  // Trophy Illustration
                  Transform.translate(
                    offset: const Offset(-10, 0),
                    child: Container(
                      width: 160,
                      height: 180,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/credit_trophy.png'),
                          fit: BoxFit.contain,
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
    );
  }

  Widget _buildStatRow({required IconData icon, required String label, required int value, required Color color}) {
    return Row(
      children: [
        Text(
          '$label:',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showCreditsInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Kredi Sistemi Hakkında',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildInfoItem(Icons.add_circle_outline_rounded, 'Kredi Kazanma', 'Anketlere katılarak, tartışmalara yanıt vererek ve uzman sorularını cevaplayarak kredi kazanabilirsiniz.'),
                  _buildInfoItem(Icons.remove_circle_outline_rounded, 'Kredi Harcama', 'Yeni tartışma başlatmak, danışma sorusu sormak veya ilan yayınlamak için kredi harcanır.'),
                  _buildInfoItem(Icons.trending_up_rounded, 'Seviye Sistemi', 'Kazandığınız krediler toplam bakiyenizi artırır ve belirli eşiklerde (1000, 5000, 10000) yeni seviyelere ulaşırsınız.'),
                  _buildInfoItem(Icons.workspace_premium_rounded, 'Avantajlar', 'Üst seviyelerde yeni özellikler (Özel mesaj, anket oluşturma, ilan verme) aktifleşir.'),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.actionBlue, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 60) return 'time_ago_min'.tr(args: [diff.inMinutes.toString()]);
      if (diff.inHours < 24) return 'time_ago_hour'.tr(args: [diff.inHours.toString()]);
      if (diff.inDays < 7) return 'time_ago_day'.tr(args: [diff.inDays.toString()]);
      return '${date.day}.${date.month}.${date.year}';
    } catch (e) {
      if (dateStr.length >= 16) return dateStr.substring(0, 16);
      return dateStr;
    }
  }

  IconData _getLogIcon(String action) {
    switch (action) {
      case 'survey_vote': return Icons.bar_chart_rounded;
      case 'discussion_reply': return Icons.chat_bubble_outline_rounded;
      case 'consultation_reply': return Icons.psychology_outlined;
      case 'app_review': return Icons.star_outline_rounded;
      case 'friend_referral': return Icons.person_add_outlined;
      case 'survey_create': return Icons.add_chart_rounded;
      case 'listing_create': return Icons.campaign_outlined;
      case 'discussion_create': return Icons.forum_outlined;
      case 'consultation_ask': return Icons.help_outline_rounded;
      case 'chat_message': return Icons.send_outlined;
      default: return Icons.history_rounded;
    }
  }

  Color _getLogIconColor(String action) {
    switch (action) {
      case 'survey_vote': return Colors.blue;
      case 'discussion_reply': return Colors.purple;
      case 'consultation_reply': return Colors.teal;
      case 'app_review': return Colors.orange;
      case 'friend_referral': return Colors.pink;
      case 'listing_create': return Colors.red;
      case 'chat_message': return Colors.indigo;
      default: return AppTheme.actionBlue;
    }
  }

  String _getLogActionTitle(String action, dynamic description) {
    switch (action) {
      case 'survey_vote': return 'Ankete oy verdiniz';
      case 'discussion_reply': return 'Tartışmaya cevap verdiniz';
      case 'consultation_reply': return 'Danışmaya cevap verdiniz';
      case 'app_review': return 'Uygulama hakkında yorum yaptınız';
      case 'friend_referral': return 'Arkadaşınızı önerdiniz';
      case 'survey_create': return 'Anket oluşturdunuz';
      case 'listing_create': return 'İlan yayınladınız';
      case 'discussion_create': return 'Tartışma başlattınız';
      case 'consultation_ask': return 'Bir uzmana danıştınız';
      case 'chat_message': return 'Mesaj gönderdiniz';
      default: return (description ?? action).toString();
    }
  }

  String _formatLogDateTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      
      final isToday = date.day == now.day && date.month == now.month && date.year == now.year;
      final isYesterday = date.day == now.day - 1 && date.month == now.month && date.year == now.year;
      
      final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      
      if (isToday) return 'Bugün, $timeStr';
      if (isYesterday) return 'Dün, $timeStr';
      
      return '${date.day} ${_getLogMonthName(date.month)} ${date.year}, $timeStr';
    } catch (e) {
      return dateStr;
    }
  }

  String _getLogMonthName(int month) {
    const months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return months[month - 1];
  }
}
