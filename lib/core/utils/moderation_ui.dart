import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/moderation_service.dart';

class ModerationUI {
  static Future<bool> check(
    BuildContext context, 
    ModerationService service, 
    String text, {
    ModerationMode mode = ModerationMode.content,
    bool isNewTopic = false,
    void Function()? onOffTopicApproved,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId != null) {
      try {
        final profileResponse = await client.from('profiles').select().eq('id', userId).maybeSingle();
        if (profileResponse != null) {
          // 1. Süresiz engel kontrolü
          final isIndefiniteBlocked = profileResponse['is_indefinite_blocked'] as bool? ?? false;
          if (isIndefiniteBlocked) {
            final isAppealPending = profileResponse['is_appeal_pending'] as bool? ?? false;
            if (isAppealPending) {
              await _showInfoDialog(context, 'İnceleme Devam Ediyor', 'Değerlendirmeniz admin tarafından inceleniyor. Lütfen bekleyiniz.');
            } else {
              await _showAppealDialog(context, userId);
            }
            return false;
          }

          // 2. Geçici engel kontrolü
          if (profileResponse['temp_blocked_until'] != null) {
            String cleanStr = (profileResponse['temp_blocked_until'] as String).trim();
            if (!cleanStr.contains('Z') && !cleanStr.contains('+') && !cleanStr.contains('-')) {
              cleanStr += 'Z';
            }
            final tempBlockedUntil = DateTime.parse(cleanStr).toUtc();
            final nowUtc = DateTime.now().toUtc();
            
            if (tempBlockedUntil.isAfter(nowUtc)) {
              await _showInfoDialog(context, 'Geçici Engelleme', 'Birden fazla topluluk kurallarına uygun yazılara uymadığınız için 5 dakikalığına bloklandınız.');
              return false;
            } else {
              // Süre dolduysa veritabanında temp_blocked_until'i temizleyelim
              await client.from('profiles').update({'temp_blocked_until': null}).eq('id', userId);
            }
          }
        }

      } catch (e) {
        debugPrint('Kullanıcı durum kontrol hatası: $e');
      }
    }

    try {
      final result = await service.moderate(text, mode: mode, isNewTopic: isNewTopic);

      if (result.isInappropriate) {
        if (mode == ModerationMode.name) {
          if (context.mounted) {
            await _showNameRejectDialog(context);
          }
          return false;
        }
        if (userId != null && context.mounted) {
          await _handleInappropriateContentAction(context, userId);
        }
        return false;
      }

      if (result.isOffTopic) {
        bool continuePosting = false;
        if (context.mounted) {
          continuePosting = await _showOffTopicDialog(context);
        }
        if (continuePosting) {
          onOffTopicApproved?.call();
          return true;
        }
        return false;
      }

      return true;
    } catch (e) {
      return true;
    }
  }

  static Future<bool> checkImage(BuildContext context, ModerationService service, Uint8List imageBytes, String mimeType) async {
    try {
      final result = await service.moderateImage(imageBytes, mimeType);

      if (!result.isApproved) {
        if (context.mounted) {
          await _showImageRejectDialog(context, result.reason);
        }
        return false;
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  static Future<void> _handleInappropriateContentAction(BuildContext context, String userId) async {
    final client = Supabase.instance.client;
    try {
      final profile = await client.from('profiles').select().eq('id', userId).maybeSingle();
      if (profile == null) return;

      int currentStrikes = (profile['moderation_strike_count'] ?? 0) + 1;
      int todayBlocks = profile['moderation_block_count_today'] ?? 0;
      DateTime? lastBlockedAt = profile['last_blocked_at'] != null ? DateTime.parse(profile['last_blocked_at']) : null;

      if (lastBlockedAt != null) {
        final now = DateTime.now();
        if (lastBlockedAt.year != now.year || lastBlockedAt.month != now.month || lastBlockedAt.day != now.day) {
          todayBlocks = 0;
        }
      }

      if (currentStrikes >= 5) {
        int newBlockCount = todayBlocks + 1;
        if (newBlockCount >= 3) {
          await client.from('profiles').update({
            'moderation_strike_count': 0,
            'moderation_block_count_today': newBlockCount,
            'is_indefinite_blocked': true,
            'last_blocked_at': DateTime.now().toIso8601String(),
          }).eq('id', userId);

          if (context.mounted) {
            await _showAppealDialog(context, userId);
          }
        } else {
          await client.from('profiles').update({
            'moderation_strike_count': 0,
            'moderation_block_count_today': newBlockCount,
            'temp_blocked_until': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
            'last_blocked_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', userId);


          if (context.mounted) {
            await _showInfoDialog(context, 'Geçici Engelleme', 'Birden fazla topluluk kurallarına uygun yazılara uymadığınız için 5 dakikalığına bloklandınız.');
          }
        }
      } else {
        await client.from('profiles').update({
          'moderation_strike_count': currentStrikes,
        }).eq('id', userId);

        if (context.mounted) {
          await _showRejectDialog(context, 'Hakaret ve aşağılayıcı sözler tespit ettim. Lütfen Topluluk kurallarına uygun şekilde yazınız.');
        }
      }
    } catch (e) {
      debugPrint('Error updating moderation strike counts: $e');
    }
  }

  static Future<T?> _showModernDialog<T>({
    required BuildContext context,
    required Widget icon,
    required String title,
    required String message,
    Widget? extraContent,
    required Widget actions,
    bool barrierDismissible = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 12,
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  if (extraContent != null) ...[
                    const SizedBox(height: 16),
                    extraContent,
                  ],
                  const SizedBox(height: 24),
                  actions,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<bool> _showOffTopicDialog(BuildContext context) async {
    final res = await _showModernDialog<bool>(
      context: context,
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 32),
      ),
      title: 'Konu Dışı İçerik Tespiti',
      message: 'Açmış olduğunuz yeni içerik maliye, muhasebe vb. konularının dışında. Yine de devam etmek istiyor musunuz?',
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: const Text('Düzenle', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Devam Et', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  static Future<void> _showRejectDialog(BuildContext context, String? reason) async {
    await _showModernDialog(
      context: context,
      barrierDismissible: true,
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
      ),
      title: 'moderation_rejected_title'.tr(),
      message: reason ?? 'moderation_rejected_msg'.tr(),
      actions: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Düzelt', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  static Future<void> _showImageRejectDialog(BuildContext context, String? reason) async {
    await _showModernDialog(
      context: context,
      barrierDismissible: true,
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.photo_camera_front_outlined, color: Colors.blue, size: 32),
      ),
      title: 'Profil Resmi Uygun Değil',
      message: 'Lütfen yüzünüzü net gösterecek uygun bir profil resmi yükleyin.',
      actions: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Düzelt', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  static Future<void> _showNameRejectDialog(BuildContext context) async {
    await _showModernDialog(
      context: context,
      barrierDismissible: true,
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.badge_outlined, color: Colors.orange, size: 32),
      ),
      title: 'Geçersiz İsim / Unvan',
      message: 'Lütfen rakam veya geçersiz özel karakter içermeyen, gerçek adınızı ve unvanınızı giriniz.',
      actions: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Düzelt', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  static Future<void> _showInfoDialog(BuildContext context, String title, String message) async {
    await _showModernDialog(
      context: context,
      barrierDismissible: true,
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_outline_rounded, color: Colors.red, size: 32),
      ),
      title: title,
      message: message,
      actions: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  static Future<void> _showAppealDialog(BuildContext context, String userId) async {
    final client = Supabase.instance.client;
    final explanationController = TextEditingController();

    await _showModernDialog(
      context: context,
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.gavel_rounded, color: Colors.red, size: 32),
      ),
      title: 'Hesabınız Süresiz Bloklandı',
      message: 'Topluluk kurallarına birden fazla uymadığınız tespit edildiği için süresiz bloklandınız.',
      extraContent: Column(
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: explanationController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Açıklama (İtiraz gerekçeniz)',
              labelStyle: const TextStyle(fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1565C0)),
              ),
            ),
          ),
        ],
      ),
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: const Text('Vazgeç', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                if (explanationController.text.trim().isNotEmpty) {
                  await client.from('profiles').update({
                    'appeal_explanation': explanationController.text.trim(),
                    'is_appeal_pending': true,
                  }).eq('id', userId);
                  if (context.mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Değerlendirmeniz admin tarafından inceleniyor.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Gönder', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
