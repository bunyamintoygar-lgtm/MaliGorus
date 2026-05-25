import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/market_product_model.dart';
import '../home/home_provider.dart';
import 'market_provider.dart';
import 'market_bottom_navigation_bar.dart';

class ConsultingServicesScreen extends ConsumerStatefulWidget {
  const ConsultingServicesScreen({super.key});

  @override
  ConsumerState<ConsultingServicesScreen> createState() => _ConsultingServicesScreenState();
}

class _ConsultingServicesScreenState extends ConsumerState<ConsultingServicesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userCredits = ref.watch(homeProvider).value?.profile?.creditBalance ?? 0;
    final cartItems = ref.watch(marketCartProvider).value ?? [];

    final productsAsyncValue = ref.watch(marketProductsProvider(MarketProductType.vipService));
    final unfilteredAsyncValue = ref.watch(unfilteredMarketProductsProvider(MarketProductType.vipService));

    // Dynamically discover all unique categories that have products!
    final unfilteredProducts = unfilteredAsyncValue.value ?? [];
    final existingCategories = unfilteredProducts
        .map((p) => p.category)
        .where((cat) => cat.isNotEmpty)
        .toSet()
        .toList();

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
                _buildSearchAndFilters(existingCategories),
                productsAsyncValue.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Hata oluştu: $err', style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                  data: (products) {
                    if (products.isEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildExploreByCategoriesSection(unfilteredProducts),
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(48),
                              child: Text(
                                'Bu filtreye uygun danışmanlık hizmeti bulunamadı.',
                                style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVipAdvantagesBanner(),
                        _buildExploreByCategoriesSection(unfilteredProducts),
                        _buildServicesSection(products),
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
            'Danışmanlık & Hizmetler',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            'Uzmanlardan birebir ve özel kurumsal çözümler.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      actions: [
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

  Widget _buildSearchAndFilters(List<String> existingCategories) {
    final activeCategory = ref.watch(marketCategoryProvider)[MarketProductType.vipService] ?? 'Tümü';
    final categories = ['Tümü', ...existingCategories];

    final cartItems = ref.watch(marketCartProvider).value ?? [];

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
                      hintText: 'Hizmet ara...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) {
                      ref.read(marketSearchProvider.notifier).setSearch(MarketProductType.vipService, val);
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
                  if (cartItems.isNotEmpty)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '${cartItems.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
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
                            ref.read(marketCategoryProvider.notifier).setCategory(MarketProductType.vipService, cat);
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVipAdvantagesBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber[800]!,
            Colors.orange[600]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
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
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFE65100),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREMIUM VIP DANIŞMANLIK HİZMETLERİ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Kişiye özel danışman ataması, limitsiz doğrudan destek ve strateji raporları.',
                  style: TextStyle(
                    color: const Color(0xFFFFF3E0),
                    fontWeight: FontWeight.w500,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreByCategoriesSection(List<MarketProductModel> allProducts) {
    final Map<String, List<MarketProductModel>> grouped = {};
    for (var p in allProducts) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }

    final categories = grouped.entries.map((entry) {
      final name = entry.key;
      final count = entry.value.length;
      Color color = Colors.blue;
      if (name == 'Teknoloji') {
        color = Colors.purple;
      } else if (name == 'Danışmanlık') {
        color = Colors.orange;
      } else if (name == 'Kişisel Gelişim') {
        color = Colors.red;
      } else if (name == 'Finans') {
        color = Colors.green;
      }

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
            'Kategorilere Göre Keşfet',
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
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: (cat['color'] as Color).withValues(alpha: 0.15)),
                ),
                clipBehavior: Clip.antiAlias,
                color: (cat['color'] as Color).withValues(alpha: 0.05),
                child: InkWell(
                  onTap: () {
                    ref.read(marketCategoryProvider.notifier).setCategory(
                          MarketProductType.vipService,
                          cat['name'] as String,
                        );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: cat['color'] as Color, shape: BoxShape.circle),
                          child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 10),
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
                            Text('${cat['count']} Hizmet', style: TextStyle(fontSize: 8, color: Colors.grey[500])),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildServicesSection(List<MarketProductModel> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Tüm Danışmanlık Paketleri',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final item = products[index];
            final isSaved = ref.watch(marketSavedProvider.notifier).isSaved(item.id);
            final features = (item.metadata['features'] as List?)?.cast<String>() ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () => _showProductDetailsDialog(item),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(
                            item.imageUrl ?? '',
                            width: double.infinity,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.blue[50],
                              width: double.infinity,
                              height: 140,
                              child: const Icon(Icons.business_center_rounded, color: Colors.blue, size: 48),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: IconButton(
                              icon: Icon(
                                isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                                color: isSaved ? Colors.blue : Colors.grey,
                                size: 20,
                              ),
                              onPressed: () {
                                ref.read(marketSavedProvider.notifier).toggleSaved(item.id);
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.amber[800],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.star, color: Colors.white, size: 10),
                                SizedBox(width: 4),
                                Text(
                                  'PREMIUM',
                                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.description ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          if (features.isNotEmpty) ...[
                            ...features.take(2).map((feat) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      feat,
                                      style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${NumberFormat('#,###', 'tr_TR').format(item.creditCost)} Kredi',
                                style: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              ElevatedButton(
                                onPressed: () => _showProductDetailsDialog(item),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryNavy,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text('Detayları İncele', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showProductDetailsDialog(MarketProductModel item) {
    context.push('/market/detail', extra: item);
  }
}
