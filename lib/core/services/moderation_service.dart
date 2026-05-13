import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ModerationMode { content, name }
enum ModerationStatus { approved, inappropriate, offTopic }

class ModerationResult {
  final ModerationStatus status;
  final String? reason;

  ModerationResult({required this.status, this.reason});

  bool get isApproved => status == ModerationStatus.approved;
  bool get isInappropriate => status == ModerationStatus.inappropriate;
  bool get isOffTopic => status == ModerationStatus.offTopic;
}

final moderationServiceProvider = Provider((ref) => ModerationService());

class ModerationService {
  final _supabase = Supabase.instance.client;

  /// Supabase Edge Function üzerinden içerik denetimi yapar
  Future<ModerationResult> moderate(
    String text, {
    ModerationMode mode = ModerationMode.content,
    bool isNewTopic = false,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'moderate-content',
        body: {
          'text': text,
          'mode': mode == ModerationMode.name ? 'name' : 'content',
          'is_new_topic': isNewTopic,
        },
      );

      if (response.status != 200) {
        debugPrint('Moderasyon servis hatası (Status: ${response.status})');
        return ModerationResult(status: ModerationStatus.approved);
      }

      final data = response.data as Map<String, dynamic>;
      return _parseResponse(data['result'] as String?);
    } catch (e) {
      debugPrint('Moderasyon bağlantı hatası: $e');
      return ModerationResult(status: ModerationStatus.approved);
    }
  }

  /// Supabase Edge Function üzerinden resim denetimi yapar
  Future<ModerationResult> moderateImage(Uint8List imageBytes, String mimeType) async {
    try {
      final base64Image = base64Encode(imageBytes);

      final response = await _supabase.functions.invoke(
        'moderate-content',
        body: {
          'image': base64Image,
          'mimeType': mimeType,
          'mode': 'image',
          'is_new_topic': false,
        },
      );

      if (response.status != 200) {
        debugPrint('Resim moderasyon servis hatası (Status: ${response.status})');
        return ModerationResult(status: ModerationStatus.approved);
      }

      final data = response.data as Map<String, dynamic>;
      return _parseResponse(data['result'] as String?);
    } catch (e) {
      debugPrint('Resim moderasyon bağlantı hatası: $e');
      return ModerationResult(status: ModerationStatus.approved);
    }
  }

  ModerationResult _parseResponse(String? responseText) {
    final text = responseText?.trim().toUpperCase() ?? 'ONAY';
    
    if (text.contains('UYGUNSUZ_ICERIK') || text.contains('RED')) {
      return ModerationResult(
        status: ModerationStatus.inappropriate,
        reason: 'Hakaret ve aşağılayıcı sözler tespit edildi.',
      );
    } else if (text.contains('KONU_DISI')) {
      return ModerationResult(
        status: ModerationStatus.offTopic,
        reason: 'Konu dışı içerik tespit edildi.',
      );
    }
    
    return ModerationResult(status: ModerationStatus.approved);
  }
}
