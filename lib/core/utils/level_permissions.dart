import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/level_model.dart';

enum AppPermission {
  createDiscussion,
  sendDirectMessage,
  replyToConsultation,
  shopMarket,
  giftCredits,
  createSurvey,
  createListing,
  applyToListing,
}

class LevelPermissions {
  static bool hasPermission(String? levelKey, AppPermission permission, List<LevelModel> levels) {
    if (levelKey == null || levels.isEmpty) return false;
    
    // Güvenlik için listeyi kredi eşiğine göre sırala (Hiyerarşi garantisi)
    final sortedLevels = List<LevelModel>.from(levels)
      ..sort((a, b) => a.minCredits.compareTo(b.minCredits));
    
    // Kullanıcının seviye index'ini sıralı listede bul (Esnek eşleşme ile)
    final userIndex = sortedLevels.indexWhere((l) => l.key.toLowerCase() == levelKey.toLowerCase());
    
    if (userIndex == -1) return false;

    // Gerekli olan minimum seviyenin index'ini belirle
    int requiredIndex = 0;
    switch (permission) {
      case AppPermission.createDiscussion:
      case AppPermission.sendDirectMessage:
      case AppPermission.applyToListing:
        requiredIndex = 1; // Gümüş ve üzeri (Index 1)
        break;
      case AppPermission.replyToConsultation:
      case AppPermission.createSurvey:
      case AppPermission.createListing:
        requiredIndex = 2; // Altın ve üzeri (Index 2)
        break;
      case AppPermission.shopMarket:
      case AppPermission.giftCredits:
        requiredIndex = 3; // Platin ve üzeri (Index 3)
        break;
      default:
        return true;
    }

    return userIndex >= requiredIndex;
  }

  static String getRequiredLevel(AppPermission permission) {
    switch (permission) {
      case AppPermission.createDiscussion:
      case AppPermission.sendDirectMessage:
        return 'silver';
      case AppPermission.replyToConsultation:
        return 'gold';
      case AppPermission.shopMarket:
      case AppPermission.giftCredits:
        return 'platinum';
      case AppPermission.createSurvey:
      case AppPermission.createListing:
        return 'gold';
      case AppPermission.applyToListing:
        return 'silver';
    }
  }

  static String getLevelName(String key) {
    switch (key.toLowerCase()) {
      case 'bronze': return 'Bronz Üye';
      case 'silver': return 'Gümüş Üye';
      case 'gold': return 'Altın Üye';
      case 'platinum': return 'Platin Üye';
      default: return 'Üye';
    }
  }

  static void showAccessDeniedDialog(BuildContext context, AppPermission permission) {
    final requiredLevel = getRequiredLevel(permission);
    final levelName = getLevelName(requiredLevel);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.orange),
            const SizedBox(width: 12),
            const Text('Yetki Gerekli'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu özelliği kullanabilmek için en az $levelName seviyesinde olmalısınız.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            const Text(
              'Daha fazla tartışmaya katılarak ve anket doldurarak kredi kazanabilir, seviyenizi yükseltebilirsiniz!',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anladım'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/credit-earn');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Kredi Kazan'),
          ),
        ],
      ),
    );
  }

  static void showInsufficientCreditDialog(BuildContext context, {int? requiredCredits}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.stars_rounded, color: AppTheme.creditGold),
            const SizedBox(width: 12),
            const Text('Yetersiz Kredi'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              requiredCredits != null 
                ? 'Bu işlem için $requiredCredits kredi gereklidir. Mevcut bakiyeniz yetersiz.'
                : 'Bu işlem için yeterli krediniz bulunmuyor.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hemen kredi kazanmak için aşağıdaki butona tıklayabilirsiniz!',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anladım'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/credit-earn');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Kredi Kazan'),
          ),
        ],
      ),
    );
  }
}
