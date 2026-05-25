-- =========================================================================
-- MaliGörüş Market Products Seeding SQL Script (Enriched Edition)
-- =========================================================================
-- Bu scripti Supabase Dashboard -> SQL Editor alanına yapıştırıp "Run" 
-- butonuna tıklayarak veritabanınızı 30+ premium ve videolu ürünle anında doldurabilirsiniz.
--
-- NOT: Mevcut satın alımları bozmamak için DELETE yerine "ON CONFLICT" kullanılmıştır.
-- Bu sayde mevcut satın aldığınız ürünler güncellenir, yeni ürünler ise doğrudan eklenir.

INSERT INTO market_products (id, title, description, image_url, credit_cost, stock, is_active, type, category, metadata, created_at) VALUES

-- === 1. DOKÜMANLAR & HAZIR ŞABLONLAR (Type: 'document') ===
(
  'd0c11111-1111-1111-1111-111111111111', 
  'İş Planı Şablonu', 
  'Yatırımcı sunumları, hibe başvuruları ve banka kredileri için uzmanlarca hazırlanmış, kapsamlı ve profesyonel iş planı şablonu.', 
  'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=600&q=80', 
  1250, 
  999, 
  true, 
  'document', 
  'İş & Yönetim', 
  '{"file_type": "docx", "pages": "12 Sayfa", "validity": "2026 Güncel", "usage": "Sınırsız", "video_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}', 
  NOW()
),
(
  'd0c22222-2222-2222-2222-222222222222', 
  'Bütçe Planlama Tablosu', 
  'Şirketinizin gelir-gider takibi, departman bütçeleri ve yıllık tahminler yapabilmeniz için formülleri hazır, profesyonel Excel şablonu.', 
  'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=600&q=80', 
  950, 
  999, 
  true, 
  'document', 
  'Finans', 
  '{"file_type": "xlsx", "pages": "6 Sekme", "validity": "2026 Güncel", "usage": "Sınırsız", "video_url": "https://www.youtube.com/watch?v=KGD-T3bhFEA"}', 
  NOW()
),
(
  'd0c33333-3333-3333-3333-333333333333', 
  'Sözleşme Şablonları Paketi', 
  'İş ortaklıkları, hizmet alımları, freelance iş sözleşmeleri ve danışmanlık hizmetleri için 10+ farklı, hukuki olarak koruyucu sözleşme şablonu.', 
  'https://images.unsplash.com/photo-1450133064473-71024230f91b?w=600&q=80', 
  1800, 
  999, 
  true, 
  'document', 
  'Hukuk', 
  '{"file_type": "pdf", "pages": "25 Sayfa", "validity": "2026 Güncel", "usage": "Sınırsız", "video_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}', 
  NOW()
),
(
  'd0c44444-4444-4444-4444-444444444444', 
  'Pazarlama Planı Şablonu', 
  'Marka konumlandırma, hedef kitle analizi ve dijital pazarlama kanalları bütçelendirmesi için hazır sunum sunusu ve planlama rehberi.', 
  'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=600&q=80', 
  1100, 
  999, 
  true, 
  'document', 
  'Pazarlama', 
  '{"file_type": "pptx", "pages": "18 Slayt", "validity": "2026 Güncel", "usage": "Sınırsız", "video_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}', 
  NOW()
),
(
  'd0c55555-5555-5555-5555-555555555555', 
  'Toplantı Notu Şablonu', 
  'Ekiplerinizin haftalık ve aylık toplantılarında alınan kararları, aksiyon adımlarını ve sorumluları takip edebilmeniz için şık Word belgesi.', 
  'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?w=600&q=80', 
  450, 
  999, 
  true, 
  'document', 
  'İş & Yönetim', 
  '{"file_type": "docx", "pages": "2 Sayfa", "validity": "Genel", "usage": "Sınırsız"}', 
  NOW()
),
(
  'd0c66666-6666-6666-6666-666666666666', 
  'Nakit Akış Tablosu', 
  'Aylık ve yıllık bazda nakit giriş-çıkış dengesini görebileceğiniz, geleceğe yönelik likidite tahmini yapabilen otomatik Excel tablosu.', 
  'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?w=600&q=80', 
  650, 
  999, 
  true, 
  'document', 
  'Finans', 
  '{"file_type": "xlsx", "pages": "4 Sekme", "validity": "2026 Güncel", "usage": "Sınırsız", "video_url": "https://www.youtube.com/watch?v=KGD-T3bhFEA"}', 
  NOW()
),
(
  'd0c77777-7777-7777-7777-777777777777', 
  'Gizlilik Sözleşmesi (NDA)', 
  'Yeni fikirlerinizi, şirket verilerinizi veya ticari sırlarınızı üçüncü şahıslarla paylaşırken hukuki koruma sağlayan profesyonel gizlilik sözleşmesi.', 
  'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=600&q=80', 
  900, 
  999, 
  true, 
  'document', 
  'Hukuk', 
  '{"file_type": "docx", "pages": "4 Sayfa", "validity": "2026 Güncel", "usage": "Sınırsız", "video_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}', 
  NOW()
),
(
  'd0c88888-8888-8888-8888-888888888888', 
  'Performans Değerlendirme Şablonu', 
  'Şirket içi çalışanların yıllık hedeflerini, yetkinliklerini ve geri bildirimlerini yapılandırılmış bir biçimde yönetmek için sunum ve form paketi.', 
  'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?w=600&q=80', 
  700, 
  999, 
  true, 
  'document', 
  'İş & Yönetim', 
  '{"file_type": "pptx", "pages": "15 Slayt", "validity": "2026 Güncel", "usage": "Sınırsız"}', 
  NOW()
),
(
  'd0c99999-9999-9999-9999-999999999999', 
  'KVKK Uyum Rehberi ve Belgeleri', 
  'Kişisel Verilerin Korunması Kanunu kapsamında şirketinizin alması gereken idari tedbirler, aydınlatma metinleri ve açık rıza formları şablon paketi.', 
  'https://images.unsplash.com/photo-1508873535684-277a3cbcc4e8?w=600&q=80', 
  2500, 
  999, 
  true, 
  'document', 
  'Hukuk', 
  '{"file_type": "zip", "pages": "45 Belge", "validity": "2026 Uyumlu", "usage": "Sınırsız", "video_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}', 
  NOW()
),
(
  'd0caaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 
  'Kurumlar Vergisi Kontrol Listesi', 
  'Beyanname döneminde hata yapmamanız için gider yazılabilen kalemler, istisna ve indirimlerin yer aldığı mükemmel bir kontrol tablosu.', 
  'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=600&q=80', 
  850, 
  999, 
  true, 
  'document', 
  'Finans', 
  '{"file_type": "xlsx", "pages": "3 Sekme", "validity": "2026 Güncel", "usage": "Sınırsız", "video_url": "https://www.youtube.com/watch?v=KGD-T3bhFEA"}', 
  NOW()
),

-- === 2. SERTİFİKA PROGRAMLARI (Type: 'certificate') ===
(
  'c1e11111-1111-1111-1111-111111111111', 
  'Dijital Pazarlama Sertifika Programı', 
  'Dijital pazarlamanın temelleri, Google Ads, SEO, sosyal medya yönetimi ve dönüşüm optimizasyonu konularında 48 ders saatlik uzmanlık eğitimi.', 
  'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=600&q=80', 
  12000, 
  50, 
  true, 
  'certificate', 
  'Pazarlama', 
  '{"duration": "8 Hafta", "lectures_count": 48, "level": "Orta Seviye", "badge": "POPÜLER", "video_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}', 
  NOW()
),
(
  'c1e22222-2222-2222-2222-222222222222', 
  'Finansal Analiz Sertifika Programı', 
  'Finansal tabloların analizi, rasyolar, nakit yönetimi ve yatırım kararlarının değerlendirilmesi üzerine odaklanmış kapsamlı müfredat.', 
  'https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=600&q=80', 
  11000, 
  40, 
  true, 
  'certificate', 
  'Finans', 
  '{"duration": "6 Hafta", "lectures_count": 36, "level": "Orta Seviye", "badge": "POPÜLER", "video_url": "https://www.youtube.com/watch?v=KGD-T3bhFEA"}', 
  NOW()
),
(
  'c1e33333-3333-3333-3333-333333333333', 
  'Python ile Veri Analizi Sertifikası', 
  'Veri bilimine ilk adım: Python, Pandas, Numpy, Matplotlib ve makine öğrenmesine giriş algoritmalarıyla büyük veri analizi becerileri kazanın.', 
  'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=600&q=80', 
  13500, 
  30, 
  true, 
  'certificate', 
  'Teknoloji', 
  '{"duration": "7 Hafta", "lectures_count": 42, "level": "Orta - İleri Seviye", "badge": "YENİ", "video_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}', 
  NOW()
),
(
  'c1e44444-4444-4444-4444-444444444444', 
  'İnsan Kaynakları Yönetimi Sertifikası', 
  'İşe alım, mülakat teknikleri, yetenek yönetimi, bordrolama ve iş hukuku süreçlerini içeren uçtan uca modern insan kaynakları eğitimi.', 
  'https://images.unsplash.com/photo-1573497019940-1c28c88b4f3e?w=600&q=80', 
  9000, 
  60, 
  true, 
  'certificate', 
  'İş & Yönetim', 
  '{"duration": "5 Hafta", "lectures_count": 30, "level": "Başlangıç", "badge": "POPÜLER"}', 
  NOW()
),
(
  'c1e55555-5555-5555-5555-555555555555', 
  'Excel İleri Düzey Sertifika Programı', 
  'Temel Excel bilgisini profesyonel düzeye taşıyın: Makrolar, Pivot Tablolar, Dashboard tasarımı, veri görselleştirme ve VBA programlama.', 
  'https://images.unsplash.com/photo-1531403009284-440f080d1e12?w=600&q=80', 
  8000, 
  100, 
  true, 
  'certificate', 
  'Teknoloji', 
  '{"duration": "4 Hafta", "lectures_count": 24, "level": "Orta Seviye", "badge": "ÇOK SATAN", "video_url": "https://www.youtube.com/watch?v=KGD-T3bhFEA"}', 
  NOW()
),
(
  'c1e66666-6666-6666-6666-666666666666', 
  'Uluslararası Finansal Raporlama (IFRS)', 
  'Uluslararası Muhasebe Standartları (IAS) ve IFRS kurallarına göre finansal tabloların hazırlanması ve raporlanması konusunda uzmanlaşın.', 
  'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=600&q=80', 
  14000, 
  25, 
  true, 
  'certificate', 
  'Finans', 
  '{"duration": "8 Hafta", "lectures_count": 40, "level": "İleri Düzey", "badge": "PREMIUM", "video_url": "https://www.youtube.com/watch?v=KGD-T3bhFEA"}', 
  NOW()
),

-- === 3. CANLI EĞİTİMLER (Type: 'live_training') ===
(
  '111e1111-1111-1111-1111-111111111111', 
  'Finansal Analiz Uzmanlığı Canlı Atölyesi', 
  'Bilanço, gelir tablosu ve nakit akışı analizini canlı uygulamalarla ve gerçek şirket verileri üzerinden öğreneceğiniz interaktif atölye.', 
  'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?w=600&q=80', 
  3750, 
  20, 
  true, 
  'live_training', 
  'Finans', 
  '{"is_live": true, "duration": "2s 30dk", "zoom_link": "https://zoom.us/j/test-meeting-1", "date_time": "Bugün 14:00", "trainer_name": "Mehmet Yılmaz", "trainer_title": "Finans Uzmanı", "trainer_avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&q=80", "video_url": "https://www.youtube.com/watch?v=KGD-T3bhFEA"}', 
  NOW()
),
(
  '111e2222-2222-2222-2222-222222222222', 
  'Dijital Pazarlama Stratejileri', 
  'SEO, Google Ads, Meta Ads ve büyüme pazarlaması (growth hacking) stratejilerini sıfırdan kurmayı öğreneceğiniz canlı yayın eğitimi.', 
  'https://images.unsplash.com/photo-1432888498266-38ffec3eaf0a?w=600&q=80', 
  2800, 
  25, 
  true, 
  'live_training', 
  'Pazarlama', 
  '{"is_live": true, "duration": "1s 45dk", "zoom_link": "https://zoom.us/j/test-meeting-2", "date_time": "Yarın 11:00", "trainer_name": "Ayşe Demir", "trainer_title": "Dijital Pazarlama Uzmanı", "trainer_avatar": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&q=80", "video_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}', 
  NOW()
),
(
  '111e3333-3333-3333-3333-333333333333', 
  'Excel İleri Seviye – Dashboard Eğitimi', 
  'Yöneticiler için tek ekranda tüm KPI ve verilerin takip edilebildiği, otomatik güncellenen dinamik veri panelleri hazırlama eğitimi.', 
  'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=600&q=80', 
  2500, 
  35, 
  true, 
  'live_training', 
  'Teknoloji', 
  '{"is_live": false, "duration": "2s 15dk", "zoom_link": "https://zoom.us/j/test-meeting-3", "date_time": "28 Mayıs Cuma 15:00", "trainer_name": "Kerem Arslan", "trainer_title": "Excel Eğitmeni", "trainer_avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&q=80", "video_url": "https://www.youtube.com/watch?v=KGD-T3bhFEA"}', 
  NOW()
),
(
  '111e4444-4444-4444-4444-444444444444', 
  'Liderlik ve Etkin Ekip Yönetimi', 
  'Uzaktan çalışan ekiplerde motivasyon, çatışma yönetimi, geri bildirim kültürü ve görev dağılımını optimize etme üzerine canlı yayın atölyesi.', 
  'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=600&q=80', 
  2200, 
  30, 
  true, 
  'live_training', 
  'İş & Yönetim', 
  '{"is_live": false, "duration": "1s 30dk", "zoom_link": "https://zoom.us/j/test-meeting-4", "date_time": "30 Mayıs Cmt 10:30", "trainer_name": "Zeynep Kaya", "trainer_title": "İK ve Liderlik Danışmanı", "trainer_avatar": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80"}', 
  NOW()
),
(
  '111e5555-5555-5555-5555-555555555555', 
  'Dönem Sonu Kapanış İşlemleri', 
  'Mali müşavirlerin yıl sonu işlemlerinde dikkat etmesi gereken kritik hususlar, amortismanlar ve vergi matrahı tespiti üzerine canlı yayın.', 
  'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=600&q=80', 
  4000, 
  15, 
  true, 
  'live_training', 
  'Finans', 
  '{"is_live": true, "duration": "3 Saat", "zoom_link": "https://zoom.us/j/test-meeting-5", "date_time": "1 Haziran Pzt 19:30", "trainer_name": "Ahmet Şahin", "trainer_title": "YMM / Vergi Uzmanı", "trainer_avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&q=80", "video_url": "https://www.youtube.com/watch?v=KGD-T3bhFEA"}', 
  NOW()
),

-- === 4. ETKİNLİKLER (Type: 'event') ===
(
  'e0e11111-1111-1111-1111-111111111111', 
  'Ekonomide Güncel Gelişmeler Semineri', 
  'Merkez bankası faiz kararları, enflasyon beklentileri ve döviz piyasalarının 2026 yılı seyri üzerine interaktif panel.', 
  'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=600&q=80', 
  0, 
  100, 
  true, 
  'event', 
  'Finans', 
  '{"day": "24", "month": "MAY", "duration": "1s 30dk", "location": "Online / Zoom", "date_time": "24 MAY | 19:00 - 20:30", "event_type": "WEBINAR", "trainer_name": "Dr. Ali Yılmaz", "trainer_title": "Ekonomist", "trainer_avatar": "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&q=80", "video_url": "https://www.youtube.com/watch?v=KGD-T3bhFEA"}', 
  NOW()
),
(
  'e0e22222-2222-2222-2222-222222222222', 
  'Etkili Sunum Teknikleri Atölyesi', 
  'Topluluk önünde heyecanı yönetme, sunum tasarlama teknikleri ve etkileyici beden dili kullanımı üzerine yüz yüze atölye.', 
  'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?w=600&q=80', 
  1250, 
  15, 
  true, 
  'event', 
  'Kişisel Gelişim', 
  '{"day": "28", "month": "MAY", "duration": "3 Saat", "location": "Levent, İstanbul", "date_time": "28 MAY | 14:00 - 17:00", "event_type": "ATÖLYE", "trainer_name": "Zeynep Kaya", "trainer_title": "Eğitmen & İletişim Koçu", "trainer_avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100&q=80"}', 
  NOW()
),
(
  'e0e33333-3333-3333-3333-333333333333', 
  'Yapay Zeka ile Geleceği Şekillendirmek', 
  'Yapay zeka araçlarının (ChatGPT, Midjourney) iş dünyasına ve muhasebe süreçlerine entegrasyonu hakkında kapsamlı seminer.', 
  'https://images.unsplash.com/photo-1677442136019-21780efad99a?w=600&q=80', 
  750, 
  200, 
  true, 
  'event', 
  'Teknoloji', 
  '{"day": "31", "month": "MAY", "duration": "2 Saat", "location": "Online / YouTube Canlı", "date_time": "31 MAY | 19:00 - 21:00", "event_type": "SEMİNER", "trainer_name": "Mehmet Demir", "trainer_title": "Yapay Zeka Mimarı", "trainer_avatar": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&q=80", "video_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}', 
  NOW()
),
(
  'e0e44444-4444-4444-4444-444444444444', 
  'Mali Müşavirler Vizyon Günü', 
  'Sektörün geleceği, dijital dönüşüm fırsatları ve mali süreçlerde otomasyon konularının tartışılacağı büyük networking buluşması.', 
  'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=600&q=80', 
  1500, 
  150, 
  true, 
  'event', 
  'Finans', 
  '{"day": "12", "month": "HAZ", "duration": "Tam Gün", "location": "Kadıköy, İstanbul", "date_time": "12 HAZ | 09:30 - 17:30", "event_type": "KONFERANS", "trainer_name": "Mustafa Koç", "trainer_title": "YMM / Moderatör", "trainer_avatar": "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&q=80", "video_url": "https://www.youtube.com/watch?v=KGD-T3bhFEA"}', 
  NOW()
),

-- === 5. VIP HİZMETLER (Type: 'vip_service') ===
(
  'd1a11111-1111-1111-1111-111111111111', 
  'VIP Yıllık Danışmanlık Paketi', 
  'Finansal durum analizleri, özel vergi danışmanlığı, atanan kişisel danışman ve aylık strateji geliştirme toplantıları içeren tam kapsamlı kurumsal paket.', 
  'https://images.unsplash.com/photo-1521791136064-7986c2920216?w=600&q=80', 
  10000, 
  10, 
  true, 
  'vip_service', 
  'Danışmanlık', 
  '{"features": ["Yıllık limitsiz danışmanlık", "Öncelikli uzman desteği", "Kişisel danışman ataması", "Aylık strateji toplantısı"], "video_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}', 
  NOW()
),
(
  'd1a22222-2222-2222-2222-222222222222', 
  'Vergi Yapılandırma Danışmanlığı', 
  'Şirketinizin finansal risklerini azaltmak, yasal muafiyetlerden yararlanmak ve en uygun vergi stratejilerini belirlemek üzere özel danışmanlık.', 
  'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?w=600&q=80', 
  12000, 
  5, 
  true, 
  'vip_service', 
  'Danışmanlık', 
  '{"features": ["Vergi planlama desteği", "Mali yapılandırma analizi", "Risk ve fırsat raporu", "Özel aksiyon planı"], "video_url": "https://www.youtube.com/watch?v=KGD-T3bhFEA"}', 
  NOW()
),
(
  'd1a33333-3333-3333-3333-333333333333', 
  'Özel Yazılım Entegrasyon Paketi', 
  'Şirketinizin ERP, fatura ve muhasebe yazılımlarını otomatik entegre eden, süreçlerinizi %90 oranında hızlandıran özel API ve kurulum paketi.', 
  'https://images.unsplash.com/photo-1551434678-e076c223a692?w=600&q=80', 
  15000, 
  8, 
  true, 
  'vip_service', 
  'Teknoloji', 
  '{"features": ["Firma verilerinize özel entegrasyon", "Otomatik raporlama sistemi", "API ve sistem kurulumu", "3 ay kesintisiz teknik destek"]}', 
  NOW()
),
(
  'd1a44444-4444-4444-4444-444444444444', 
  'Kişisel Mentor & Koçluk Programı (6 Ay)', 
  'Finans ve muhasebe alanında kariyer hedeflerinize emin adımlarla ulaşmanız, liderlik yetkinliklerinizi artırmanız için 6 aylık birebir mentorluk.', 
  'https://images.unsplash.com/photo-1552664730-d307ca884978?w=600&q=80', 
  15000, 
  12, 
  true, 
  'vip_service', 
  'Kişisel Gelişim', 
  '{"features": ["6 ay 1''e 1 mentorluk", "Mesleki gelişim planı", "Aylık performans analizi", "Özel kaynak ve rehberlik"]}', 
  NOW()
),
(
  'd1a55555-5555-5555-5555-555555555555', 
  'Dijital Dönüşüm & E-Devlet Entegrasyonu', 
  'E-Fatura, e-Arşiv, e-Defter geçiş süreçlerinde şirketinizi uçtan uca hazırlayan, cezai riskleri sıfırlayan premium kurulum ve danışmanlık hizmeti.', 
  'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&q=80', 
  13000, 
  15, 
  true, 
  'vip_service', 
  'Teknoloji', 
  '{"features": ["E-geçiş süreç analizi", "Kurulum ve test işlemleri", "Çalışan eğitimi semineri", "1 ay canlı destek hattı"], "video_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}', 
  NOW()
)

ON CONFLICT (id) 
DO UPDATE SET 
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  image_url = EXCLUDED.image_url,
  credit_cost = EXCLUDED.credit_cost,
  stock = EXCLUDED.stock,
  is_active = EXCLUDED.is_active,
  type = EXCLUDED.type,
  category = EXCLUDED.category,
  metadata = EXCLUDED.metadata;
