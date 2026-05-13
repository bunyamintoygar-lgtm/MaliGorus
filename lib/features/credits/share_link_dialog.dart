import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/referral_repository.dart';

class ShareLinkDialog extends ConsumerStatefulWidget {
  const ShareLinkDialog({super.key});

  @override
  ConsumerState<ShareLinkDialog> createState() => _ShareLinkDialogState();
}

class _ShareLinkDialogState extends ConsumerState<ShareLinkDialog> {
  String? _referralCode;
  bool _loading = true;
  bool _hasReview = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = ref.read(referralRepositoryProvider);
    final code = await repo.getMyReferralCode();
    final review = await repo.getMyReview();

    if (mounted) {
      setState(() {
        _referralCode = code;
        _hasReview = review != null;
        _loading = false;
      });
    }
  }

  String get _referralLink {
    // Gerçek domain deploy edildiğinde değiştirilecek
    // Not: Buraya kendi domain adresinizi yazın
    return 'https://maligorus.com/?ref=$_referralCode';
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _referralLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link kopyalandı! 📋'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Başlık
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.actionBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.share_rounded, color: AppTheme.actionBlue, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Referans Linkiniz',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primaryNavy),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bu linki paylaşın, her yeni kayıt için\n+20 Kredi kazanın!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                  ),

                  const SizedBox(height: 24),

                  // Yorum uyarısı
                  if (!_hasReview) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Önce uygulama hakkında yorum yapın! Yorumunuz referans sayfanızda görünecek ve +5 Kredi kazanacaksınız.',
                              style: TextStyle(color: Colors.amber[800], fontSize: 12, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Link kutusu
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link, color: AppTheme.actionBlue, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _referralLink,
                            style: const TextStyle(fontSize: 13, color: AppTheme.primaryNavy, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Kopyala butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _copyLink,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.actionBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                      label: const Text('Linki Kopyala', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Kapat
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kapat', style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
      ),
    );
  }
}
