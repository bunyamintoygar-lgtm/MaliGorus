import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../data/models/market_product_model.dart';
import '../home/home_provider.dart';
import 'market_provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class MarketDetailScreen extends ConsumerWidget {
  final MarketProductModel product;

  const MarketDetailScreen({super.key, required this.product});

  // Premium Vibrant Purple Accent Theme Color
  static const Color premiumPurple = Color(0xFF5E2BFF);
  static const Color premiumIndigo = Color(0xFF8B5CF6);
  static const Color textCharcoal = Color(0xFF1E1B4B);
  static const Color textSlate = Color(0xFF475569);
  static const Color borderGrey = Color(0xFFEEEEEE);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(homeProvider).value?.profile;
    final balance = profile?.creditBalance ?? 0;
    final isSaved = ref.watch(marketSavedProvider.notifier).isSaved(product.id);
    final isDocument = product.type == MarketProductType.document;
    
    // Dynamic values matching the mockup for the main product, or fallback defaults for other products
    final isVip2 = product.id == 'vip-2';
    final badgeText = isDocument ? 'POPÜLER' : (isVip2 ? 'POPÜLER' : (product.metadata['badge'] ?? 'PREMIUM'));
    
    // Grid metadata values based on type
    final durationText = isVip2
        ? '5-7 İş Günü'
        : (product.metadata['duration'] ?? product.metadata['validity'] ?? '3-5 İş Günü');
    final supportText = isVip2
        ? 'Var'
        : (product.metadata['provider'] ?? (isDocument ? 'Yok' : 'Var'));
    final reportingText = isVip2
        ? 'Detaylı Rapor'
        : (product.metadata['sessions'] ?? (isDocument ? 'Kullanım Kılavuzu' : 'Detaylı Rapor'));
    final privacyText = '%100 Güvenli';

    // Detailed service description checklist
    List<String> featuresList;
    if (isDocument) {
      featuresList = [
        'Kolayca doldurulabilir, rehber niteliğinde açıklamalı alanlar',
        'Türk Ticaret Kanunu (TTK) hükümlerine %100 uyumluluk garantisi',
        'Kendi logonuzu ve özel maddelerinizi ekleme esnekliği',
        'Hem Word (.docx) hem de PDF formatında tek tıkla indirme',
        'Ömür boyu erişim ve yasal güncellemelerden anında faydalanma',
      ];
    } else if (isVip2) {
      featuresList = [
        'Vergi planlama ve optimizasyon',
        'Mali analiz ve risk değerlendirmesi',
        'Yasal mevzuata uygunluk kontrolü',
        'Fırsat analizi ve tasarruf önerileri',
        'Detaylı raporlama ve sunum'
      ];
    } else {
      featuresList = (product.metadata['features'] as List<dynamic>? ?? [
        'Kapsamlı rehber ve yönergeler',
        'Hızlı entegrasyon ve uyumluluk',
        'Profesyonel format ve tasarım',
        'Ömür boyu ücretsiz güncellemeler'
      ]).map((e) => e.toString()).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: textCharcoal),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Detayı Gör',
            style: TextStyle(color: textCharcoal, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                NumberFormat('#,###', 'tr_TR').format(balance),
                style: const TextStyle(color: textCharcoal, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP HEADER CARD
                _buildHeaderCard(context, ref, isSaved, badgeText),
                
                // 2. INFO ROW GRID
                isDocument
                    ? _buildDocumentInfoRow(product)
                    : _buildInfoRow(durationText, supportText, reportingText, privacyText),
                
                const SizedBox(height: 16),
                
                _buildVideoPlayerBlock(product),
                
                // 3. SERVICE DESCRIPTION
                _buildServiceDescription(featuresList, isDocument),
                
                // 4. WHO IS IT FOR
                _buildWhoIsItFor(isDocument),
                
                // 5. HOW IT WORKS
                _buildHowItWorks(isDocument),
                
                // 6. SIMILAR SERVICES
                _buildSimilarServices(context, ref, isDocument),
              ],
            ),
          ),
          // 8. STICKY BOTTOM BAR
          _buildStickyBottomBar(context, ref),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, WidgetRef ref, bool isSaved, String badgeText) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular Image/Icon Representation with Badge Overlay and Radial Gradient
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          premiumPurple.withValues(alpha: 0.15),
                          premiumIndigo.withValues(alpha: 0.05)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: premiumPurple.withValues(alpha: 0.15),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getProductIcon(),
                          color: premiumPurple,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: premiumPurple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Product details & price tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textCharcoal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.description ?? '',
                      style: const TextStyle(color: textSlate, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${NumberFormat('#,###', 'tr_TR').format(product.creditCost)} Kredi',
                          style: const TextStyle(
                            color: premiumPurple,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Direct Action Buy Button inside Card matching Mockup
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _handleQuickPurchase(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: premiumPurple,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hemen Satın Al',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.chevron_right, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Quick Info Grid for Documents & Templates (Görsel 1 spesifikasyonu)
  Widget _buildDocumentInfoRow(MarketProductModel product) {
    final fileTypeLabel = product.fileType?.toUpperCase() ?? 'Word / PDF';
    final pagesVal = product.metadata['pages'] ?? '5 Sayfa';
    final validityVal = product.metadata['validity'] ?? '2026 Güncel';
    final usageVal = product.metadata['usage'] ?? 'Sınırsız';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildInfoCard('Dosya Formatı', fileTypeLabel, Icons.description_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _buildInfoCard('Sayfa Sayısı', pagesVal, Icons.auto_stories_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _buildInfoCard('Güncellik', validityVal, Icons.verified_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _buildInfoCard('Kullanım', usageVal, Icons.all_inclusive_rounded)),
        ],
      ),
    );
  }

  // Quick Info Grid for Services / Classes (Görsel 5 spesifikasyonu)
  Widget _buildInfoRow(String duration, String support, String reporting, String privacy) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildInfoCard('Tahmini Süre', duration, Icons.access_time_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _buildInfoCard('Uzman Desteği', support, Icons.person_outline_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _buildInfoCard('Raporlama', reporting, Icons.description_outlined)),
          const SizedBox(width: 8),
          Expanded(child: _buildInfoCard('Gizlilik', privacy, Icons.verified_user_outlined)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String val, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Icon(icon, color: premiumPurple, size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            textAlign: TextAlign.center,
            style: const TextStyle(color: textCharcoal, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDescription(List<String> features, bool isDocument) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDocument ? 'Doküman Açıklaması' : 'Hizmet Açıklaması',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textCharcoal),
          ),
          const SizedBox(height: 10),
          Text(
            isDocument 
                ? 'İşletmenizin resmi kuruluş süreçlerini hızlandırmak ve yasal altyapısını eksiksiz kurmak için tasarlanmış şablonumuzu güvenle kullanabilirsiniz. Güncel mevzuata uygun olarak uzman hukukçular tarafından hazırlanmıştır.'
                : 'İşletmenizin vergi süreçlerini optimize ediyor, yasal yükümlülüklerinizi azaltmanıza yardımcı oluyoruz. Alanında uzman danışmanlarımız, işletmenize özel çözümler sunar.',
            style: const TextStyle(color: textSlate, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          ...features.map((feat) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEE8FF),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: const Icon(Icons.check, color: premiumPurple, size: 10),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feat,
                        style: const TextStyle(color: textSlate, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildWhoIsItFor(bool isDocument) {
    final documentChips = [
      {'title': "Girişimciler & Şirket Ortakları", 'icon': Icons.business_center_rounded},
      {'title': 'Hukuk Müşavirleri & Avukatlar', 'icon': Icons.gavel_rounded},
      {'title': 'Mali Müşavirler & Muhasebeciler', 'icon': Icons.analytics_rounded},
    ];

    final serviceChips = [
      {'title': "KOBİ'ler", 'icon': Icons.business_rounded},
      {'title': 'Şirket Sahipleri', 'icon': Icons.person_rounded},
      {'title': 'Mali Yöneticiler', 'icon': Icons.analytics_rounded},
    ];

    final activeChips = isDocument ? documentChips : serviceChips;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDocument ? 'Bu Doküman Kimler İçin Uygun?' : 'Bu Hizmet Kimler İçin Uygun?',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textCharcoal),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: activeChips.map((c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(c['icon'] as IconData, color: premiumPurple, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        c['title'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textCharcoal),
                      ),
                    ],
                  ),
                )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks(bool isDocument) {
    final docSteps = [
      {'num': '1', 'title': 'Satın Al', 'desc': 'Kredinizi kullanarak şablonu saniyeler içinde edinin.', 'icon': Icons.shopping_cart_outlined},
      {'num': '2', 'title': 'İndir', 'desc': 'Dosyayı Word (.docx) veya PDF formatında indirin.', 'icon': Icons.download_for_offline_outlined},
      {'num': '3', 'title': 'Düzenle', 'desc': 'Belirtilen boşlukları kendi bilgilerinizle doldurun.', 'icon': Icons.edit_note_rounded},
      {'num': '4', 'title': 'Kullan', 'desc': 'Resmi mercilerde veya ticari işlerinizde güvenle kullanın.', 'icon': Icons.task_alt_rounded},
    ];

    final serviceSteps = [
      {'num': '1', 'title': 'Satın Al', 'desc': 'Hizmeti satın alarak süreci başlatın.', 'icon': Icons.shopping_cart_outlined},
      {'num': '2', 'title': 'Bilgi Paylaşımı', 'desc': 'Gerekli bilgileri uzman ekibimize iletin.', 'icon': Icons.chat_bubble_outline_rounded},
      {'num': '3', 'title': 'Analiz & Çözüm', 'desc': 'Uzmanlarımız analiz yapar ve çözümleri hazırlar.', 'icon': Icons.search_rounded},
      {'num': '4', 'title': 'Rapor Teslimi', 'desc': 'Detaylı raporunuz size teslim edilir.', 'icon': Icons.assignment_turned_in_outlined},
    ];

    final steps = isDocument ? docSteps : serviceSteps;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nasıl Çalışır?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textCharcoal),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: steps.map((s) {
              final isLast = s['num'] == '4';
              return Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: premiumPurple.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(s['icon'] as IconData, color: premiumPurple, size: 20),
                              ),
                              Positioned(
                                top: -4,
                                left: -4,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: premiumPurple,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      s['num'] as String,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            s['title'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textCharcoal),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s['desc'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Container(
                        margin: const EdgeInsets.only(top: 24),
                        child: Text(
                          '•••',
                          style: TextStyle(color: premiumPurple.withValues(alpha: 0.3), fontSize: 8),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }



  Widget _buildSimilarServices(BuildContext context, WidgetRef ref, bool isDocument) {
    final similarAsync = ref.watch(marketProductsProvider(product.type));

    return similarAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (allProducts) {
        final similar = allProducts
            .where((p) => p.id != product.id)
            .take(3)
            .toList();

        if (similar.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isDocument ? 'Benzer Dokümanlar' : 'Benzer Hizmetler',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textCharcoal),
                  ),
                  InkWell(
                    onTap: () => context.pop(),
                    child: const Row(
                      children: [
                        Text('Tümünü Gör', style: TextStyle(color: premiumPurple, fontWeight: FontWeight.bold, fontSize: 12)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, color: premiumPurple, size: 9),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: similar.length,
                itemBuilder: (context, index) {
                  final item = similar[index];
                  return GestureDetector(
                    onTap: () {
                      context.pushReplacement('/market/detail', extra: item);
                    },
                    child: Container(
                      width: 220,
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x02000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getTypeColor(item.type).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_getTypeIcon(item.type), color: _getTypeColor(item.type), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textCharcoal),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${NumberFormat('#,###', 'tr_TR').format(item.creditCost)} Kredi',
                                  style: const TextStyle(color: premiumPurple, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStickyBottomBar(BuildContext context, WidgetRef ref) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
          border: const Border(
            top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
          ),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Toplam Tutar',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${NumberFormat('#,###', 'tr_TR').format(product.creditCost)} Kredi',
                      style: const TextStyle(color: textCharcoal, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _handleQuickPurchase(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: premiumPurple,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Hemen Satın Al',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.chevron_right, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleQuickPurchase(BuildContext context, WidgetRef ref) async {
    // Add product to cart
    await ref.read(marketCartProvider.notifier).addToCart(product);
    
    // Direct redirect to market cart screen for elegant checkout
    if (context.mounted) {
      context.push('/market/cart');
    }
  }

  IconData _getProductIcon() {
    switch (product.type) {
      case MarketProductType.document:
        return Icons.description_rounded;
      case MarketProductType.certificate:
        return Icons.workspace_premium_rounded;
      case MarketProductType.liveTraining:
        return Icons.video_camera_front_rounded;
      case MarketProductType.event:
        return Icons.event_rounded;
      case MarketProductType.vipService:
        return Icons.account_balance_rounded; // Bank/Library building mockup look
    }
  }

  Color _getTypeColor(MarketProductType type) {
    switch (type) {
      case MarketProductType.document:
        return Colors.green[600]!;
      case MarketProductType.certificate:
        return Colors.purple[600]!;
      case MarketProductType.liveTraining:
        return Colors.deepOrange[600]!;
      case MarketProductType.event:
        return Colors.blue[600]!;
      case MarketProductType.vipService:
        return premiumPurple;
    }
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
        return Icons.event_rounded;
      case MarketProductType.vipService:
        return Icons.account_balance_rounded;
    }
  }

  Widget _buildVideoPlayerBlock(MarketProductModel product) {
    final youtubeUrl = product.metadata['video_url'] ?? product.metadata['youtube_id'];
    if (youtubeUrl == null || youtubeUrl.toString().trim().isEmpty) {
      return const SizedBox.shrink();
    }
    
    final videoId = extractYoutubeId(youtubeUrl.toString());
    if (videoId == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: premiumPurple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: premiumPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Ürün Tanıtım Videosu',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textCharcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: MarketProductVideoPlayer(videoId: videoId),
          ),
        ],
      ),
    );
  }
}

// === top-level helper functions and stateful video player widget ===

String? extractYoutubeId(String url) {
  url = url.trim();
  if (url.isEmpty) return null;
  
  if (url.length == 11 && !url.contains('/') && !url.contains('?')) {
    return url;
  }
  
  final regExp = RegExp(
    r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*',
    caseSensitive: false,
    multiLine: false,
  );
  
  final match = regExp.firstMatch(url);
  if (match != null && match.groupCount >= 2) {
    final id = match.group(2);
    if (id != null && id.length == 11) {
      return id;
    }
  }
  return null;
}

class MarketProductVideoPlayer extends StatefulWidget {
  final String videoId;

  const MarketProductVideoPlayer({super.key, required this.videoId});

  @override
  State<MarketProductVideoPlayer> createState() => _MarketProductVideoPlayerState();
}

class _MarketProductVideoPlayerState extends State<MarketProductVideoPlayer> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(
      controller: _controller,
      aspectRatio: 16 / 9,
    );
  }
}
