import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../data/models/level_model.dart';
import '../../data/models/market_category_model.dart';

final appConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.from('app_config').select();
  
  final Map<String, dynamic> config = {};
  for (var item in response) {
    final key = item['key'];
    final value = item['value'];
    
    if (value is String && (value.startsWith('[') || value.startsWith('{'))) {
      try {
        config[key] = jsonDecode(value);
      } catch (e) {
        config[key] = value;
      }
    } else {
      config[key] = value;
    }
  }
  return config;
});

final levelConfigProvider = Provider<AsyncValue<List<LevelModel>>>((ref) {
  final configAsync = ref.watch(appConfigProvider);
  return configAsync.whenData((config) {
    final levelsJson = config['level_config'] as List<dynamic>? ?? [];
    return levelsJson.map((l) => LevelModel.fromJson(l as Map<String, dynamic>)).toList();
  });
});

/// Zengin yapılı varsayılan kategoriler ve alt kategorileri (ikonlu ve renkli)
final List<MarketCategoryModel> _defaultMarketCategories = [
  const MarketCategoryModel(
    id: 'sablonlar',
    label: 'Şablonlar',
    icon: 'folder_open',
    color: '4F46E5',
    subcategories: [
      MarketSubCategoryModel(id: 'is_yonetim', label: 'İş & Yönetim', icon: 'business'),
      MarketSubCategoryModel(id: 'finans_muhasebe', label: 'Finans & Muhasebe', icon: 'calculate'),
      MarketSubCategoryModel(id: 'vergi_hukuku', label: 'Vergi Hukuku', icon: 'gavel'),
      MarketSubCategoryModel(id: 'pazarlama', label: 'Pazarlama', icon: 'trending_up'),
    ],
  ),
  const MarketCategoryModel(
    id: 'dokumanlar',
    label: 'Dokümanlar',
    icon: 'description',
    color: '0EA5E9',
    subcategories: [
      MarketSubCategoryModel(id: 'resmi_yazilar', label: 'Resmi Yazışmalar', icon: 'article'),
      MarketSubCategoryModel(id: 'sozlesmeler', label: 'Sözleşmeler', icon: 'handshake'),
      MarketSubCategoryModel(id: 'yonetmelikler', label: 'Yönetmelikler', icon: 'balance'),
      MarketSubCategoryModel(id: 'kilavuzlar', label: 'Kılavuzlar', icon: 'menu_book'),
    ],
  ),
  const MarketCategoryModel(
    id: 'paketler',
    label: 'Paketler',
    icon: 'inventory_2',
    color: '10B981',
    subcategories: [
      MarketSubCategoryModel(id: 'baslangic', label: 'Başlangıç Paketleri', icon: 'workspace_premium'),
      MarketSubCategoryModel(id: 'sektorler', label: 'Sektörel Paketler', icon: 'business'),
      MarketSubCategoryModel(id: 'denetim', label: 'Denetim Paketleri', icon: 'verified'),
    ],
  ),
  const MarketCategoryModel(
    id: 'araclar',
    label: 'Araçlar',
    icon: 'construction',
    color: 'F59E0B',
    subcategories: [
      MarketSubCategoryModel(id: 'hesaplayicilar', label: 'Hesaplayıcılar', icon: 'calculate'),
      MarketSubCategoryModel(id: 'tablolar', label: 'Tablolar & Grafikler', icon: 'table_chart'),
      MarketSubCategoryModel(id: 'yazilimlar', label: 'Pratik Yazılımlar', icon: 'computer'),
    ],
  ),
  const MarketCategoryModel(
    id: 'egitimler',
    label: 'Eğitimler',
    icon: 'school',
    color: 'EC4899',
    subcategories: [
      MarketSubCategoryModel(id: 'video_egitim', label: 'Video Eğitimler', icon: 'computer'),
      MarketSubCategoryModel(id: 'makaleler', label: 'Akademik Makaleler', icon: 'article'),
      MarketSubCategoryModel(id: 'sunumlar', label: 'Seminer Sunumları', icon: 'assessment'),
    ],
  ),
  const MarketCategoryModel(
    id: 'diger',
    label: 'Diğer',
    icon: 'more_horiz',
    color: '64748B',
    subcategories: [
      MarketSubCategoryModel(id: 'diger_alt', label: 'Diğer Dosyalar', icon: 'label'),
    ],
  ),
];

final marketCategoriesProvider = Provider<AsyncValue<List<MarketCategoryModel>>>((ref) {
  final configAsync = ref.watch(appConfigProvider);
  return configAsync.whenData((config) {
    final raw = config['market_categories'];
    if (raw is List) {
      return raw.map((e) => MarketCategoryModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return _defaultMarketCategories;
  });
});

bool isVersionOutdated(String currentVersion, String minVersion) {
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
    // Silent catch
  }
  return false;
}

final updateAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    final config = await ref.watch(appConfigProvider.future);
    final latestVersion = config['latest_app_version']?.toString();
    if (latestVersion == null) return false;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

    return isVersionOutdated(currentVersion, latestVersion);
  } catch (_) {
    return false;
  }
});
