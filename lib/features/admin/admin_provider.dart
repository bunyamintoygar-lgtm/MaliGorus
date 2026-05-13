import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supabase/admin_service.dart';

final adminServiceProvider = Provider((ref) => AdminService());

/// Dashboard istatistikleri
final adminStatsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  return ref.read(adminServiceProvider).getStats();
});

/// Kullanıcı büyüme grafiği verileri
final adminGrowthProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(adminServiceProvider).getUserGrowth();
});

/// Tüm ilanlar (admin)
final adminListingsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(adminServiceProvider).getAllListings();
});

/// Duyurular
final adminAnnouncementsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(adminServiceProvider).getAnnouncements();
});
