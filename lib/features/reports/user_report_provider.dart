import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supabase/user_report_service.dart';
import '../../data/models/user_report_model.dart';

final userReportServiceProvider = Provider((ref) => UserReportService());

/// Admin: Tüm şikayetleri getir
final adminReportsProvider = FutureProvider.autoDispose<List<UserReportModel>>((ref) async {
  final service = ref.read(userReportServiceProvider);
  return service.getAllReports();
});
