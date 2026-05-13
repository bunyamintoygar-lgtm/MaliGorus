import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/promotion_model.dart';

final promotionServiceProvider = Provider((ref) => PromotionService());

class PromotionService {
  final SupabaseClient _client = Supabase.instance.client;

  // Tüm aktif promosyonları getir
  Future<List<PromotionModel>> getPromotions({bool onlyActive = true}) async {
    var query = _client.from('promotions').select('*');
    
    if (onlyActive) {
      query = query.eq('is_active', true);
    }
    
    final response = await query.order('created_at', ascending: false);
    return (response as List).map((json) => PromotionModel.fromJson(json)).toList();
  }

  // Yeni promosyon ekle (Admin)
  Future<void> addPromotion(PromotionModel promotion) async {
    await _client.from('promotions').insert(promotion.toJson());
  }

  // Promosyon güncelle (Admin)
  Future<void> updatePromotion(String id, Map<String, dynamic> data) async {
    await _client.from('promotions').update(data).eq('id', id);
  }

  // Promosyon sil (Admin)
  Future<void> deletePromotion(String id) async {
    await _client.from('promotions').delete().eq('id', id);
  }

  // Promosyon satın al
  Future<bool> purchasePromotion(PromotionModel promotion) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      // 1. Kullanıcının kredisini kontrol et
      final profileResponse = await _client
          .from('profiles')
          .select('credit_balance')
          .eq('id', userId)
          .single();
      
      final currentBalance = profileResponse['credit_balance'] as int;
      if (currentBalance < promotion.creditCost) {
        throw Exception('Yetersiz kredi bakiyesi');
      }

      // 2. Stok kontrolü
      if (promotion.stock <= 0) {
        throw Exception('Ürün stokta kalmadı');
      }

      // 3. İşlemi gerçekleştir (RPC ile atomik bakiye düşüşü)
      await _client.rpc('increment_credit', params: {
        'user_id': userId,
        'amount': -promotion.creditCost,
      });

      // 4. Stok düşür
      await _client.from('promotions').update({
        'stock': promotion.stock - 1,
      }).eq('id', promotion.id);

      // 5. Satın alma kaydı oluştur
      await _client.from('promotion_purchases').insert({
        'user_id': userId,
        'promotion_id': promotion.id,
        'credit_amount': promotion.creditCost,
        'status': 'pending',
      });

      // 6. Kredi logu oluştur
      await _client.from('credit_logs').insert({
        'user_id': userId,
        'amount': -promotion.creditCost,
        'action': 'promotion_purchase',
        'description': '${promotion.title} satın alındı',
      });

      return true;
    } catch (e) {
      print('Purchase Error: $e');
      rethrow;
    }
  }

  // Kullanıcının satın almalarını getir
  Future<List<PromotionPurchaseModel>> getMyPurchases() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('promotion_purchases')
        .select('*, promotions(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    
    return (response as List).map((json) => PromotionPurchaseModel.fromJson(json)).toList();
  }

  // Tüm satın almaları getir (Admin)
  Future<List<PromotionPurchaseModel>> getAllPurchases({
    int offset = 0,
    int limit = 20,
    String? status,
    String? searchTerm,
  }) async {
    var query = _client
        .from('promotion_purchases')
        .select('*, promotions(*), profiles(full_name)');

    if (status != null && status != 'all') {
      query = query.eq('status', status);
    }

    if (searchTerm != null && searchTerm.isNotEmpty) {
      // Not: Supabase'de join tablolarında arama yapmak için filter kullanıyoruz
      query = query.or('profiles.full_name.ilike.%$searchTerm%,promotions.title.ilike.%$searchTerm%');
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    
    return (response as List).map((json) => PromotionPurchaseModel.fromJson(json)).toList();
  }

  // Satın alma durumunu güncelle ve iptal durumunda krediyi iade et
  Future<void> updatePurchaseStatus(PromotionPurchaseModel purchase, String newStatus) async {
    // 1. Mevcut durumu kontrol et (Zaten güncellenmişse işlem yapma)
    final check = await _client
        .from('promotion_purchases')
        .select('status')
        .eq('id', purchase.id)
        .single();
    
    if (check['status'] == newStatus) return;

    // 2. Durumu güncelle
    await _client
        .from('promotion_purchases')
        .update({'status': newStatus})
        .eq('id', purchase.id);

    // 3. Eğer iptal edildiyse krediyi iade et
    if (newStatus == 'cancelled') {
      await _client.rpc('increment_credit', params: {
        'user_id': purchase.userId,
        'amount': purchase.creditAmount,
      });

      // 4. Kredi logu oluştur
      await _client.from('credit_logs').insert({
        'user_id': purchase.userId,
        'amount': purchase.creditAmount,
        'action': 'promotion_refund',
        'description': '${purchase.promotion?.title ?? 'Ürün'} iadesi (İptal)',
      });
    }
  }
}
