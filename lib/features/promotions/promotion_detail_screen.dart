import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/promotion_model.dart';
import '../../data/supabase/promotion_service.dart';
import '../home/home_provider.dart';
import 'package:go_router/go_router.dart';

class PromotionDetailScreen extends ConsumerStatefulWidget {
  final PromotionModel promotion;
  final bool isPurchased;

  const PromotionDetailScreen({
    super.key,
    required this.promotion,
    required this.isPurchased,
  });

  @override
  ConsumerState<PromotionDetailScreen> createState() => _PromotionDetailScreenState();
}

class _PromotionDetailScreenState extends ConsumerState<PromotionDetailScreen> {
  bool _isPurchasing = false;
  late bool _currentPurchased;

  @override
  void initState() {
    super.initState();
    _currentPurchased = widget.isPurchased;
  }

  Future<void> _handlePurchase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('market_buy_confirm_title'.tr()),
        content: Text('market_buy_confirm_body'.tr(args: [widget.promotion.title, widget.promotion.creditCost.toString()])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
            child: Text('market_buy'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isPurchasing = true);
      try {
        final success = await ref.read(promotionServiceProvider).purchasePromotion(widget.promotion);
        if (success && context.mounted) {
          setState(() {
            _currentPurchased = true;
            _isPurchasing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('market_buy_success'.tr())),
          );
          // Bakiyeyi güncellemek için homeProvider'ı tetikle
          ref.read(homeProvider.notifier).loadHomeData();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isPurchasing = false);
          String message = e.toString();
          if (message.contains('Exception: ')) {
            message = message.replaceAll('Exception: ', '');
          }
          
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(
                    message.contains('bakiye') ? Icons.account_balance_wallet_outlined : Icons.error_outline,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 12),
                  Text('common_error'.tr()),
                ],
              ),
              content: Text(
                message,
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                if (message.contains('bakiye'))
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/credit-earn');
                    },
                    child: Text('credit_earn_title'.tr(), style: const TextStyle(color: AppTheme.actionBlue, fontWeight: FontWeight.bold)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('common_confirm'.tr(), style: const TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: widget.promotion.imageUrl != null && widget.promotion.imageUrl!.isNotEmpty
                  ? Image.network(widget.promotion.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[100],
                      child: const Icon(Icons.card_giftcard_rounded, size: 80, color: Colors.grey),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.promotion.title,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.creditGold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: AppTheme.creditGold, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.promotion.creditCost}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.creditGold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'market_stock'.tr(args: [widget.promotion.stock.toString()]),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'market_description_title'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.promotion.description ?? 'market_no_description'.tr(),
                    style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.5),
                  ),
                  const SizedBox(height: 100), // Bottom padding for button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (widget.promotion.stock > 0 && !_currentPurchased && !_isPurchasing) 
                  ? _handlePurchase 
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentPurchased ? Colors.green : AppTheme.primaryNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isPurchasing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _currentPurchased 
                          ? 'market_request_received'.tr() 
                          : (widget.promotion.stock > 0 ? 'market_buy_now'.tr() : 'market_out_of_stock'.tr()),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
