import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/credit_service.dart';
import '../../features/home/home_provider.dart';
import '../../features/profile/profile_provider.dart';
import '../../features/credits/credit_provider.dart';

final iapProvider = AsyncNotifierProvider<IapService, List<ProductDetails>>(IapService.new);

class IapService extends AsyncNotifier<List<ProductDetails>> {
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // Bu ID'ler App Store / Play Console'da tanımladığımız ID'ler ile birebir aynı olmalı
  static const Set<String> _kProductIds = {
    'com.maligorus.maligorus.credit_100',
    'com.maligorus.maligorus.credit_250',
    'com.maligorus.maligorus.credit_500',
    'com.maligorus.maligorus.credit_1000',
    'com.maligorus.maligorus.credit_5000',
    'com.maligorus.maligorus.credit_10000',
  };

  @override
  FutureOr<List<ProductDetails>> build() async {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint('IAP Update Error: $error');
    });

    return _loadProducts();
  }

  Future<List<ProductDetails>> _loadProducts() async {
    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) return [];

      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kProductIds);
      if (response.error != null) {
        debugPrint('IAP Query Error: ${response.error}');
        return [];
      }

      // Ürünleri fiyata göre sıralayalım
      final products = response.productDetails.toList();
      products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      return products;
    } catch (e) {
      debugPrint('IAP Load Error: $e');
      return [];
    }
  }

  Future<void> buyProduct(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // İşlem bekleniyor
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase Error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // Satın alma başarılı!
          await _verifyAndAddCredits(purchaseDetails);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifyAndAddCredits(PurchaseDetails purchaseDetails) async {
    int amount = 0;
    switch (purchaseDetails.productID) {
      case 'com.maligorus.maligorus.credit_100': amount = 100; break;
      case 'com.maligorus.maligorus.credit_250': amount = 250; break;
      case 'com.maligorus.maligorus.credit_500': amount = 500; break;
      case 'com.maligorus.maligorus.credit_1000': amount = 1000; break;
      case 'com.maligorus.maligorus.credit_5000': amount = 5000; break;
      case 'com.maligorus.maligorus.credit_10000': amount = 10000; break;
    }

    if (amount > 0) {
      try {
        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        if (user != null) {
          // RPC fonksiyonunu çağırarak krediyi ekle
          await supabase.rpc(
            'add_user_credits',
            params: {
              'p_user_id': user.id,
              'p_amount': amount,
            },
          );
          
          // Paket bazlı seviye yükseltme (isteğe bağlı eklenebilir)
          if (purchaseDetails.productID.contains('5000')) {
            await ref.read(creditServiceProvider).checkAndSetHighestLevel(user.id, currentBalance: 5000, currentHighest: 'gold');
          } else if (purchaseDetails.productID.contains('10000')) {
            await ref.read(creditServiceProvider).checkAndSetHighestLevel(user.id, currentBalance: 10000, currentHighest: 'platinum');
          } else {
            await ref.read(creditServiceProvider).checkAndSetHighestLevel(user.id);
          }

          // Kredi eklendikten sonra tüm ilgili sağlayıcıları (providers) sıfırla/yenile
          ref.invalidate(homeProvider);
          ref.invalidate(profileProvider);
          ref.invalidate(creditStatsProvider);
          ref.read(creditLogsProvider.notifier).loadLogs(isRefresh: true);
        }
      } catch (e) {
        debugPrint('Kredi ekleme hatası: $e');
      }
    }
  }
}
