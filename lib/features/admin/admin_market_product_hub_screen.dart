import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/app_config_provider.dart';
import '../../core/utils/market_icon_helper.dart';
import '../../data/models/market_product_model.dart';
import '../../data/models/market_category_model.dart';
import '../../data/supabase/admin_market_service.dart';

class AdminMarketProductHubScreen extends ConsumerStatefulWidget {
  final MarketProductModel product;

  const AdminMarketProductHubScreen({super.key, required this.product});

  @override
  ConsumerState<AdminMarketProductHubScreen> createState() => _AdminMarketProductHubScreenState();
}

class _AdminMarketProductHubScreenState extends ConsumerState<AdminMarketProductHubScreen> {
  late MarketProductModel _currentProduct;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
  }

  Future<void> _toggleStatus() async {
    setState(() => _loading = true);
    try {
      final updated = MarketProductModel(
        id: _currentProduct.id,
        title: _currentProduct.title,
        description: _currentProduct.description,
        imageUrl: _currentProduct.imageUrl,
        creditCost: _currentProduct.creditCost,
        stock: _currentProduct.stock,
        isActive: !_currentProduct.isActive,
        type: _currentProduct.type,
        category: _currentProduct.category,
        fileUrl: _currentProduct.fileUrl,
        fileType: _currentProduct.fileType,
        metadata: _currentProduct.metadata,
        createdAt: _currentProduct.createdAt,
      );
      await ref.read(adminMarketServiceProvider).updateProduct(updated.id, updated.toJson());
      setState(() {
        _currentProduct = updated;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_currentProduct.isActive ? 'Ürün aktife alındı.' : 'Ürün pasife alındı.'),
            backgroundColor: AppTheme.primaryNavy,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildFileTypeIcon(MarketProductModel p) {
    final category = p.category;
    final isDocument = category == 'Şablonlar' || category == 'Dokümanlar';

    if (!isDocument) {
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

      final hexColor = catModel?.color ?? '4F46E5';
      final baseColor = MarketIconHelper.colorFromHex(hexColor);
      final bgColor = baseColor.withValues(alpha: 0.1);
      final textColor = baseColor;
      
      final iconName = subModel?.icon ?? catModel?.icon ?? 'category';
      final iconData = MarketIconHelper.get(iconName);

      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Icon(
            iconData,
            color: textColor,
            size: 28,
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
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: label == 'PDF' || label == 'ZIP' ? 14 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => context.pop(true), // Return true to refresh list
        ),
        title: const Text(
          'Ürün Düzenle',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Premium Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildFileTypeIcon(_currentProduct),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _currentProduct.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _currentProduct.isActive ? const Color(0xFFE2FBE7) : const Color(0xFFFFF1F2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _currentProduct.isActive ? 'Aktif' : 'Pasif',
                                          style: TextStyle(
                                            color: _currentProduct.isActive ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${(_currentProduct.category == 'Şablonlar' || _currentProduct.category == 'Dokümanlar' ? (_currentProduct.fileType ?? _currentProduct.metadata['file_type'] ?? "docx").toUpperCase() : _currentProduct.category)} • ${_currentProduct.creditCost} Kredi    ID: #${_currentProduct.id.substring(0, 4)}',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Preview Button
                        OutlinedButton.icon(
                          onPressed: () {
                            context.push('/market/detail', extra: _currentProduct);
                          },
                          icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                          label: const Text('Önizleme', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Settings Hub List
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildHubTile(
                          icon: Icons.edit_note_rounded,
                          iconColor: const Color(0xFF0EA5E9),
                          title: 'Temel Bilgiler',
                          subtitle: 'Ürün adı, açıklama, kategori vb.',
                          step: 0,
                        ),
                        const Divider(height: 1, indent: 64),
                        _buildHubTile(
                          icon: Icons.folder_open_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          title: 'Dosyalar',
                          subtitle: 'Yüklü dosyalar ve görseller',
                          step: 1,
                        ),
                        const Divider(height: 1, indent: 64),
                        _buildHubTile(
                          icon: Icons.stars_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'Fiyat & Ayarlar',
                          subtitle: 'Fiyat, görünürlük ve erişim ayarları',
                          step: 2,
                        ),
                        const Divider(height: 1, indent: 64),
                        _buildHubTile(
                          icon: Icons.search_rounded,
                          iconColor: const Color(0xFFEC4899),
                          title: 'SEO & Etiketler',
                          subtitle: 'Arama motoru ve etiket yönetimi',
                          step: 0, // Fallback to basic
                        ),
                        const Divider(height: 1, indent: 64),
                        _buildHubTile(
                          icon: Icons.star_outline_rounded,
                          iconColor: const Color(0xFF10B981),
                          title: 'Sıralama & Öne Çıkarma',
                          subtitle: 'Ürün sıralaması ve öne çıkarma',
                          step: 2, // Fallback to pricing & settings
                        ),
                        const Divider(height: 1, indent: 64),
                        _buildHubTile(
                          icon: Icons.trending_up_rounded,
                          iconColor: const Color(0xFFEF4444),
                          title: 'İstatistikler',
                          subtitle: 'Görüntüleme ve satış istatistikleri',
                          step: 0, // Fallback to basic
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Bottom Action Buttons
                  ElevatedButton(
                    onPressed: () => context.pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Güncelle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _toggleStatus,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _currentProduct.isActive ? Colors.red[600] : Colors.green[600],
                      side: BorderSide(color: _currentProduct.isActive ? Colors.red[100]! : Colors.green[100]!),
                      backgroundColor: _currentProduct.isActive ? Colors.red[50] : Colors.green[50],
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _currentProduct.isActive ? 'Ürünü Pasife Al' : 'Ürünü Aktife Al',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHubTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required int step,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
      onTap: () async {
        final result = await context.push<bool>(
          '/admin/market-products/form',
          extra: {
            'product': _currentProduct,
            'initialStep': step,
          },
        );
        if (result == true) {
          // Fetch updated product from DB
          setState(() => _loading = true);
          try {
            final list = await ref.read(adminMarketServiceProvider).getAdminProducts();
            final matched = list.firstWhere((element) => element.id == _currentProduct.id);
            setState(() {
              _currentProduct = matched;
            });
          } catch (e) {
            // ignore
          } finally {
            setState(() => _loading = false);
          }
        }
      },
    );
  }
}
