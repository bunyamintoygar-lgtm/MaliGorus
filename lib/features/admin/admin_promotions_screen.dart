import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/promotion_model.dart';
import '../../data/supabase/promotion_service.dart';
import '../../data/supabase/credit_service.dart';

class AdminPromotionsScreen extends ConsumerStatefulWidget {
  const AdminPromotionsScreen({super.key});

  @override
  ConsumerState<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends ConsumerState<AdminPromotionsScreen> {
  List<PromotionModel> _promotions = [];
  bool _loading = true;
  bool _marketEnabled = true;
  bool _loadingConfig = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadPromotions(),
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

  Future<void> _loadPromotions() async {
    try {
      final promos = await ref.read(promotionServiceProvider).getPromotions(onlyActive: false);
      if (mounted) {
        setState(() {
          _promotions = promos;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddEditDialog([PromotionModel? promo]) {
    final titleController = TextEditingController(text: promo?.title);
    final descController = TextEditingController(text: promo?.description);
    final costController = TextEditingController(text: promo?.creditCost.toString());
    final stockController = TextEditingController(text: promo?.stock.toString());
    final imageController = TextEditingController(text: promo?.imageUrl);
    bool isActive = promo?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(promo == null ? 'Yeni Ürün Ekle' : 'Ürünü Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Ürün Adı'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                  maxLines: 2,
                ),
                TextField(
                  controller: costController,
                  decoration: const InputDecoration(labelText: 'Kredi Maliyeti'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: stockController,
                  decoration: const InputDecoration(labelText: 'Stok Adedi'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: imageController,
                  decoration: const InputDecoration(labelText: 'Resim URL (Opsiyonel)'),
                ),
                SwitchListTile(
                  title: const Text('Aktif mi?'),
                  value: isActive,
                  onChanged: (val) => setDialogState(() => isActive = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPromo = PromotionModel(
                  id: promo?.id ?? '',
                  title: titleController.text,
                  description: descController.text,
                  creditCost: int.tryParse(costController.text) ?? 0,
                  stock: int.tryParse(stockController.text) ?? 0,
                  imageUrl: imageController.text,
                  isActive: isActive,
                  createdAt: promo?.createdAt ?? DateTime.now(),
                );

                if (promo == null) {
                  await ref.read(promotionServiceProvider).addPromotion(newPromo);
                } else {
                  await ref.read(promotionServiceProvider).updatePromotion(promo.id, newPromo.toJson());
                }
                
                if (mounted) {
                  Navigator.pop(context);
                  _loadPromotions();
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promosyon Yönetimi'),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppTheme.primaryNavy,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: (_loading || _loadingConfig)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Market Aktif/Pasif Bölümü
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _marketEnabled ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _marketEnabled ? Colors.green[100]! : Colors.red[100]!),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      _marketEnabled ? 'Market Modülü: AKTİF' : 'Market Modülü: PASİF',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: _marketEnabled ? Colors.green[800] : Colors.red[800]
                      ),
                    ),
                    subtitle: Text(
                      _marketEnabled ? 'Kullanıcılar kredi sayfasında market butonunu görebilir.' : 'Kullanıcılar markete erişemez.',
                      style: TextStyle(fontSize: 12, color: _marketEnabled ? Colors.green[700] : Colors.red[700]),
                    ),
                    value: _marketEnabled,
                    activeColor: Colors.green,
                    onChanged: _toggleMarket,
                    secondary: Icon(
                      _marketEnabled ? Icons.shopping_cart : Icons.shopping_cart_outlined,
                      color: _marketEnabled ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _promotions.isEmpty
                      ? const Center(child: Text('Henüz ürün eklenmemiş'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                  itemCount: _promotions.length,
                  itemBuilder: (context, index) {
                    final promo = _promotions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: promo.imageUrl != null && promo.imageUrl!.isNotEmpty
                              ? Image.network(promo.imageUrl!, fit: BoxFit.cover)
                              : const Icon(Icons.shopping_bag_outlined),
                        ),
                        title: Text(promo.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${promo.creditCost} Kredi | Stok: ${promo.stock}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              promo.isActive ? Icons.check_circle : Icons.cancel,
                              color: promo.isActive ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showAddEditDialog(promo),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                ),
              ],
            ),
    );
  }
}
