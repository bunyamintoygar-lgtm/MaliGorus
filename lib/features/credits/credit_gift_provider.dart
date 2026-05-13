import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supabase/credit_service.dart';

final giftLogsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, otherUserId) async {
  final service = ref.read(creditServiceProvider);
  return service.getGiftLogs(otherUserId);
});

final pendingGiftProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.read(creditServiceProvider);
  return service.getPendingGift();
});
