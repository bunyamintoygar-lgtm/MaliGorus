import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/market_product_model.dart';
import '../models/market_purchase_model.dart';

final adminMarketServiceProvider = Provider((ref) => AdminMarketService());

class AdminMarketService {
  final SupabaseClient _client = Supabase.instance.client;

  // Tüm market ürünlerini getir (Admin için aktif/pasif hepsi dahil)
  Future<List<MarketProductModel>> getAdminProducts() async {
    final response = await _client
        .from('market_products')
        .select('*')
        .order('created_at', ascending: false);
    
    return (response as List).map((json) => MarketProductModel.fromJson(json)).toList();
  }

  // Yeni market ürünü ekle (Admin)
  Future<void> addProduct(MarketProductModel product) async {
    await _client.from('market_products').insert(product.toJson());
  }

  // Market ürünü güncelle (Admin)
  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    await _client.from('market_products').update(data).eq('id', id);
  }

  // Market ürünü sil (Admin)
  Future<void> deleteProduct(String id) async {
    await _client.from('market_products').delete().eq('id', id);
  }

  // Tüm satın almaları getir (Admin)
  Future<List<MarketPurchaseModel>> getAllPurchases({
    int offset = 0,
    int limit = 20,
    String? status,
    String? searchTerm,
  }) async {
    var query = _client
        .from('market_purchases')
        .select('*, market_products(*), profiles(full_name)');

    if (status != null && status != 'all') {
      query = query.eq('status', status);
    }

    if (searchTerm != null && searchTerm.isNotEmpty) {
      query = query.or('profiles.full_name.ilike.%$searchTerm%,market_products.title.ilike.%$searchTerm%');
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    
    return (response as List).map((json) => MarketPurchaseModel.fromJson(json)).toList();
  }

  // Satın alma durumunu güncelle ve iptal durumunda krediyi iade et
  Future<void> updatePurchaseStatus(MarketPurchaseModel purchase, String newStatus) async {
    // 1. Mevcut durumu kontrol et (Zaten güncellenmişse işlem yapma)
    final check = await _client
        .from('market_purchases')
        .select('status')
        .eq('id', purchase.id)
        .single();
    
    if (check['status'] == newStatus) return;

    // 2. Durumu güncelle
    await _client
        .from('market_purchases')
        .update({'status': newStatus})
        .eq('id', purchase.id);

    // 3. Eğer iptal edildiyse krediyi iade et
    if (newStatus == 'cancelled') {
      try {
        await _client.rpc('increment_credit', params: {
          'user_id': purchase.userId,
          'amount': purchase.creditPaid,
        });
      } catch (rpcError) {
        // RPC Fallback
        final freshProfile = await _client
            .from('profiles')
            .select('credit_balance')
            .eq('id', purchase.userId)
            .single();
        
        final currentBalance = freshProfile['credit_balance'] as int;
        await _client
            .from('profiles')
            .update({'credit_balance': currentBalance + purchase.creditPaid})
            .eq('id', purchase.userId);
      }

      // 4. Kredi logu oluştur
      try {
        await _client.from('credit_logs').insert({
          'user_id': purchase.userId,
          'amount': purchase.creditPaid,
          'action': 'market_refund',
          'description': '${purchase.product?.title ?? 'Ürün'} iadesi (İptal)',
        });
      } catch (e) {
        print('Refund credit logging skipped: $e');
      }

      // 5. Stoğu geri iade et
      if (purchase.product != null && purchase.product!.stock < 999) {
        try {
          await _client
              .from('market_products')
              .update({'stock': purchase.product!.stock + 1})
              .eq('id', purchase.productId);
        } catch (e) {
          print('Refund stock increment skipped: $e');
        }
      }
    }
  }
}
