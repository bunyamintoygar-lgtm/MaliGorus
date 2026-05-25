import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/theme/app_theme.dart';
import '../../data/models/market_product_model.dart';

class MarketPurchaseSuccessScreen extends StatelessWidget {
  final List<MarketProductModel> purchasedItems;

  const MarketPurchaseSuccessScreen({
    super.key,
    required this.purchasedItems,
  });

  @override
  Widget build(BuildContext context) {
    final double totalCredits = purchasedItems.fold(0.0, (sum, item) => sum + item.creditCost);
    final String formattedDate = DateFormat('dd MMMM yyyy • HH:mm', 'tr_TR').format(DateTime.now());
    
    // Check if there are downloadables
    final documents = purchasedItems.where((i) => i.type == MarketProductType.document).toList();
    final firstItem = purchasedItems.isNotEmpty ? purchasedItems.first : null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.primaryNavy),
          onPressed: () => context.go('/market'),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Success Header Icon & Animation space
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981).withOpacity(0.08),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981).withOpacity(0.15),
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Satın Alım Başarılı!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.primaryNavy,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                purchasedItems.length == 1
                    ? '${firstItem?.title} adlı ürünü başarıyla satın aldınız. İçeriğe hemen erişebilir, indirebilir ve kullanmaya başlayabilirsiniz.'
                    : 'Seçtiğiniz ${purchasedItems.length} adet ürünü başarıyla satın aldınız. İçeriklerinize hemen erişebilir, indirebilir ve kullanmaya başlayabilirsiniz.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Purchased Items List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: purchasedItems.length,
                itemBuilder: (context, index) {
                  final item = purchasedItems[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _getTypeBgColor(item.type),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getTypeIcon(item.type),
                            color: _getTypeColor(item.type),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _getCategoryLabel(item.type),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.creditCost} Kredi',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Sipariş Özeti
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          color: AppTheme.primaryNavy,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Sipariş Özeti',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSummaryRow(
                      'Ürün',
                      purchasedItems.length == 1
                          ? firstItem?.title ?? ''
                          : '${purchasedItems.length} Adet Ürün',
                      isBold: true,
                    ),
                    const Divider(height: 18, color: Color(0xFFE2E8F0)),
                    _buildSummaryRow(
                      'Tutar',
                      '${totalCredits.toInt()} Kredi',
                      textColor: const Color(0xFF6366F1),
                    ),
                    const Divider(height: 18, color: Color(0xFFE2E8F0)),
                    _buildSummaryRow('Tarih', formattedDate),
                    const Divider(height: 18, color: Color(0xFFE2E8F0)),
                    _buildSummaryRow('Ödeme Yöntemi', 'Kredi Bakiyesi'),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Şimdi Ne Yapabilirsiniz?
              const Text(
                'Şimdi Ne Yapabilirsiniz?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 12),

              // Şablonu İndir
              if (documents.isNotEmpty)
                _buildActionTile(
                  icon: Icons.file_download_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  bgColor: const Color(0xFFF5F3FF),
                  title: 'Şablonu İndir',
                  subtitle: 'Şablonu hemen cihazınıza indirin ve kullanmaya başlayın.',
                  onTap: () {
                    if (firstItem != null) {
                      _simulateFileDownload(context, firstItem);
                    }
                  },
                ),
              
              // Şablonu Önizle
              if (firstItem != null)
                _buildActionTile(
                  icon: Icons.visibility_rounded,
                  iconColor: const Color(0xFF06B6D4),
                  bgColor: const Color(0xFFECFEFF),
                  title: 'Şablonu Önizle',
                  subtitle: 'Şablonu önizleyerek içeriğini inceleyin.',
                  onTap: () => context.push('/market/detail', extra: firstItem),
                ),

              // Dokümanlarım'da Görüntüle
              _buildActionTile(
                icon: Icons.folder_rounded,
                iconColor: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                title: 'Dokümanlarım\'da Görüntüle',
                subtitle: 'Tüm şablonlarınızı Dokümanlarım sayfasında yönetin.',
                onTap: () => context.go('/market/documents'),
              ),
              const SizedBox(height: 16),

              // Tüm Şablonları Keşfet Promotion Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withOpacity(0.06),
                      const Color(0xFF6366F1).withOpacity(0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E7FF)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFF8B5CF6),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Şablonları Daha Verimli Kullanın',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hazır şablonlarımızla iş süreçlerinizi hızlandırın, profesyonelliğinizi artırın.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => context.go('/market'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B5CF6),
                        side: const BorderSide(color: Color(0xFF8B5CF6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      child: const Text(
                        'Keşfet',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Bottom Actions
              ElevatedButton(
                onPressed: () => context.go('/market'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Alışverişe Devam Et',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/market'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Ana Sayfaya Dön',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Footer Secure Checkout Note
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    'Güvenli alışveriş yaptığınız için teşekkür ederiz.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? textColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isBold || textColor != null ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
              color: textColor ?? AppTheme.primaryNavy,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppTheme.primaryNavy,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 12,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Color _getTypeColor(MarketProductType type) {
    switch (type) {
      case MarketProductType.document:
        return const Color(0xFF2563EB);
      case MarketProductType.certificate:
        return const Color(0xFF7C3AED);
      case MarketProductType.liveTraining:
        return const Color(0xFFEA580C);
      case MarketProductType.event:
        return const Color(0xFF0284C7);
      case MarketProductType.vipService:
        return const Color(0xFFD97706);
    }
  }

  Color _getTypeBgColor(MarketProductType type) {
    return _getTypeColor(type).withOpacity(0.08);
  }

  IconData _getTypeIcon(MarketProductType type) {
    switch (type) {
      case MarketProductType.document:
        return Icons.description_rounded;
      case MarketProductType.certificate:
        return Icons.workspace_premium_rounded;
      case MarketProductType.liveTraining:
        return Icons.video_camera_front_rounded;
      case MarketProductType.event:
        return Icons.event_available_rounded;
      case MarketProductType.vipService:
        return Icons.stars_rounded;
    }
  }

  String _getCategoryLabel(MarketProductType type) {
    switch (type) {
      case MarketProductType.document:
        return 'Doküman & Şablonlar';
      case MarketProductType.certificate:
        return 'Sertifika & Eğitim';
      case MarketProductType.liveTraining:
        return 'Canlı Eğitim';
      case MarketProductType.event:
        return 'Etkinlik';
      case MarketProductType.vipService:
        return 'Premium Hizmet';
    }
  }

  Future<void> _simulateFileDownload(BuildContext context, MarketProductModel document) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/${document.title.replaceAll(' ', '_')}.${document.fileType}';
      final file = File(path);
      await file.writeAsString('MaliGörüş Professional Template: ${document.title}');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${document.title} başarıyla indirildi: ${file.path}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dosya indirme hatası: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
