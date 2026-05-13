import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/promotion_model.dart';
import '../../data/supabase/promotion_service.dart';
import 'package:go_router/go_router.dart';
import '../home/home_provider.dart';
import '../../core/utils/level_permissions.dart';
import '../../core/providers/app_config_provider.dart';

class PromotionMarketScreen extends ConsumerStatefulWidget {
  const PromotionMarketScreen({super.key});

  @override
  ConsumerState<PromotionMarketScreen> createState() => _PromotionMarketScreenState();
}

class _PromotionMarketScreenState extends ConsumerState<PromotionMarketScreen> {
  List<PromotionModel> _promotions = [];
  Set<String> _purchasedPromoIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPromotions();
  }

  Future<void> _loadPromotions() async {
    try {
      final promos = await ref.read(promotionServiceProvider).getPromotions();
      final purchases = await ref.read(promotionServiceProvider).getMyPurchases();
      if (mounted) {
        setState(() {
          _promotions = promos;
          _purchasedPromoIds = purchases
              .where((p) => p.promotionId != null)
              .map((p) => p.promotionId!)
              .toSet();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userCredits = ref.watch(homeProvider).value?.profile?.creditBalance ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('market_title'.tr()),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: AppTheme.creditGold, size: 18),
                    const SizedBox(width: 6),
                    Text('$userCredits', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPromotions,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _promotions.isEmpty
                ? Center(child: Text('market_no_promotions'.tr()))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _promotions.length,
                    itemBuilder: (context, index) {
                      final promo = _promotions[index];
                      return _buildPromoCard(promo);
                    },
                  ),
      ),
    );
  }

  Widget _buildPromoCard(PromotionModel promo) {
    final isPurchased = _purchasedPromoIds.contains(promo.id);

    return InkWell(
      onTap: () async {
        final myLevel = ref.read(homeProvider).value?.profile?.highestLevel;
        final levels = ref.read(levelConfigProvider).value ?? [];
        if (!LevelPermissions.hasPermission(myLevel, AppPermission.shopMarket, levels)) {
          LevelPermissions.showAccessDeniedDialog(context, AppPermission.shopMarket);
          return;
        }
        
        await context.push('/promotions/detail', extra: {
          'promotion': promo,
          'isPurchased': isPurchased,
        });
        _loadPromotions();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: promo.imageUrl != null && promo.imageUrl!.isNotEmpty
                      ? Image.network(promo.imageUrl!, fit: BoxFit.cover, width: double.infinity)
                      : const Center(child: Icon(Icons.card_giftcard_rounded, size: 48, color: Colors.grey)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promo.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    promo.description ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: AppTheme.creditGold, size: 14),
                          const SizedBox(width: 4),
                          Text('${promo.creditCost}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      if (isPurchased)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('market_purchased'.tr(), style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      else
                        Text('market_stock'.tr(args: [promo.stock.toString()]), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
