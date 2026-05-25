import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/theme/app_theme.dart';
import '../../data/models/market_product_model.dart';
import '../home/home_provider.dart';
import 'market_provider.dart';
import 'market_bottom_navigation_bar.dart';

class MarketCartScreen extends ConsumerWidget {
  const MarketCartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsyncValue = ref.watch(marketCartProvider);
    final profile = ref.watch(homeProvider).value?.profile;
    final balance = profile?.creditBalance ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Sepetim', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () {
              ref.read(marketCartProvider.notifier).clearCart();
            },
          ),
        ],
      ),
      body: cartAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Sepet yüklenirken hata oluştu: $err')),
        data: (items) {
          if (items.isEmpty) {
            return _buildEmptyCart(context);
          }

          final totalCost = ref.read(marketCartProvider.notifier).totalCost;
          final isBalanceSufficient = balance >= totalCost;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildCartItem(context, ref, item);
                  },
                ),
              ),
              _buildCheckoutSummary(context, ref, items, totalCost, balance, isBalanceSufficient),
            ],
          );
        },
      ),
      bottomNavigationBar: const MarketBottomNavigationBar(),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_cart_outlined, color: Colors.blue[700], size: 64),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sepetiniz Boş',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 8),
            Text(
              'Market sayfasından dilediğiniz eğitimi, sertifikayı veya dokümanı sepetinize ekleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Alışverişe Başla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, WidgetRef ref, MarketProductModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 10)],
      ),
      child: Row(
        children: [
          // Icon/Image representation based on product type
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getTypeColor(item.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getTypeIcon(item.type), color: _getTypeColor(item.type), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 2),
                Text(
                  _getTypeLabel(item.type),
                  style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${NumberFormat('#,###', 'tr_TR').format(item.creditCost)} Kredi',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  ref.read(marketCartProvider.notifier).removeFromCart(item.id);
                },
                child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutSummary(
    BuildContext context,
    WidgetRef ref,
    List<MarketProductModel> items,
    int totalCost,
    int balance,
    bool isBalanceSufficient,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Toplam Tutar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                Text(
                  '${NumberFormat('#,###', 'tr_TR').format(totalCost)} Kredi',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.primaryNavy),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mevcut Bakiyeniz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: AppTheme.creditGold, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${NumberFormat('#,###', 'tr_TR').format(balance)} Kredi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isBalanceSufficient ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (!isBalanceSufficient) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Yetersiz kredi bakiyesi. Satın almaya devam etmek için kredi yüklemeniz gerekir.',
                        style: TextStyle(color: Colors.red[900], fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isBalanceSufficient ? () => _handleCheckout(context, ref, items) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Satın Almayı Tamamla',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
            if (!isBalanceSufficient) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/credit-earn', extra: 'packages');
                  },
                  icon: const Icon(Icons.stars_rounded, color: Colors.white),
                  label: const Text(
                    'Kredi Yükle',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleCheckout(BuildContext context, WidgetRef ref, List<MarketProductModel> items) async {
    try {
      final success = await ref.read(marketCartProvider.notifier).checkout();
      if (success) {
        if (context.mounted) {
          // Clear current screen history and transition to premium success screen
          context.go('/market/purchase-success', extra: items);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Satın alım hatası: $e')));
      }
    }
  }

  Future<void> _simulateFileDownload(BuildContext context, MarketProductModel document) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/${document.title.replaceAll(' ', '_')}.${document.fileType}';
      final file = File(path);
      
      // Simulate file write of dummy template content
      await file.writeAsString('MaliGörüş Professional Template: ${document.title}');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${document.title} başarıyla indirildi: ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dosya indirme hatası: $e')));
      }
    }
  }

  Color _getTypeColor(MarketProductType type) {
    switch (type) {
      case MarketProductType.document:
        return Colors.green[600]!;
      case MarketProductType.certificate:
        return Colors.purple[600]!;
      case MarketProductType.liveTraining:
        return Colors.deepOrange[600]!;
      case MarketProductType.event:
        return Colors.blue[600]!;
      case MarketProductType.vipService:
        return Colors.amber[600]!;
    }
  }

  IconData _getTypeIcon(MarketProductType type) {
    switch (type) {
      case MarketProductType.document:
        return Icons.description_rounded;
      case MarketProductType.certificate:
        return Icons.workspace_premium_rounded;
      case MarketProductType.liveTraining:
        return Icons.video_camera_front_rounded;
      case MarketProductType.event:
        return Icons.event_rounded;
      case MarketProductType.vipService:
        return Icons.star_rounded;
    }
  }

  String _getTypeLabel(MarketProductType type) {
    switch (type) {
      case MarketProductType.document:
        return 'Doküman & Şablon';
      case MarketProductType.certificate:
        return 'Sertifika Programı';
      case MarketProductType.liveTraining:
        return 'Canlı Eğitim Atölyesi';
      case MarketProductType.event:
        return 'Sektörel Etkinlik / Webinar';
      case MarketProductType.vipService:
        return 'VIP Özel Hizmet';
    }
  }
}
