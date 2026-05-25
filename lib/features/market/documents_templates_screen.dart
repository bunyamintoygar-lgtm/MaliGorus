import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/market_product_model.dart';
import '../home/home_provider.dart';
import 'market_provider.dart';
import 'market_bottom_navigation_bar.dart';

class DocumentsTemplatesScreen extends ConsumerStatefulWidget {
  const DocumentsTemplatesScreen({super.key});

  @override
  ConsumerState<DocumentsTemplatesScreen> createState() => _DocumentsTemplatesScreenState();
}

class _DocumentsTemplatesScreenState extends ConsumerState<DocumentsTemplatesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final userCredits = ref.watch(homeProvider).value?.profile?.creditBalance ?? 0;
    final cartItems = ref.watch(marketCartProvider).value ?? [];

    final productsAsyncValue = ref.watch(marketProductsProvider(MarketProductType.document));

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
                      final searchQuery = ref.watch(marketSearchProvider)[MarketProductType.document] ?? '';
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
                                    ? '"$searchQuery" aramasına uygun doküman veya şablon bulunamadı.'
                                    : 'Bu kategoride doküman veya şablon bulunamadı.',
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
                        _buildFeaturedSection(products),
                        _buildPopularCategoriesSection(products),
                        _buildRecentlyAddedSection(products),
                      ],
                    );
                  },
                ),
                _buildGuaranteeBanner(),
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
            'Doküman & Şablonlar',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            'İşinizi kolaylaştıracak dokümanlara ve şablonlara ulaş.',
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
    final activeCategory = ref.watch(marketCategoryProvider)[MarketProductType.document] ?? 'Tümü';
    final categories = ['Tümü', 'İş & Yönetim', 'Finans', 'Pazarlama', 'Hukuk', 'Kişisel Gelişim'];

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
          // Search box & Cart integration row
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
                      hintText: 'Doküman veya şablon ara...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) {
                      ref.read(marketSearchProvider.notifier).setSearch(MarketProductType.document, val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Cart with badge
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
          // Horizontal scrolling categories
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
                            ref.read(marketCategoryProvider.notifier).setCategory(MarketProductType.document, cat);
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple[50]!, Colors.deepPurple[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '10.000+ KREDİYE ÖZEL',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Hazır Şablonlar, Hızlı Çözümler',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 6),
                Text(
                  'Profesyonel dokümanlar ve şablonlarla zaman kazan, işini büyüt.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {},
                  child: const Row(
                    children: [
                      Text('Tüm Dokümanları Keşfet', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 12)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: Colors.deepPurple, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Right Stack of Word, Excel, PDF icons
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 10,
                  child: _fileMiniIcon('W', Colors.blue, 40),
                ),
                Positioned(
                  right: 0,
                  top: 25,
                  child: _fileMiniIcon('X', Colors.green, 42),
                ),
                Positioned(
                  left: 20,
                  bottom: 0,
                  child: _fileMiniIcon('PDF', Colors.red, 38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileMiniIcon(String letter, Color color, double size) {
    return Container(
      width: size,
      height: size + 8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            child: Text(
              letter,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8),
            ),
          ),
          const SizedBox(height: 4),
          Icon(Icons.description_outlined, color: color.withValues(alpha: 0.5), size: 16),
        ],
      ),
    );
  }

  Widget _buildFeaturedSection(List<MarketProductModel> products) {
    final featured = products.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: featured.length,
            itemBuilder: (context, index) {
              final item = featured[index];
              return _buildFeaturedCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(MarketProductModel item) {
    final fileColor = _getFileTypeColor(item.fileType);

    return Container(
      width: 150,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular rounded Icon matching Mockup 1
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: fileColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_getFileIconData(item.fileType), color: fileColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            item.description ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          // Blue capsule credit cost
          GestureDetector(
            onTap: () => _handleItemSelection(item),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.blue, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '${NumberFormat('#,###', 'tr_TR').format(item.creditCost)} Kredi',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularCategoriesSection(List<MarketProductModel> allProducts) {
    final Map<String, List<MarketProductModel>> grouped = {};
    for (var p in allProducts) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }

    final categories = grouped.entries.map((entry) {
      final catProducts = entry.value;
      final minCost = catProducts.isEmpty ? 500 : catProducts.map((p) => p.creditCost).reduce((a, b) => a < b ? a : b);
      final fileTypes = catProducts.map((p) => p.fileType ?? 'docx').toSet().toList();
      
      IconData icon = Icons.category_rounded;
      if (entry.key == 'İş & Yönetim') icon = Icons.business_center_rounded;
      else if (entry.key == 'Finans') icon = Icons.trending_up_rounded;
      else if (entry.key == 'Pazarlama') icon = Icons.campaign_rounded;
      else if (entry.key == 'Hukuk') icon = Icons.gavel_rounded;
      else if (entry.key == 'Kişisel Gelişim') icon = Icons.psychology_rounded;

      return {
        'name': entry.key,
        'count': catProducts.length,
        'min': minCost,
        'icon': icon,
        'types': fileTypes,
      };
    }).toList();

    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 20, bottom: 12),
          child: Text(
            'Popüler Kategoriler',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[100]!),
              ),
              clipBehavior: Clip.antiAlias,
              color: Colors.white,
              child: InkWell(
                onTap: () {
                  ref.read(marketCategoryProvider.notifier).setCategory(
                        MarketProductType.document,
                        cat['name'] as String,
                      );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(cat['icon'] as IconData, color: Colors.blue[700], size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat['name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${cat['count']} şablon',
                              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      // File badge mini previews matching Mockup 1
                      Row(
                        children: (cat['types'] as List<String>).take(3).map((t) {
                          return Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getFileTypeColor(t).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t.toUpperCase(),
                              style: TextStyle(color: _getFileTypeColor(t), fontSize: 7, fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                      ),
                      if ((cat['types'] as List<String>).length > 3)
                        Text('+${(cat['types'] as List<String>).length - 3}', style: TextStyle(color: Colors.grey[500], fontSize: 8)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Başlangıç',
                            style: TextStyle(color: Colors.grey[400], fontSize: 8),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${cat['min']} Kredi',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentlyAddedSection(List<MarketProductModel> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 24, right: 16, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Son Eklenenler',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
              ),
              InkWell(
                onTap: () {},
                child: const Text('Tümünü Gör', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 12)),
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
            return _buildRecentlyAddedRow(item);
          },
        ),
      ],
    );
  }

  Widget _buildRecentlyAddedRow(MarketProductModel item) {
    final fileColor = _getFileTypeColor(item.fileType);
    final isSaved = ref.watch(marketSavedProvider.notifier).isSaved(item.id);

    return InkWell(
      onTap: () => context.push('/market/detail', extra: item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: fileColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_getFileIconData(item.fileType), color: fileColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.category}  •  ${item.metadata['added_days_ago'] ?? 2} gün önce eklendi',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Text(
              '${NumberFormat('#,###', 'tr_TR').format(item.creditCost)} Kredi',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 11),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(
                isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                color: isSaved ? Colors.deepPurple : Colors.grey,
                size: 20,
              ),
              onPressed: () {
                ref.read(marketSavedProvider.notifier).toggleSaved(item.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuaranteeBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: Colors.deepPurple, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Güvenli & Güncel İçerik',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy),
                ),
                SizedBox(height: 2),
                Text(
                  'Tüm dokümanlar uzmanlar tarafından hazırlanır ve düzenli olarak güncellenir.',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.deepPurple.withValues(alpha: 0.5), size: 18),
        ],
      ),
    );
  }

  void _handleItemSelection(MarketProductModel item) {
    context.push('/market/detail', extra: item);
  }

  Color _getFileTypeColor(String? type) {
    switch (type) {
      case 'docx':
        return Colors.blue[600]!;
      case 'xlsx':
        return Colors.green[600]!;
      case 'pdf':
        return Colors.red[600]!;
      case 'pptx':
        return Colors.orange[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getFileIconData(String? type) {
    switch (type) {
      case 'docx':
        return Icons.article_rounded;
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'pptx':
        return Icons.slideshow_rounded;
      default:
        return Icons.description_rounded;
    }
  }
}
