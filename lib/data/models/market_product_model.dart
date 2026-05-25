enum MarketProductType {
  document,
  certificate,
  liveTraining,
  event,
  vipService;

  String toJson() {
    switch (this) {
      case MarketProductType.document: return 'document';
      case MarketProductType.certificate: return 'certificate';
      case MarketProductType.liveTraining: return 'live_training';
      case MarketProductType.event: return 'event';
      case MarketProductType.vipService: return 'vip_service';
    }
  }
  
  static MarketProductType fromJson(String value) {
    switch (value) {
      case 'document': return MarketProductType.document;
      case 'certificate': return MarketProductType.certificate;
      case 'live_training':
      case 'liveTraining':
        return MarketProductType.liveTraining;
      case 'event': return MarketProductType.event;
      case 'vip_service':
      case 'vipService':
        return MarketProductType.vipService;
      default: return MarketProductType.document;
    }
  }
}

class MarketProductModel {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final int creditCost;
  final int stock;
  final bool isActive;
  final MarketProductType type;
  final String category; // 'İş & Yönetim', 'Finans', 'Teknoloji', 'Pazarlama', 'Hukuk', 'Kişisel Gelişim'
  final String? fileUrl; // For downloadable templates
  final String? fileType; // 'docx', 'xlsx', 'pdf', 'pptx'
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  MarketProductModel({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    required this.creditCost,
    required this.stock,
    this.isActive = true,
    required this.type,
    required this.category,
    this.fileUrl,
    this.fileType,
    required this.metadata,
    required this.createdAt,
  });

  // Helper getters for metadata values
  String get duration => metadata['duration'] ?? '';
  int get lecturesCount => metadata['lectures_count'] ?? 0;
  String get level => metadata['level'] ?? '';
  String get dateTime => metadata['date_time'] ?? '';
  String get trainerName => metadata['trainer_name'] ?? '';
  String get trainerTitle => metadata['trainer_title'] ?? '';
  String get trainerAvatar => metadata['trainer_avatar'] ?? '';
  String get location => metadata['location'] ?? '';
  bool get isLive => metadata['is_live'] ?? false;
  String get zoomLink => metadata['zoom_link'] ?? '';
  bool get certificateIssued => metadata['certificate_issued'] ?? false;

  factory MarketProductModel.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'] ?? {};
    return MarketProductModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      imageUrl: json['image_url'],
      creditCost: json['credit_cost'] ?? 0,
      stock: json['stock'] ?? 0,
      isActive: json['is_active'] ?? true,
      type: MarketProductType.fromJson(json['type'] ?? 'document'),
      category: json['category'] ?? 'Tümü',
      fileUrl: json['file_url'] ?? meta['file_url'],
      fileType: json['file_type'] ?? meta['file_type'],
      metadata: Map<String, dynamic>.from(meta),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final updatedMetadata = Map<String, dynamic>.from(metadata);
    if (fileType != null) {
      updatedMetadata['file_type'] = fileType;
    }
    if (fileUrl != null) {
      updatedMetadata['file_url'] = fileUrl;
    }
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'credit_cost': creditCost,
      'stock': stock,
      'is_active': isActive,
      'type': type.toJson(),
      'category': category,
      'metadata': updatedMetadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Generates lifelike dummy products to render identical views as requested in the Mockups
  static List<MarketProductModel> generateDummyProducts() {
    return [
      // === DOCUMENTS (Görsel 1) ===
      MarketProductModel(
        id: 'd0c11111-1111-1111-1111-111111111111',
        title: 'İş Planı Şablonu',
        description: 'Yatırımcı sunumları için kapsamlı ve profesyonel iş planı şablonu.',
        creditCost: 1250,
        stock: 999,
        type: MarketProductType.document,
        category: 'İş & Yönetim',
        fileType: 'docx',
        metadata: {
          'added_days_ago': 2,
          'video_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        },
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      MarketProductModel(
        id: 'd0c22222-2222-2222-2222-222222222222',
        title: 'Bütçe Planlama Tablosu',
        description: 'Gelir-gider takibi ve bütçe planlaması için detaylı Excel şablonu.',
        creditCost: 950,
        stock: 999,
        type: MarketProductType.document,
        category: 'Finans',
        fileType: 'xlsx',
        metadata: {
          'added_days_ago': 3,
        },
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      MarketProductModel(
        id: 'd0c33333-3333-3333-3333-333333333333',
        title: 'Sözleşme Şablonları Paketi',
        description: 'İş ortaklıkları ve hizmet alımları için 10+ farklı sözleşme şablonu.',
        creditCost: 1800,
        stock: 999,
        type: MarketProductType.document,
        category: 'Hukuk',
        fileType: 'pdf',
        metadata: {
          'added_days_ago': 4,
        },
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      MarketProductModel(
        id: 'd0c44444-4444-4444-4444-444444444444',
        title: 'Pazarlama Planı Şablonu',
        description: 'Stratejik pazarlama planı hazırlama ve bütçelendirme rehberi.',
        creditCost: 1100,
        stock: 999,
        type: MarketProductType.document,
        category: 'Pazarlama',
        fileType: 'pptx',
        metadata: {
          'added_days_ago': 5,
        },
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      MarketProductModel(
        id: 'd0c55555-5555-5555-5555-555555555555',
        title: 'Toplantı Notu Şablonu',
        description: 'Ekipler arası verimli toplantı tutanakları tutmak için Word belgesi.',
        creditCost: 450,
        stock: 999,
        type: MarketProductType.document,
        category: 'İş & Yönetim',
        fileType: 'docx',
        metadata: {
          'added_days_ago': 2,
        },
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      MarketProductModel(
        id: 'd0c66666-6666-6666-6666-666666666666',
        title: 'Nakit Akış Tablosu',
        description: 'Aylık ve yıllık nakit akışını takip edebileceğiniz otomatik Excel tablosu.',
        creditCost: 650,
        stock: 999,
        type: MarketProductType.document,
        category: 'Finans',
        fileType: 'xlsx',
        metadata: {
          'added_days_ago': 3,
        },
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      MarketProductModel(
        id: 'd0c77777-7777-7777-7777-777777777777',
        title: 'Gizlilik Sözleşmesi (NDA)',
        description: 'Bilgi güvenliğini koruma amaçlı profesyonel gizlilik sözleşmesi şablonu.',
        creditCost: 900,
        stock: 999,
        type: MarketProductType.document,
        category: 'Hukuk',
        fileType: 'pdf',
        metadata: {
          'added_days_ago': 4,
        },
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      MarketProductModel(
        id: 'd0c88888-8888-8888-8888-888888888888',
        title: 'Yıllık Performans Raporu Şablonu',
        description: 'Şirket içi çalışan performansını değerlendirmek için PowerPoint şablonu.',
        creditCost: 700,
        stock: 999,
        type: MarketProductType.document,
        category: 'İş & Yönetim',
        fileType: 'pptx',
        metadata: {
          'added_days_ago': 5,
        },
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),

      // === CERTIFICATES (Görsel 2) ===
      MarketProductModel(
        id: 'c1e11111-1111-1111-1111-111111111111',
        title: 'Dijital Pazarlama Sertifika Programı',
        description: 'Dijital pazarlama stratejileri, SEO, Google Ads, sosyal medya ve içerik pazarlaması.',
        imageUrl: 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=400&q=80',
        creditCost: 12000,
        stock: 50,
        type: MarketProductType.certificate,
        category: 'Pazarlama',
        metadata: {
          'duration': '8 Hafta',
          'lectures_count': 48,
          'level': 'Orta Seviye',
          'badge': 'POPÜLER',
        },
        createdAt: DateTime.now(),
      ),
      MarketProductModel(
        id: 'c1e22222-2222-2222-2222-222222222222',
        title: 'Finansal Analiz Sertifika Programı',
        description: 'Finansal tablo analizi, oran analizi, değerleme yöntemleri ve yatırım analizi.',
        imageUrl: 'https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=400&q=80',
        creditCost: 11000,
        stock: 40,
        type: MarketProductType.certificate,
        category: 'Finans',
        metadata: {
          'duration': '6 Hafta',
          'lectures_count': 36,
          'level': 'Orta Seviye',
          'badge': 'POPÜLER',
        },
        createdAt: DateTime.now(),
      ),
      MarketProductModel(
        id: 'c1e33333-3333-3333-3333-333333333333',
        title: 'Python ile Veri Analizi Sertifika Programı',
        description: 'Python ile veri analizi, veri görselleştirme ve makine öğrenmesine giriş.',
        imageUrl: 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=400&q=80',
        creditCost: 13500,
        stock: 30,
        type: MarketProductType.certificate,
        category: 'Teknoloji',
        metadata: {
          'duration': '7 Hafta',
          'lectures_count': 42,
          'level': 'Orta - İleri Seviye',
          'badge': 'YENİ',
        },
        createdAt: DateTime.now(),
      ),
      MarketProductModel(
        id: 'c1e44444-4444-4444-4444-444444444444',
        title: 'İnsan Kaynakları Yönetimi Sertifika Programı',
        description: 'İK stratejileri, işe alım süreçleri, performans yönetimi ve iş hukuku.',
        imageUrl: 'https://images.unsplash.com/photo-1573497019940-1c28c88b4f3e?w=400&q=80',
        creditCost: 9000,
        stock: 60,
        type: MarketProductType.certificate,
        category: 'İş & Yönetim',
        metadata: {
          'duration': '5 Hafta',
          'lectures_count': 30,
          'level': 'Başlangıç',
          'badge': 'POPÜLER',
        },
        createdAt: DateTime.now(),
      ),
      MarketProductModel(
        id: 'c1e55555-5555-5555-5555-555555555555',
        title: 'Excel İleri Düzey Sertifika Programı',
        description: 'Excel\'de ileri formüller, pivot tablolar, dashboard ve VBA ile otomasyon.',
        imageUrl: 'https://images.unsplash.com/photo-1531403009284-440f080d1e12?w=400&q=80',
        creditCost: 8000,
        stock: 100,
        type: MarketProductType.certificate,
        category: 'Teknoloji',
        metadata: {
          'duration': '4 Hafta',
          'lectures_count': 24,
          'level': 'Orta Seviye',
          'badge': 'ÇOK SATAN',
        },
        createdAt: DateTime.now(),
      ),

      // === LIVE TRAININGS (Görsel 3) ===
      MarketProductModel(
        id: '111e1111-1111-1111-1111-111111111111',
        title: 'Finansal Analiz Uzmanlığı',
        description: 'Bilanço, gelir tablosu ve nakit akışı analizi canlı atölyesi.',
        imageUrl: 'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?w=400&q=80',
        creditCost: 3750,
        stock: 20,
        type: MarketProductType.liveTraining,
        category: 'Finans',
        metadata: {
          'date_time': 'Bugün 14:00',
          'trainer_name': 'Mehmet Yılmaz',
          'trainer_title': 'Finans Uzmanı',
          'trainer_avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&q=80',
          'duration': '2s 30dk',
          'zoom_link': 'https://zoom.us/j/test-meeting-1',
          'is_live': true,
          'video_url': 'https://www.youtube.com/watch?v=KGD-T3bhFEA',
        },
        createdAt: DateTime.now(),
      ),
      MarketProductModel(
        id: '111e2222-2222-2222-2222-222222222222',
        title: 'Dijital Pazarlama Stratejileri',
        description: 'SEO, Google Ads ve sosyal medya stratejileri.',
        imageUrl: 'https://images.unsplash.com/photo-1432888498266-38ffec3eaf0a?w=400&q=80',
        creditCost: 2800,
        stock: 25,
        type: MarketProductType.liveTraining,
        category: 'Pazarlama',
        metadata: {
          'date_time': 'Yarın 11:00',
          'trainer_name': 'Ayşe Demir',
          'trainer_title': 'Dijital Pazarlama Uzmanı',
          'trainer_avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&q=80',
          'duration': '1s 45dk',
          'zoom_link': 'https://zoom.us/j/test-meeting-2',
          'is_live': true,
        },
        createdAt: DateTime.now(),
      ),
      MarketProductModel(
        id: '111e3333-3333-3333-3333-333333333333',
        title: 'Excel İleri Seviye – Dashboard',
        description: 'Dinamik dashboardlar ve veri görselleştirme yöntemleri.',
        imageUrl: 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=400&q=80',
        creditCost: 2500,
        stock: 35,
        type: MarketProductType.liveTraining,
        category: 'Teknoloji',
        metadata: {
          'date_time': '24 Mayıs Cuma 15:00',
          'trainer_name': 'Kerem Arslan',
          'trainer_title': 'Excel Eğitmeni',
          'trainer_avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&q=80',
          'duration': '2s 15dk',
          'zoom_link': 'https://zoom.us/j/test-meeting-3',
          'is_live': false,
        },
        createdAt: DateTime.now(),
      ),
      MarketProductModel(
        id: '111e4444-4444-4444-4444-444444444444',
        title: 'Liderlik ve Ekip Yönetimi',
        description: 'Etkili liderlik becerileri ve ekip motivasyonu teknikleri.',
        imageUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400&q=80',
        creditCost: 2200,
        stock: 30,
        type: MarketProductType.liveTraining,
        category: 'İş & Yönetim',
        metadata: {
          'date_time': '25 Mayıs Cmt 10:30',
          'trainer_name': 'Zeynep Kaya',
          'trainer_title': 'İK ve Liderlik Danışmanı',
          'trainer_avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80',
          'duration': '1s 30dk',
          'zoom_link': 'https://zoom.us/j/test-meeting-4',
          'is_live': false,
        },
        createdAt: DateTime.now(),
      ),

      // === EVENTS (Görsel 4) ===
      MarketProductModel(
        id: 'e0e11111-1111-1111-1111-111111111111',
        title: 'Ekonomide Güncel Gelişmeler ve Piyasalar',
        description: 'Küresel ve yerel ekonomik gelişmelerin piyasalara yansıması semineri.',
        imageUrl: 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=400&q=80',
        creditCost: 0, // Ücretsiz
        stock: 100,
        type: MarketProductType.event,
        category: 'Finans',
        metadata: {
          'date_time': '24 MAY | 19:00 - 20:30',
          'day': '24',
          'month': 'MAY',
          'location': 'Online',
          'duration': '1s 30dk',
          'event_type': 'WEBINAR',
          'trainer_name': 'Dr. Ali Yılmaz',
          'trainer_title': 'Ekonomist',
          'trainer_avatar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&q=80',
        },
        createdAt: DateTime.now(),
      ),
      MarketProductModel(
        id: 'e0e22222-2222-2222-2222-222222222222',
        title: 'Etkili Sunum Teknikleri Atölyesi',
        description: 'Topluluk önünde konuşma ve etkileyici sunum hazırlama yöntemleri.',
        imageUrl: 'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?w=400&q=80',
        creditCost: 1250,
        stock: 15,
        type: MarketProductType.event,
        category: 'Kişisel Gelişim',
        metadata: {
          'date_time': '28 MAY | 14:00 - 17:00',
          'day': '28',
          'month': 'MAY',
          'location': 'İstanbul',
          'duration': '3 Saat',
          'event_type': 'ATÖLYE',
          'trainer_name': 'Zeynep Kaya',
          'trainer_title': 'Eğitmen & Koç',
          'trainer_avatar': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100&q=80',
        },
        createdAt: DateTime.now(),
      ),
      MarketProductModel(
        id: 'e0e33333-3333-3333-3333-333333333333',
        title: 'Yapay Zeka ile Geleceği Şekillendirmek',
        description: 'Üretken yapay zekanın iş dünyasına entegrasyonu paneli.',
        imageUrl: 'https://images.unsplash.com/photo-1677442136019-21780efad99a?w=400&q=80',
        creditCost: 750,
        stock: 200,
        type: MarketProductType.event,
        category: 'Teknoloji',
        metadata: {
          'date_time': '31 MAY | 19:00 - 21:00',
          'day': '31',
          'month': 'MAY',
          'location': 'Online',
          'duration': '2 Saat',
          'event_type': 'SEMİNER',
          'trainer_name': 'Mehmet Demir',
          'trainer_title': 'Yapay Zeka Uzmanı',
          'trainer_avatar': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&q=80',
        },
        createdAt: DateTime.now(),
      ),

      // === VIP SERVICES (Görsel 5) ===
      MarketProductModel(
        id: 'd1a11111-1111-1111-1111-111111111111',
        title: 'VIP Yıllık Danışmanlık Paketi',
        description: 'Finansal planlama desteği, özel uzman desteği, kişisel danışman ataması ve aylık strateji toplantıları içeren en kapsamlı paket.',
        imageUrl: 'https://images.unsplash.com/photo-1521791136064-7986c2920216?w=400&q=80',
        creditCost: 10000,
        stock: 10,
        type: MarketProductType.vipService,
        category: 'Danışmanlık',
        metadata: {
          'features': [
            'Yıllık limitsiz danışmanlık',
            'Öncelikli uzman desteği',
            'Kişisel danışman ataması',
            'Aylık strateji toplantısı'
          ]
        },
        createdAt: DateTime.now(),
      ),
      MarketProductModel(
        id: 'd1a22222-2222-2222-2222-222222222222',
        title: 'Özel Firma & Vergi Yapılandırma Danışmanlığı',
        description: 'Şirketlerin finansal risklerini yönetmek, vergi yapılandırmalarını gerçekleştirmek ve geleceğe yönelik planlama yapmak için kapsamlı destek.',
        imageUrl: 'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?w=400&q=80',
        creditCost: 12000,
        stock: 5,
        type: MarketProductType.vipService,
        category: 'Danışmanlık',
        metadata: {
          'features': [
            'Vergi planlama desteği',
            'Mali yapılandırma analizi',
            'Risk ve fırsat raporu',
            'Özel aksiyon planı'
          ]
        },
        createdAt: DateTime.now(),
      ),
      MarketProductModel(
        id: 'd1a33333-3333-3333-3333-333333333333',
        title: 'Özel Yazılım Entegrasyon Paketi',
        description: 'Finansal ve muhasebe yazılımlarınızı otomatik entegre eden, süreçlerinizi kolaylaştıran özel yazılım desteği.',
        imageUrl: 'https://images.unsplash.com/photo-1551434678-e076c223a692?w=400&q=80',
        creditCost: 15000,
        stock: 8,
        type: MarketProductType.vipService,
        category: 'Teknoloji',
        metadata: {
          'features': [
            'Firma verilerinize özel entegrasyon',
            'Otomatik raporlama sistemi',
            'API ve sistem kurulumu',
            '3 ay teknik destek'
          ]
        },
        createdAt: DateTime.now(),
      ),
      MarketProductModel(
        id: 'd1a44444-4444-4444-4444-444444444444',
        title: 'Kişisel Mentor & Koçluk Programı (6 Ay)',
        description: 'Kariyerinizde ve işinizde hedeflerinize ulaşmanız için tasarlanmış 6 aylık birebir gelişim ve mentorluk süreci.',
        imageUrl: 'https://images.unsplash.com/photo-1552664730-d307ca884978?w=400&q=80',
        creditCost: 15000,
        stock: 12,
        type: MarketProductType.vipService,
        category: 'Kişisel Gelişim',
        metadata: {
          'features': [
            '6 ay 1\'e 1 mentorluk',
            'Mesleki gelişim planı',
            'Aylık performans analizi',
            'Özel kaynak ve rehberlik'
          ]
        },
        createdAt: DateTime.now(),
      ),
    ];
  }
}
