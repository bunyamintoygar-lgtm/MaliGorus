class PromotionModel {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final int creditCost;
  final int stock;
  final bool isActive;
  final DateTime createdAt;

  PromotionModel({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    required this.creditCost,
    required this.stock,
    this.isActive = true,
    required this.createdAt,
  });

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      imageUrl: json['image_url'],
      creditCost: json['credit_cost'] ?? 0,
      stock: json['stock'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'credit_cost': creditCost,
      'stock': stock,
      'is_active': isActive,
    };
  }
}

class PromotionPurchaseModel {
  final String id;
  final String userId;
  final String? promotionId;
  final int creditAmount;
  final String status;
  final DateTime createdAt;
  final String? userName; // Join ile gelecek
  final PromotionModel? promotion; // UI'da göstermek için join ile gelebilir

  PromotionPurchaseModel({
    required this.id,
    required this.userId,
    this.promotionId,
    required this.creditAmount,
    required this.status,
    required this.createdAt,
    this.userName,
    this.promotion,
  });

  factory PromotionPurchaseModel.fromJson(Map<String, dynamic> json) {
    return PromotionPurchaseModel(
      id: json['id'],
      userId: json['user_id'],
      promotionId: json['promotion_id'],
      creditAmount: json['credit_amount'] ?? 0,
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at']),
      userName: json['profiles']?['full_name'],
      promotion: json['promotions'] != null 
          ? PromotionModel.fromJson(json['promotions']) 
          : null,
    );
  }
}
