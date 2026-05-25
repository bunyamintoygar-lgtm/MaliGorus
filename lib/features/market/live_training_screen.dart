import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/market_product_model.dart';
import '../home/home_provider.dart';
import 'market_provider.dart';
import 'market_bottom_navigation_bar.dart';

class LiveTrainingScreen extends ConsumerStatefulWidget {
  const LiveTrainingScreen({super.key});

  @override
  ConsumerState<LiveTrainingScreen> createState() => _LiveTrainingScreenState();
}

class _LiveTrainingScreenState extends ConsumerState<LiveTrainingScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final userCredits = ref.watch(homeProvider).value?.profile?.creditBalance ?? 0;
    final cartItems = ref.watch(marketCartProvider).value ?? [];

    final productsAsyncValue = ref.watch(marketProductsProvider(MarketProductType.liveTraining));

    return Scaffold(
      backgroundColor: const Color(0xFF021040),
      appBar: _buildAppBar(userCredits, cartItems.length),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF092A8C),
              Color(0xFF021040),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchAndFilters(),
                productsAsyncValue.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                  error: (err, stack) => Center(child: Text('Hata oluştu: $err')),
                  data: (products) {
                    if (products.isEmpty) {
                      final searchQuery = ref.watch(marketSearchProvider)[MarketProductType.liveTraining] ?? '';
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                searchQuery.isNotEmpty
                                    ? '"$searchQuery" aramasına uygun canlı eğitim bulunamadı.'
                                    : 'Bu kategoride canlı eğitim bulunamadı.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUpcomingTrainingsSection(products),
                        _buildRecordedReplaysNotice(),
                        _buildPopularTrainingsGrid(products),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const MarketBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar(int credits, int cartCount) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Canlı Eğitim',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            'Uzman eğitmenlerle canlı ve interaktif derslere katıl.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      actions: [
        // Balance capsule
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Text(
            NumberFormat('#,###', 'tr_TR').format(credits),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF092A8C),
              Color(0xFF021040),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final activeCategory = ref.watch(marketCategoryProvider)[MarketProductType.liveTraining] ?? 'Tümü';
    final categories = ['Tümü', 'Yaklaşan', 'Bugün', 'Bu Hafta', 'Finans', 'Pazarlama'];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Canlı eğitim ara...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) {
                      ref.read(marketSearchProvider.notifier).setSearch(MarketProductType.liveTraining, val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black87),
                      onPressed: () => context.push('/market/cart'),
                    ),
                  ),
                  finalCartCountBadge(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = activeCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? AppTheme.primaryNavy : Colors.grey[700],
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            ref.read(marketCategoryProvider.notifier).setCategory(MarketProductType.liveTraining, cat);
                          },
                          backgroundColor: Colors.white,
                          selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: isSelected ? AppTheme.primaryNavy : Colors.grey[200]!),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 18, color: Colors.black87),
                  onPressed: () {},
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget finalCartCountBadge() {
    final cartItems = ref.watch(marketCartProvider).value ?? [];
    if (cartItems.isEmpty) return const SizedBox.shrink();
    return Positioned(
      right: 4,
      top: 4,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: Text(
          '${cartItems.length}',
          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFFFB300),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.stars_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '10.000+ KREDİ İLE ULAŞABİLECEĞİNİZ ÖZEL AVANTAJLAR',
                  style: TextStyle(
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'En kapsamlı çözümler ve kişisel ayrıcalıklar sizi bekliyor.',
                  style: TextStyle(
                    color: Color(0xFF5D4037),
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFECEFF1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextButton(
              onPressed: () {
                // Action to explore VIP features
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                foregroundColor: const Color(0xFFFFB300),
              ),
              child: const Text(
                'Keşfet',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: Color(0xFFFFB300),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          const Icon(Icons.check_rounded, color: Colors.purple, size: 12),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildUpcomingTrainingsSection(List<MarketProductModel> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Yaklaşan Canlı Eğitimler',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
              ),
              InkWell(
                onTap: () {},
                child: const Row(
                  children: [
                    Text('Tümünü Gör', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: Colors.purple, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final item = products[index];
            return _buildLiveTrainingCard(item);
          },
        ),
      ],
    );
  }

  Widget _buildLiveTrainingCard(MarketProductModel item) {
    final isPurchasedAsync = ref.watch(isProductPurchasedProvider(item.id));
    final isPurchased = isPurchasedAsync.value ?? false;

    return InkWell(
      onTap: () => _showLiveTrainingDetailsDialog(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Left visual stack with Live Badge overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                child: Image.network(
                  item.imageUrl ?? '',
                  width: 110,
                  height: 125,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.purple[50],
                    width: 110,
                    height: 125,
                    child: const Icon(Icons.videocam_rounded, color: Colors.purple, size: 36),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'CANLI',
                    style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          // Right content details area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.dateTime,
                    style: TextStyle(color: Colors.purple[700], fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy),
                  ),
                  const SizedBox(height: 6),
                  // Host/Trainer profile row matching Mockup 3
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          item.trainerAvatar,
                          width: 22,
                          height: 22,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[300],
                            width: 22,
                            height: 22,
                            child: const Icon(Icons.person, size: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.trainerName,
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                            ),
                            Text(
                              item.trainerTitle,
                              style: TextStyle(fontSize: 8, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Bottom cost & Dynamic Actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 10, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(item.duration, style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                          const SizedBox(width: 10),
                          Text(
                            '${NumberFormat('#,###', 'tr_TR').format(item.creditCost)} Kredi',
                            style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                      // DYNAMIC ACTION BUTTON
                      _buildDynamicAction(item, isPurchased),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildDynamicAction(MarketProductModel item, bool isPurchased) {
    if (isPurchased) {
      return SizedBox(
        height: 26,
        child: ElevatedButton(
          onPressed: () => _launchZoomUrl(item.zoomLink),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text('Katıl', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
        ),
      );
    }

    return SizedBox(
      height: 26,
      child: OutlinedButton(
        onPressed: () => _showLiveTrainingDetailsDialog(item),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.deepPurple),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: const Text('Detaylar', style: TextStyle(fontSize: 9, color: Colors.deepPurple, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _launchZoomUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback display
    }
  }

  Widget _buildRecordedReplaysNotice() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
            child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Canlı eğitime katılamazsan sorun değil!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primaryNavy),
                ),
                SizedBox(height: 2),
                Text(
                  'Tüm canlı eğitimlerin kayıtlarına 30 gün boyunca erişebilirsin.',
                  style: TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
        ],
      ),
    );
  }

  Widget _buildPopularTrainingsGrid(List<MarketProductModel> allProducts) {
    final Map<String, List<MarketProductModel>> grouped = {};
    for (var p in allProducts) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }

    final categories = grouped.entries.map((entry) {
      final name = entry.key;
      final count = entry.value.length;
      Color color = Colors.blue;
      if (name == 'Finans') color = Colors.green;
      else if (name == 'Pazarlama') color = Colors.orange;
      else if (name == 'Yönetim') color = Colors.purple;
      else if (name == 'Teknoloji') color = Colors.blue;
      else if (name == 'Kişisel Gelişim') color = Colors.red;

      return {
        'name': name,
        'count': count,
        'color': color,
      };
    }).toList();

    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 16, bottom: 12),
          child: Text(
            'Popüler Canlı Eğitimler',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
          ),
        ),
        SizedBox(
          height: 65,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: (cat['color'] as Color).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (cat['color'] as Color).withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: cat['color'] as Color, shape: BoxShape.circle),
                      child: const Icon(Icons.school_outlined, color: Colors.white, size: 10),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          cat['name'] as String,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                        ),
                        const SizedBox(height: 2),
                        Text('${cat['count']} Eğitim', style: TextStyle(fontSize: 8, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showLiveTrainingDetailsDialog(MarketProductModel item) {
    context.push('/market/detail', extra: item);
  }
}
