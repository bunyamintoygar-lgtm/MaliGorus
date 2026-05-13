import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/listing_model.dart';
import '../supabase/credit_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final listingRepositoryProvider = Provider((ref) {
  final creditService = ref.watch(creditServiceProvider);
  return ListingRepository(creditService);
});

class ListingRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final CreditService _creditService;

  ListingRepository(this._creditService);

  // Listeleme
  Future<List<ListingModel>> getListings({int page = 0, int pageSize = 20, String? category, String? searchQuery}) async {
    final lastMonth = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    
    final from = page * pageSize;
    final to = from + pageSize - 1;

    var query = _client
        .from('listings')
        .select('*, profiles(full_name, profession, highest_level), application_count:listing_applications(count)')
        .gte('created_at', lastMonth);
        
    if (category != null && category != 'hepsi') {
      query = query.eq('category', category);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      
      // Türkçe karakterler için olası büyük/küçük harf varyasyonları
      final lowerTr = q.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
      final upperTr = q.replaceAll('ı', 'I').replaceAll('i', 'İ').toUpperCase();
      
      // Baş harfi büyük varyasyon (ör: 'iş' -> 'İş')
      final capTr = lowerTr.isNotEmpty ? lowerTr.replaceRange(0, 1, upperTr[0]) : lowerTr;

      // Tüm varyasyonları benzersiz bir sette toplayalım
      final variations = {q, lowerTr, upperTr, capTr, q.toLowerCase(), q.toUpperCase()};
      
      // Varyasyonları Supabase OR formatına çevirelim
      final orFilters = variations.map((v) => 'title.ilike.%$v%').join(',');
      query = query.or(orFilters);
    }
        
    final response = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(from, to);
    
    return (response as List).map((e) => ListingModel.fromJson(e)).toList();
  }

  // Kullanıcıya ait İlanları Listele
  Future<List<ListingModel>> getListingsByUser(String userId) async {
    final response = await _client
        .from('listings')
        .select('*, profiles(full_name, profession, highest_level), application_count:listing_applications(count)')
        .eq('author_id', userId)
        .order('created_at', ascending: false);
    
    return (response as List).map((e) => ListingModel.fromJson(e)).toList();
  }

  // Başvurduğum İlanları Listele
  Future<List<ListingModel>> getListingsByApplicant(String userId) async {
    final response = await _client
        .from('listing_applications')
        .select('listings (*, profiles(full_name, profession, highest_level), application_count:listing_applications(count))')
        .eq('applicant_id', userId)
        .order('created_at', ascending: false);
    
    return (response as List).map((e) => ListingModel.fromJson(e['listings'])).toList();
  }

  // İlan Yayınla
  Future<bool> createListing({
    required String title,
    required String description,
    required String category,
    required String location,
    bool isOffTopic = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    // 1. Kredi harca (İlan yayınlama bedeli)
    final (amountProcessed, _) = await _creditService.processCreditAction(
      actionKey: 'listing_create',
      description: 'Yeni ilan yayınlandı: $title',
    );

    if (amountProcessed == null) return false;

    // 2. İlanı kaydet
    await _client.from('listings').insert({
      'author_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'location': location,
      'is_off_topic': isOffTopic,
    });

    return true;
  }


  // İlana Başvur
  Future<bool> applyToListing(String listingId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    // 2. Başvuruyu kaydet
    await _client.from('listing_applications').insert({
      'listing_id': listingId,
      'applicant_id': userId,
    });

    return true;
  }

  // Başvuru Durumunu Kontrol Et
  Future<bool> hasUserApplied(String listingId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _client
        .from('listing_applications')
        .select('id')
        .eq('listing_id', listingId)
        .eq('applicant_id', userId)
        .maybeSingle();
    
    return response != null;
  }

  // Başvuruyu Geri Çek
  Future<bool> withdrawApplication(String listingId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    await _client
        .from('listing_applications')
        .delete()
        .eq('listing_id', listingId)
        .eq('applicant_id', userId);
    
    return true;
  }

  // İlana gelen başvuruları getir
  Future<List<Map<String, dynamic>>> getApplicationsForListing(String listingId) async {
    try {
      final response = await _client
          .from('listing_applications')
          .select('*, profiles:applicant_id(id, full_name, avatar_url, profession)')
          .eq('listing_id', listingId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Başvuruları getirme hatası: $e');
      return [];
    }
  }

  // İlan Güncelle
  Future<bool> updateListing({
    required String id,
    required String title,
    required String description,
    required String category,
    required String location,
  }) async {
    await _client.from('listings').update({
      'title': title,
      'description': description,
      'category': category,
      'location': location,
    }).eq('id', id);
    return true;
  }

  // İlan Sil
  Future<bool> deleteListing(String id) async {
    await _client.from('listings').delete().eq('id', id);
    return true;
  }
}
