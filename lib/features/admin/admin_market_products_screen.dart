import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/app_config_provider.dart';
import '../../core/utils/market_icon_helper.dart';
import '../../data/models/market_product_model.dart';
import '../../data/models/market_category_model.dart';
import '../../data/supabase/admin_market_service.dart';
import '../../data/supabase/credit_service.dart';

class AdminMarketProductsScreen extends ConsumerStatefulWidget {
  const AdminMarketProductsScreen({super.key});

  @override
  ConsumerState<AdminMarketProductsScreen> createState() => _AdminMarketProductsScreenState();
}

class _AdminMarketProductsScreenState extends ConsumerState<AdminMarketProductsScreen> with SingleTickerProviderStateMixin {
  List<MarketProductModel> _products = [];
  bool _loading = true;
  bool _marketEnabled = true;
  bool _loadingConfig = true;
  String _selectedTab = 'Tümü'; // 'Tümü', 'Aktif', 'Pasif'
  String _selectedCategoryFilter = 'Tümü';
  String _searchQuery = '';
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadProducts(),
      _loadMarketConfig(),
    ]);
  }

  Future<void> _loadMarketConfig() async {
    try {
      final enabled = await ref.read(creditServiceProvider).getConfigValue('market_enabled');
      if (mounted) {
        setState(() {
          _marketEnabled = enabled ?? true;
          _loadingConfig = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  Future<void> _toggleMarket(bool value) async {
    setState(() => _marketEnabled = value);
    final success = await ref.read(creditServiceProvider).updateConfigValue('market_enabled', value);
    if (success) {
      ref.invalidate(marketEnabledProvider);
    } else if (mounted) {
      setState(() => _marketEnabled = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ayarlar güncellenirken hata oluştu.')),
      );
    }
  }

  Future<void> _loadProducts() async {
    try {
      final list = await ref.read(adminMarketServiceProvider).getAdminProducts();
      if (mounted) {
        setState(() {
          _products = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _navigateToProductForm([MarketProductModel? product]) async {
    // Navigate to our new beautiful multi-step form screen or editing hub
    final result = await context.push<bool>(
      product == null ? '/admin/market-products/form' : '/admin/market-products/hub',
      extra: product,
    );
    if (result == true) {
      _loadProducts();
    }
  }

  void _showDeleteConfirmDialog(MarketProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ürünü Sil', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('"${product.title}" isimli ürünü silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              await ref.read(adminMarketServiceProvider).deleteProduct(product.id);
              if (mounted) {
                Navigator.pop(context);
                _loadProducts();
              }
            },
            child: const Text('Evet, Sil', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleProductStatus(MarketProductModel product) async {
    setState(() => _loading = true);
    try {
      final updated = MarketProductModel(
        id: product.id,
        title: product.title,
        description: product.description,
        imageUrl: product.imageUrl,
        creditCost: product.creditCost,
        stock: product.stock,
        isActive: !product.isActive,
        type: product.type,
        category: product.category,
        fileUrl: product.fileUrl,
        fileType: product.fileType,
        metadata: product.metadata,
        createdAt: product.createdAt,
      );
      await ref.read(adminMarketServiceProvider).updateProduct(updated.id, updated.toJson());
      await _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(product.isActive ? 'Ürün pasife alındı.' : 'Ürün aktife alındı.'),
            backgroundColor: AppTheme.primaryNavy,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _duplicateProduct(MarketProductModel product) async {
    setState(() => _loading = true);
    try {
      final duplicate = MarketProductModel(
        id: '', // New product
        title: '${product.title} (Kopya)',
        description: product.description,
        imageUrl: product.imageUrl,
        creditCost: product.creditCost,
        stock: product.stock,
        isActive: false, // Start as passive
        type: product.type,
        category: product.category,
        fileUrl: product.fileUrl,
        fileType: product.fileType,
        metadata: Map<String, dynamic>.from(product.metadata),
        createdAt: DateTime.now(),
      );
      final duplicateMap = duplicate.toJson();
      duplicateMap.remove('id');
      await ref.read(adminMarketServiceProvider).addProduct(MarketProductModel.fromJson(duplicateMap));
      await _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ürün başarıyla kopyalandı (Taslak olarak kaydedildi).'),
            backgroundColor: AppTheme.primaryNavy,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showActionSheet(MarketProductModel product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Colors.black87),
                  title: const Text('Düzenle', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToProductForm(product);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined, color: Colors.black87),
                  title: const Text('Kopyala', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _duplicateProduct(product);
                  },
                ),
                ListTile(
                  leading: Icon(
                    product.isActive ? Icons.toggle_off_outlined : Icons.toggle_on_outlined,
                    color: product.isActive ? Colors.red[400] : Colors.green[400],
                  ),
                  title: Text(
                    product.isActive ? 'Pasife Al' : 'Aktife Al',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: product.isActive ? Colors.red[700] : Colors.green[700],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleProductStatus(product);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Sil', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmDialog(product);
                  },
                ),
                const Divider(),
                ListTile(
                  title: const Center(
                    child: Text('İptal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileTypeIcon(MarketProductModel p) {
    final category = p.category;
    final altCategory = p.metadata['alt_category']?.toString() ?? '';
    
    // Find category model
    final categoriesAsync = ref.read(marketCategoriesProvider);
    final categories = categoriesAsync.asData?.value ?? [];
    
    MarketCategoryModel? catModel;
    for (var c in categories) {
      if (c.label == category) {
        catModel = c;
        break;
      }
    }
    
    // Try to find subcategory
    MarketSubCategoryModel? subModel;
    if (catModel != null) {
      for (var s in catModel.subcategories) {
        if (s.label == altCategory) {
          subModel = s;
          break;
        }
      }
    }

    final isDocument = category == 'Şablonlar' || category == 'Dokümanlar';

    if (!isDocument) {
      final hexColor = catModel?.color ?? '4F46E5';
      final baseColor = MarketIconHelper.colorFromHex(hexColor);
      final bgColor = baseColor.withValues(alpha: 0.1);
      final textColor = baseColor;
      
      final iconName = subModel?.icon ?? catModel?.icon ?? 'category';
      final iconData = MarketIconHelper.get(iconName);

      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(
            iconData,
            color: textColor,
            size: 26,
          ),
        ),
      );
    }

    final type = (p.fileType ?? p.metadata['file_type'] ?? 'docx').toLowerCase();
    Color bgColor = Colors.blue[50]!;
    Color textColor = Colors.blue[800]!;
    String label = 'W';

    if (type.contains('xls')) {
      bgColor = Colors.green[50]!;
      textColor = Colors.green[800]!;
      label = 'X';
    } else if (type.contains('pdf')) {
      bgColor = Colors.red[50]!;
      textColor = Colors.red[800]!;
      label = 'PDF';
    } else if (type.contains('ppt')) {
      bgColor = Colors.orange[50]!;
      textColor = Colors.orange[800]!;
      label = 'P3';
    } else if (type.contains('zip')) {
      bgColor = Colors.purple[50]!;
      textColor = Colors.purple[800]!;
      label = 'ZIP';
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: label == 'PDF' || label == 'ZIP' ? 14 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Market categories from app_config (with fallback)
    final categoriesAsync = ref.watch(marketCategoriesProvider);
    final categoryList = categoriesAsync.when(
      data: (list) => list.map((c) => c.label).toList(),
      loading: () => const <String>['Şablonlar', 'Dokümanlar', 'Paketler', 'Araçlar', 'Eğitimler', 'Diğer'],
      error: (e, _) => const <String>['Şablonlar', 'Dokümanlar', 'Paketler', 'Araçlar', 'Eğitimler', 'Diğer'],
    );
    final allCategoryFilters = ['Tümü', ...categoryList];

    // Filter logic
    final filteredProducts = _products.where((p) {
      // Tab filter
      if (_selectedTab == 'Aktif' && !p.isActive) return false;
      if (_selectedTab == 'Pasif' && p.isActive) return false;

      // Category filter
      if (_selectedCategoryFilter != 'Tümü' && p.category != _selectedCategoryFilter) return false;

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return p.title.toLowerCase().contains(query) ||
            (p.description?.toLowerCase().contains(query) ?? false) ||
            p.category.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    final allCount = _products.length;
    final activeCount = _products.where((p) => p.isActive).length;
    final passiveCount = _products.where((p) => !p.isActive).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => context.pop(),
        ),
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Ürünlerde ara...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : const Text(
                'Ürünler',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 20),
              ),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, color: Colors.black87),
            onPressed: () {
              setState(() {
                if (_showSearch) {
                  _searchQuery = '';
                  _searchController.clear();
                }
                _showSearch = !_showSearch;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.black87),
            onPressed: () {
              // Custom config toggle or quick filter sheet
              _showMarketConfigSheet();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading || _loadingConfig
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryNavy)))
          : Column(
              children: [
                // Custom Stepper Tabs
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildTabButton('Tümü', allCount),
                      _buildTabButton('Aktif', activeCount),
                      _buildTabButton('Pasif', passiveCount),
                    ],
                  ),
                ),
                // Category filter chips (dynamic from app_config)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: allCategoryFilters.map((cat) {
                        final isSelected = _selectedCategoryFilter == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF4F46E5),
                            backgroundColor: const Color(0xFFF1F5F9),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            onSelected: (_) => setState(() => _selectedCategoryFilter = cat),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Main Content List
                Expanded(
                  child: filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_bag_outlined, size: 72, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty ? 'Eşleşen ürün bulunamadı' : 'Henüz ürün eklenmemiş',
                                style: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final p = filteredProducts[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  onTap: () => _navigateToProductForm(p),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Left File/Type Icon
                                        _buildFileTypeIcon(p),
                                        const SizedBox(width: 16),

                                        // Center details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      p.title,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                        color: Color(0xFF1E293B),
                                                      ),
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: () => _showActionSheet(p),
                                                    child: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Text(
                                                    (p.category == 'Şablonlar' || p.category == 'Dokümanlar')
                                                        ? (p.fileType ?? p.metadata['file_type'] ?? 'DOCX').toUpperCase()
                                                        : p.category,
                                                    style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                                    child: Icon(Icons.circle, size: 4, color: Colors.grey[300]),
                                                  ),
                                                  const Icon(Icons.stars_rounded, color: AppTheme.creditGold, size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${p.creditCost} Kredi',
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        // Right side stats & status badge
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: p.isActive ? const Color(0xFFE2FBE7) : const Color(0xFFFFF1F2),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                p.isActive ? 'Aktif' : 'Pasif',
                                                style: TextStyle(
                                                  color: p.isActive ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                const Icon(Icons.stars_rounded, color: AppTheme.creditGold, size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${p.creditCost}',
                                                  style: const TextStyle(
                                                    color: AppTheme.creditGold,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _buildCustomBottomNavigationBar(),
    );
  }

  Widget _buildTabButton(String label, int count) {
    final isSelected = _selectedTab == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF6366F1) : Colors.grey[500],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($count)',
                style: TextStyle(
                  color: isSelected ? const Color(0xFF6366F1) : Colors.grey[400],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sticky Add Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: ElevatedButton.icon(
                onPressed: () => _navigateToProductForm(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Yeni Ürün Ekle',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5), // Premium Indigo
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),

            // Bottom Navigation Icons
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.grid_view_rounded, 'Panel', false),
                  _buildNavItem(Icons.shopping_bag_rounded, 'Ürünler', true),
                  _buildNavItem(Icons.receipt_long_rounded, 'Siparişler', false),
                  _buildNavItem(Icons.people_alt_rounded, 'Kullanıcılar', false),
                  _buildNavItem(Icons.settings_rounded, 'Ayarlar', false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    final activeColor = const Color(0xFF4F46E5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? activeColor : Colors.grey[400],
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : Colors.grey[500],
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showMarketConfigSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Market Modül Ayarları',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tüm kullanıcıların markete erişim iznini buradan kontrol edebilirsiniz.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _marketEnabled ? Colors.green[50] : Colors.red[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _marketEnabled ? Colors.green[100]! : Colors.red[100]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _marketEnabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: _marketEnabled ? Colors.green : Colors.red,
                            size: 28,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _marketEnabled ? 'Market Aktif' : 'Market Pasif',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _marketEnabled ? Colors.green[800] : Colors.red[800],
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _marketEnabled ? 'Kullanıcılar erişebilir.' : 'Erişime kapatıldı.',
                                  style: TextStyle(
                                    color: _marketEnabled ? Colors.green[700] : Colors.red[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _marketEnabled,
                            activeColor: Colors.green,
                            onChanged: (val) async {
                              setSheetState(() {
                                _marketEnabled = val;
                              });
                              await _toggleMarket(val);
                              setState(() {});
                            },
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryNavy,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Kapat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
