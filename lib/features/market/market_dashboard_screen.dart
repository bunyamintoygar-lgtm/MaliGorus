import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/market_product_model.dart';
import '../../data/repositories/market_repository.dart';
import '../../data/supabase/credit_service.dart';
import '../home/home_provider.dart';
import 'market_provider.dart';
import 'market_bottom_navigation_bar.dart';

class MarketDashboardScreen extends ConsumerStatefulWidget {
  const MarketDashboardScreen({super.key});

  @override
  ConsumerState<MarketDashboardScreen> createState() => _MarketDashboardScreenState();
}

class _MarketDashboardScreenState extends ConsumerState<MarketDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _scrollController;
  late final ScrollController _verticalScrollController;
  int _currentPage = 0;
  List<MarketProductModel> _vipServices = [];
  bool _loading = true;
  List<MarketProductModel> _searchResults = [];
  bool _isSearching = false;

  // Dynamic products stats calculated from Database
  int _documentCount = 28;
  int _documentMinCredit = 50;
  int _liveTrainingCount = 12;
  int _liveTrainingMinCredit = 80;
  int _certificateCount = 15;
  int _certificateMinCredit = 100;
  int _eventCount = 18;
  int _eventMinCredit = 0;
  int _softwareCount = 10;
  int _softwareMinCredit = 150;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _verticalScrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _loadVipServices();
  }

  String _normalizeString(String input) {
    return input
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ç', 'c')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('İ', 'i')
        .replaceAll('Ş', 's')
        .replaceAll('Ğ', 'g')
        .replaceAll('Ç', 'c')
        .replaceAll('Ö', 'o')
        .replaceAll('Ü', 'u');
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }

    try {
      final repository = ref.read(marketRepositoryProvider);
      final types = MarketProductType.values;
      final results = await Future.wait(
        types.map((type) => repository.getProducts(
          type: type,
          searchPattern: query,
        )),
      );

      final allMatches = results.expand((list) => list).toList();

      if (mounted) {
        setState(() {
          _searchResults = allMatches;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Dashboard search failed: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _scrollListener() {
    if (!mounted || _vipServices.isEmpty) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = (screenWidth - 32 - 12) / 2;
    final double step = cardWidth + 12;
    if (step > 0) {
      final int newPage = (_scrollController.offset / step).round().clamp(0, _vipServices.length - 1);
      if (newPage != _currentPage) {
        setState(() {
          _currentPage = newPage;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadVipServices() async {
    try {
      final repository = ref.read(marketRepositoryProvider);
      
      // Fetch VIP services
      final products = await repository.getProducts(type: MarketProductType.vipService);
      
      // Fetch other types to dynamically calculate statistics
      final docs = await repository.getProducts(type: MarketProductType.document);
      final trainings = await repository.getProducts(type: MarketProductType.liveTraining);
      final certs = await repository.getProducts(type: MarketProductType.certificate);
      final events = await repository.getProducts(type: MarketProductType.event);

      if (mounted) {
        setState(() {
          _vipServices = products;
          if (_vipServices.isEmpty) {
            _vipServices = [
              MarketProductModel(
                id: 'mock-vip-1',
                title: 'Özel Firma & Vergi Yapılandırma Danışmanlığı',
                description: 'Vergi planlama, mali analiz, risk ve fırsat raporu.',
                creditCost: 12000,
                stock: 99,
                type: MarketProductType.vipService,
                category: 'Danışmanlık',
                metadata: {},
                createdAt: DateTime.now(),
              ),
              MarketProductModel(
                id: 'mock-vip-2',
                title: 'Özel Yazılım Entegrasyon Paketi',
                description: 'Firma verilerinize özel entegrasyon ve otomatik raporlama.',
                creditCost: 15000,
                stock: 99,
                type: MarketProductType.vipService,
                category: 'Teknoloji',
                metadata: {},
                createdAt: DateTime.now(),
              ),
              MarketProductModel(
                id: 'mock-vip-3',
                title: 'Kişisel Mentor & Koçluk Programı (6 Ay)',
                description: '6 ay boyunca birebir mentorluk ve gelişim planı.',
                creditCost: 15000,
                stock: 99,
                type: MarketProductType.vipService,
                category: 'Kişisel Gelişim',
                metadata: {},
                createdAt: DateTime.now(),
              ),
            ];
          }

          // Dynamic calculation of document stats
          if (docs.isNotEmpty) {
            _documentCount = docs.length;
            _documentMinCredit = docs.map((e) => e.creditCost).reduce((a, b) => a < b ? a : b);
          }
          // Dynamic calculation of live training stats
          if (trainings.isNotEmpty) {
            _liveTrainingCount = trainings.length;
            _liveTrainingMinCredit = trainings.map((e) => e.creditCost).reduce((a, b) => a < b ? a : b);
          }
          // Dynamic calculation of certificate stats
          if (certs.isNotEmpty) {
            _certificateCount = certs.length;
            _certificateMinCredit = certs.map((e) => e.creditCost).reduce((a, b) => a < b ? a : b);
          }
          // Dynamic calculation of events stats
          if (events.isNotEmpty) {
            _eventCount = events.length;
            _eventMinCredit = events.map((e) => e.creditCost).reduce((a, b) => a < b ? a : b);
          }

          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _vipServices = [
            MarketProductModel(
              id: 'mock-vip-1',
              title: 'Özel Firma & Vergi Yapılandırma Danışmanlığı',
              description: 'Vergi planlama, mali analiz, risk ve fırsat raporu.',
              creditCost: 12000,
              stock: 99,
              type: MarketProductType.vipService,
              category: 'Danışmanlık',
              metadata: {},
              createdAt: DateTime.now(),
            ),
            MarketProductModel(
              id: 'mock-vip-2',
              title: 'Özel Yazılım Entegrasyon Paketi',
              description: 'Firma verilerinize özel entegrasyon ve otomatik raporlama.',
              creditCost: 15000,
              stock: 99,
              type: MarketProductType.vipService,
              category: 'Teknoloji',
              metadata: {},
              createdAt: DateTime.now(),
            ),
            MarketProductModel(
              id: 'mock-vip-3',
              title: 'Kişisel Mentor & Koçluk Programı (6 Ay)',
              description: '6 ay boyunca birebir mentorluk ve gelişim planı.',
              creditCost: 15000,
              stock: 99,
              type: MarketProductType.vipService,
              category: 'Kişisel Gelişim',
              metadata: {},
              createdAt: DateTime.now(),
            ),
          ];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketEnabled = ref.watch(marketEnabledProvider).value ?? true;

    if (!marketEnabled) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          title: const Text('MaliGörüş Market', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Colors.red, size: 64),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Market Geçici Olarak Kapalıdır',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                Text(
                  'MaliGörüş Market modülü yönetici tarafından geçici olarak erişime kapatılmıştır. Lütfen daha sonra tekrar deneyiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Anasayfaya Dön', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final userCredits = ref.watch(homeProvider).value?.profile?.creditBalance ?? 0;
    final cartItems = ref.watch(marketCartProvider).value ?? [];

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
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadVipServices,
                  child: SingleChildScrollView(
                    controller: _verticalScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBar(cartItems.length),
                        if (_searchController.text.isNotEmpty)
                          _buildSearchResultsSection()
                        else ...[
                          _buildCategoriesSection(),
                          _buildFeaturedSection(),
                          _buildPopularCategoriesSection(),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
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
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'market_title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 2),
          const Text(
            'Kredilerinizi kullanın, avantajlardan yararlanın',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      actions: [
        // Credit Balance Capsule
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

  Widget _buildSearchBar(int cartCount) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
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
                  hintText: 'Ürün veya kategori ara...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) {
                  _performSearch(val);
                },
                onSubmitted: (val) {
                  _performSearch(val);
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Shopping Cart Button with Badge
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
              if (cartCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.actionBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final categories = [
      {'name': 'Tümü', 'icon': Icons.grid_view_rounded, 'color': Colors.blue[600]!},
      {'name': 'Eğitim & Kurslar', 'icon': Icons.school_rounded, 'color': Colors.purple[600]!},
      {'name': 'Doküman & Şablonlar', 'icon': Icons.description_rounded, 'color': Colors.green[600]!},
      {'name': 'Sertifika Programları', 'icon': Icons.workspace_premium_rounded, 'color': Colors.orange[600]!},
      {'name': 'Danışmanlık & Hizmetler', 'icon': Icons.people_alt_rounded, 'color': Colors.indigo[600]!},
      {'name': 'Etkinlikler', 'icon': Icons.event_rounded, 'color': Colors.deepPurple[600]!},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () => _handleCategoryNavigation(cat['name'] as String),
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: (cat['color'] as Color).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat['name'] as String,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[800]),
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

  void _handleCategoryNavigation(String category) {
    if (category == 'Tümü') {
      if (_verticalScrollController.hasClients) {
        _verticalScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    } else if (category == 'Doküman & Şablonlar') {
      context.push('/market/documents');
    } else if (category == 'Eğitim & Kurslar') {
      context.push('/market/live-training');
    } else if (category == 'Sertifika Programları') {
      context.push('/market/certificates');
    } else if (category == 'Danışmanlık & Hizmetler') {
      context.push('/market/consulting');
    } else if (category == 'Etkinlikler') {
      context.push('/market/events');
    }
  }

  Widget _buildFeaturedSection() {
    if (_vipServices.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = (screenWidth - 32 - 12) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 270,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _vipServices.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final service = _vipServices[index];
              return SizedBox(
                width: cardWidth,
                child: _buildFeaturedCard(service, index),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _vipServices.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 16 : 8,
              height: 4,
              decoration: BoxDecoration(
                color: _currentPage == index ? Colors.deepPurple : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFeaturedCard(MarketProductModel service, int index) {
    final cardThemes = [
      {
        'tag': 'POPÜLER',
        'tagBg': const Color(0xFFF3E5F5),
        'tagText': const Color(0xFF7B1FA2),
        'icon': Icons.business_rounded,
        'iconBg': const Color(0xFFF3E5F5),
        'iconColor': const Color(0xFF7B1FA2),
        'priceColor': const Color(0xFF7B1FA2),
        'btnColor': const Color(0xFF7B1FA2),
      },
      {
        'tag': 'YENİ',
        'tagBg': const Color(0xFFE3F2FD),
        'tagText': const Color(0xFF1976D2),
        'icon': Icons.laptop_chromebook_rounded,
        'iconBg': const Color(0xFFE3F2FD),
        'iconColor': const Color(0xFF1976D2),
        'priceColor': const Color(0xFF1976D2),
        'btnColor': const Color(0xFF1976D2),
      },
      {
        'tag': 'ÖNERİLEN',
        'tagBg': const Color(0xFFE8F5E9),
        'tagText': const Color(0xFF388E3C),
        'icon': Icons.shield_rounded,
        'iconBg': const Color(0xFFE8F5E9),
        'iconColor': const Color(0xFF388E3C),
        'priceColor': const Color(0xFF388E3C),
        'btnColor': const Color(0xFF388E3C),
      },
    ];

    final theme = cardThemes[index % cardThemes.length];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Tag top left
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme['tagBg'] as Color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                theme['tag'] as String,
                style: TextStyle(
                  color: theme['tagText'] as Color,
                  fontWeight: FontWeight.w900,
                  fontSize: 7.5,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 26, 10, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 6),
                // Icon in circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme['iconBg'] as Color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      theme['icon'] as IconData,
                      color: theme['iconColor'] as Color,
                      size: 22,
                    ),
                  ),
                ),
                // Title
                Text(
                  service.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                    color: AppTheme.primaryNavy,
                    height: 1.15,
                  ),
                ),
                // Description
                Text(
                  service.description ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Colors.grey[500],
                    height: 1.2,
                  ),
                ),
                // Price Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stars_rounded, color: AppTheme.creditGold, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      '${NumberFormat('#,###', 'tr_TR').format(service.creditCost)} Kredi',
                      style: TextStyle(
                        color: theme['priceColor'] as Color,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.0,
                      ),
                    ),
                  ],
                ),
                // Outlined Button
                SizedBox(
                  width: double.infinity,
                  height: 28,
                  child: OutlinedButton(
                    onPressed: () => context.push('/market/detail', extra: service),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme['btnColor'] as Color, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      foregroundColor: theme['btnColor'] as Color,
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      'Detayları Gör',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 9.5,
                        color: theme['btnColor'] as Color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularCategoriesSection() {
    final categoriesData = [
      {
        'name': 'Eğitim & Kurslar',
        'subtitle': '$_liveTrainingCount ürün',
        'icon': Icons.school_rounded,
        'color': const Color(0xFF673AB7),
        'bgLight': const Color(0xFFF3E5F5),
        'startingCredit': _liveTrainingMinCredit,
        'previews': [Icons.play_circle_fill, Icons.menu_book, Icons.video_library],
        'remaining': _liveTrainingCount > 3 ? '+${_liveTrainingCount - 3}' : '+1',
        'route': '/market/live-training',
      },
      {
        'name': 'Doküman & Şablonlar',
        'subtitle': '$_documentCount ürün',
        'icon': Icons.description_rounded,
        'color': const Color(0xFF2E7D32),
        'bgLight': const Color(0xFFE8F5E9),
        'startingCredit': _documentMinCredit,
        'previews': [Icons.article, Icons.table_chart, Icons.picture_as_pdf],
        'remaining': _documentCount > 3 ? '+${_documentCount - 3}' : '+2',
        'route': '/market/documents',
      },
      {
        'name': 'Sertifika Programları',
        'subtitle': '$_certificateCount ürün',
        'icon': Icons.workspace_premium_rounded,
        'color': const Color(0xFFEF6C00),
        'bgLight': const Color(0xFFFFF3E0),
        'startingCredit': _certificateMinCredit,
        'previews': [Icons.star, Icons.workspace_premium, Icons.auto_awesome],
        'remaining': _certificateCount > 3 ? '+${_certificateCount - 3}' : '+3',
        'route': '/market/certificates',
      },
      {
        'name': 'Danışmanlık & Hizmetler',
        'subtitle': '${_vipServices.length} ürün',
        'icon': Icons.people_alt_rounded,
        'color': const Color(0xFF1565C0),
        'bgLight': const Color(0xFFE3F2FD),
        'startingCredit': _vipServices.isEmpty ? 10000 : _vipServices.map((e) => e.creditCost).reduce((a, b) => a < b ? a : b),
        'previews': [Icons.forum, Icons.support_agent, Icons.diversity_3],
        'remaining': _vipServices.length > 3 ? '+${_vipServices.length - 3}' : '+0',
        'route': '/market',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Popüler Kategoriler',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.primaryNavy,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: categoriesData.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final cat = categoriesData[index];
            return InkWell(
              onTap: () => context.push(cat['route'] as String),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.01),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Category Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cat['bgLight'] as Color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        cat['icon'] as IconData,
                        color: cat['color'] as Color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Title and subtitle
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat['name'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cat['subtitle'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Previews
                    Expanded(
                      flex: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...(cat['previews'] as List<IconData>).map((icon) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: (cat['bgLight'] as Color).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFEEEEEE), width: 0.8),
                              ),
                              child: Icon(
                                icon,
                                size: 12,
                                color: (cat['color'] as Color).withOpacity(0.7),
                              ),
                            );
                          }),
                          const SizedBox(width: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cat['remaining'] as String,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Starting Credit
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Başlangıç',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${cat['startingCredit']} Kredi',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Color(0xFF1E88E5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Colors.grey[300],
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

  Widget _buildSearchResultsSection() {
    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                '"${_searchController.text}" aramasına uygun ürün bulunamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Lütfen farklı anahtar kelimeler deneyin veya yazımı kontrol edin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 12),
          child: Text(
            'Arama Sonuçları (${_searchResults.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final item = _searchResults[index];
            return _buildSearchResultRow(item);
          },
        ),
      ],
    );
  }

  Widget _buildSearchResultRow(MarketProductModel item) {
    IconData icon;
    Color iconColor;
    String typeText;

    switch (item.type) {
      case MarketProductType.document:
        icon = Icons.description_outlined;
        iconColor = Colors.blue;
        typeText = 'Doküman';
        break;
      case MarketProductType.certificate:
        icon = Icons.workspace_premium_outlined;
        iconColor = Colors.orange;
        typeText = 'Sertifika';
        break;
      case MarketProductType.liveTraining:
        icon = Icons.video_camera_back_outlined;
        iconColor = Colors.purple;
        typeText = 'Canlı Eğitim';
        break;
      case MarketProductType.event:
        icon = Icons.event_outlined;
        iconColor = Colors.deepPurple;
        typeText = 'Etkinlik';
        break;
      case MarketProductType.vipService:
        icon = Icons.stars_outlined;
        iconColor = Colors.indigo;
        typeText = 'Danışmanlık';
        break;
    }

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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$typeText • ${item.category}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                '${NumberFormat('#,###', 'tr_TR').format(item.creditCost)} Kredi',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

