/// Market ürün kategorileri için veri modeli.
/// app_config tablosundan 'market_categories' key'i altında JSON olarak saklanır.
class MarketSubCategoryModel {
  final String id;
  final String label;
  final String icon; // Material Icons ismi (string)

  const MarketSubCategoryModel({
    required this.id,
    required this.label,
    required this.icon,
  });

  factory MarketSubCategoryModel.fromJson(Map<String, dynamic> json) {
    return MarketSubCategoryModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'label',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'icon': icon};
}

class MarketCategoryModel {
  final String id;
  final String label;
  final String icon; // Material Icons ismi (string)
  final String color; // Hex renk kodu (örn: '4F46E5')
  final List<MarketSubCategoryModel> subcategories;

  const MarketCategoryModel({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.subcategories,
  });

  factory MarketCategoryModel.fromJson(Map<String, dynamic> json) {
    final subs = (json['subcategories'] as List<dynamic>? ?? [])
        .map((s) => MarketSubCategoryModel.fromJson(s as Map<String, dynamic>))
        .toList();
    return MarketCategoryModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'category',
      color: json['color']?.toString() ?? '4F46E5',
      subcategories: subs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'icon': icon,
    'color': color,
    'subcategories': subcategories.map((s) => s.toJson()).toList(),
  };
}
