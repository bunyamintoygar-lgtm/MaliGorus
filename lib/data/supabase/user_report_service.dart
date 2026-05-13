import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_report_model.dart';

class UserReportService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Yeni şikayet oluştur
  Future<bool> createReport({
    required String reportedId,
    required String category,
    String? description,
    String contentType = 'user',
    String? contentTitle,
    String? contentId,
    String? contentBody,
  }) async {
    final reporterId = _client.auth.currentUser?.id;
    if (reporterId == null || (contentType == 'user' && reporterId == reportedId)) return false;

    try {
      await _client.from('user_reports').insert({
        'reporter_id': reporterId,
        'reported_id': reportedId,
        'category': category,
        'content_type': contentType,
        if (contentTitle != null) 'content_title': contentTitle,
        if (contentId != null) 'content_id': contentId,
        if (contentBody != null) 'content_body': contentBody,
        if (description != null && description.isNotEmpty) 'description': description,
      });
      return true;
    } catch (e) {
      print('Şikayet gönderme hatası: $e');
      return false;
    }
  }

  /// Admin: Tüm şikayetleri getir (profil bilgileriyle join)
  Future<List<UserReportModel>> getAllReports() async {
    final response = await _client
        .from('user_reports')
        .select('''
          *,
          reporter:profiles!user_reports_reporter_id_fkey(full_name, avatar_url),
          reported:profiles!user_reports_reported_id_fkey(full_name, avatar_url)
        ''')
        .order('created_at', ascending: false);

    return (response as List).map((e) => UserReportModel.fromJson(e)).toList();
  }

  /// Admin: Şikayet durumunu güncelle
  Future<bool> updateReportStatus(String reportId, String newStatus) async {
    try {
      await _client
          .from('user_reports')
          .update({'status': newStatus})
          .eq('id', reportId);
      return true;
    } catch (e) {
      print('Durum güncelleme hatası: $e');
      return false;
    }
  }

  /// Admin: Şikayeti sil
  Future<bool> deleteReport(String reportId) async {
    try {
      await _client.from('user_reports').delete().eq('id', reportId);
      return true;
    } catch (e) {
      print('Şikayet silme hatası: $e');
      return false;
    }
  }
}
