import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/market_product_model.dart';
import '../home/home_provider.dart';
import 'market_provider.dart';
import 'market_bottom_navigation_bar.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final userCredits = ref.watch(homeProvider).value?.profile?.creditBalance ?? 0;
    final cartItems = ref.watch(marketCartProvider).value ?? [];

    final productsAsyncValue = ref.watch(marketProductsProvider(MarketProductType.event));

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
                      final searchQuery = ref.watch(marketSearchProvider)[MarketProductType.event] ?? '';
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
                                    ? '"$searchQuery" aramasına uygun etkinlik bulunamadı.'
                                    : 'Bu kategoride etkinlik bulunamadı.',
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
                        _buildUpcomingEventsSection(products),
                        _buildPopularCategoriesSection(products),
                        _buildPastEventsSection(products),
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
            'Etkinlikler',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            'Kariyerinize değer katacak etkinlikleri keşfedin.',
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
    final activeCategory = ref.watch(marketCategoryProvider)[MarketProductType.event] ?? 'Tümü';
    final categories = ['Tümü', 'Yaklaşan', 'Online', 'Yüz Yüze', 'Atölye', 'Seminer', 'Webinar'];

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
                      hintText: 'Etkinlik ara...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) {
                      ref.read(marketSearchProvider.notifier).setSearch(MarketProductType.event, val);
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
                            ref.read(marketCategoryProvider.notifier).setCategory(MarketProductType.event, cat);
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
          colors: [Colors.indigo[50]!, Colors.indigo[100]!],
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
                    color: Colors.indigo[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '10.000+ KREDİYE ÖZEL',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Yeni Beceriler, Yeni Fırsatlar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 6),
                Text(
                  'Uzmanlarla buluş, ilham al ve kariyerine yön ver.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {},
                  child: Row(
                    children: [
                      Text('Tüm Etkinlikleri Keşfet', style: TextStyle(color: Colors.indigo[700], fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: Colors.indigo[700], size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.indigo, size: 48),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEventsSection(List<MarketProductModel> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Yaklaşan Etkinlikler',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
              ),
              InkWell(
                onTap: () {},
                child: const Row(
                  children: [
                    Text('Tümünü Gör', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12)),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: Colors.indigo, size: 16),
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
            return _buildEventCard(item);
          },
        ),
      ],
    );
  }

  Widget _buildEventCard(MarketProductModel item) {
    final day = item.metadata['day'] ?? '24';
    final month = item.metadata['month'] ?? 'MAY';
    final eventType = item.metadata['event_type'] ?? 'WEBINAR';
    final isSaved = ref.watch(marketSavedProvider.notifier).isSaved(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () => _showEventDetailsDialog(item),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left visual Stack with EventType and Date overlays
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                  child: Image.network(
                    item.imageUrl ?? '',
                    width: 115,
                    height: 130,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.indigo[50],
                      width: 115,
                      height: 130,
                      child: const Icon(Icons.event_rounded, color: Colors.indigo, size: 36),
                    ),
                  ),
                ),
                // Event Type overlay
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      eventType,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // Large Date Overlay block matching Mockup 4
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 42,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          day,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy),
                        ),
                        Text(
                          month,
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.indigo),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Right info block area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            ref.read(marketSavedProvider.notifier).toggleSaved(item.id);
                          },
                          child: Icon(
                            isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                            color: isSaved ? Colors.indigo : Colors.grey,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Presenter row
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          item.trainerName,
                          style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Location and duration stats row
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 2),
                        Text(item.location, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                        const SizedBox(width: 10),
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 2),
                        Text(item.duration, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Pricing tag
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        item.creditCost == 0 ? 'Ücretsiz' : '${NumberFormat('#,###', 'tr_TR').format(item.creditCost)} Kredi',
                        style: TextStyle(
                          color: item.creditCost == 0 ? Colors.green : Colors.indigo,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
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

  Widget _buildPopularCategoriesSection(List<MarketProductModel> allProducts) {
    final Map<String, List<MarketProductModel>> grouped = {};
    for (var p in allProducts) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }

    final categories = grouped.entries.map((entry) {
      final name = entry.key;
      final count = entry.value.length;
      Color color = Colors.blue;
      IconData icon = Icons.event_note_rounded;

      if (name == 'Teknoloji') {
        color = Colors.blue;
        icon = Icons.computer_rounded;
      } else if (name == 'İş & Yönetim') {
        color = Colors.orange;
        icon = Icons.business_center_rounded;
      } else if (name == 'Kişisel Gelişim') {
        color = Colors.purple;
        icon = Icons.psychology_rounded;
      } else if (name == 'Pazarlama') {
        color = Colors.red;
        icon = Icons.campaign_rounded;
      } else if (name == 'Finans') {
        color = Colors.green;
        icon = Icons.account_balance_wallet_rounded;
      } else if (name == 'Hukuk') {
        color = Colors.indigo;
        icon = Icons.gavel_rounded;
      }

      return {
        'name': name,
        'count': count,
        'icon': icon,
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
            'Popüler Kategoriler',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return GestureDetector(
                onTap: () {
                  ref.read(marketCategoryProvider.notifier).setCategory(
                        MarketProductType.event,
                        cat['name'] as String,
                      );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (cat['color'] as Color).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 20),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat['name'] as String,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPastEventsSection(List<MarketProductModel> allProducts) {
    // Generate beautiful dynamic past events from actual products list
    final List<Map<String, String>> past = allProducts.map((p) {
      final date = p.metadata['date_time']?.toString() ?? '12 Mayıs 2024';
      final loc = p.metadata['location']?.toString() ?? 'Online';
      return {
        'title': 'Geçmiş: ${p.title}',
        'date': date.contains('Bugün') || date.contains('Yarın') ? '10 Mayıs 2024' : date,
        'location': loc,
      };
    }).toList();

    if (past.isEmpty) {
      past.addAll([
        {'title': 'Dijital Dönüşüm Zirvesi 2024', 'date': '16 Mayıs 2024', 'location': 'İstanbul'},
        {'title': 'Excel İleri Seviye Teknikler', 'date': '10 Mayıs 2024', 'location': 'Online'},
        {'title': 'Siber Güvenlikte Yeni Trendler', 'date': '3 Mayıs 2024', 'location': 'Online'},
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 16, bottom: 12),
          child: Text(
            'Geçmiş Etkinlikler',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: past.take(3).length,
          itemBuilder: (context, index) {
            final p = past[index];
            return Container(
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
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history_rounded, color: Colors.indigo, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['title'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primaryNavy),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p['date']}  •  ${p['location']}',
                          style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[50],
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.play_circle_fill_rounded, color: Colors.indigo, size: 12),
                        SizedBox(width: 4),
                        Text('Kayıt İzle', style: TextStyle(color: Colors.indigo, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showEventDetailsDialog(MarketProductModel item) {
    context.push('/market/detail', extra: item);
  }
}
