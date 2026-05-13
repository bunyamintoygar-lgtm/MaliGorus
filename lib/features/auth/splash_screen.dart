import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _updateUrl;

  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  bool _isVersionOutdated(String currentVersion, String minVersion) {
    try {
      final cParts = currentVersion.split('+');
      final mParts = minVersion.split('+');
      
      final cName = cParts[0].split('.');
      final mName = mParts[0].split('.');
      
      for (int i = 0; i < 3; i++) {
        final cNum = i < cName.length ? int.tryParse(cName[i]) ?? 0 : 0;
        final mNum = i < mName.length ? int.tryParse(mName[i]) ?? 0 : 0;
        if (cNum < mNum) return true;
        if (cNum > mNum) return false;
      }
      
      if (cParts.length > 1 && mParts.length > 1) {
        final cBuild = int.tryParse(cParts[1]) ?? 0;
        final mBuild = int.tryParse(mParts[1]) ?? 0;
        return cBuild < mBuild;
      }
    } catch (e) {
      debugPrint('Versiyon karşılaştırma hatası: $e');
    }
    return false;
  }

  void _showForceUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: AppTheme.primaryNavy),
              SizedBox(width: 12),
              Text('Güncelleme Gerekli', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Uygulamanızın daha güncel ve güvenli bir sürümü mevcut. Devam edebilmek için lütfen uygulamanızı en son sürüme güncelleyin.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (_updateUrl != null && _updateUrl!.isNotEmpty) {
                  final uri = Uri.tryParse(_updateUrl!);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToNext() async {
    // --- FORCE UPDATE KONTROLÜ ---
    bool isOutdated = false;
    try {
      final List<dynamic> response = await Supabase.instance.client
          .from('app_config')
          .select('key, value')
          .inFilter('key', ['min_app_version', 'update_url']);

      String? minVersion;
      for (var row in response) {
        if (row['key'] == 'min_app_version') minVersion = row['value']?.toString();
        if (row['key'] == 'update_url') _updateUrl = row['value']?.toString();
      }

      if (minVersion != null) {
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

        isOutdated = _isVersionOutdated(currentVersion, minVersion);
      }
    } catch (e) {
      debugPrint('Versiyon kontrolü hatası: $e');
    }

    if (isOutdated && mounted) {
      _showForceUpdateDialog(context);
      return; // İşlemleri durdur
    }
    // ----------------------------

    // Referans Kontrolü (Parmak İzi Eşleştirme)
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      try {
        final List<dynamic> response = await Supabase.instance.client.rpc('match_referral_click');
        if (response.isNotEmpty) {
          final caughtRefCode = response[0]['ref_code'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_referral_code', caughtRefCode);
          debugPrint('Referans yakalandı ve kaydedildi: $caughtRefCode');
        }
      } catch (e) {
        debugPrint('Referans hatası: $e');
      }
    }

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryNavy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.analytics_rounded,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'app_name'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'app_slogan'.tr(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
