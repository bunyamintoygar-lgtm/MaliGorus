import 'market_product_model.dart';

class MarketPurchaseModel {
  final String id;
  final String userId;
  final String productId;
  final int creditPaid;
  final String status;
  final DateTime createdAt;
  final String? userName; // Populated via join with profiles(full_name)
  final MarketProductModel? product; // Populated via join with market_products(*)

  MarketPurchaseModel({
    required this.id,
    required this.userId,
    required this.productId,
    required this.creditPaid,
    required this.status,
    required this.createdAt,
    this.userName,
    this.product,
  });

  factory MarketPurchaseModel.fromJson(Map<String, dynamic> json) {
    return MarketPurchaseModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      creditPaid: json['credit_paid'] ?? 0,
      status: json['status'] ?? 'completed',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      userName: json['profiles']?['full_name'] ?? json['user_name'],
      product: json['market_products'] != null 
          ? MarketProductModel.fromJson(json['market_products']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'product_id': productId,
      'credit_paid': creditPaid,
      'status': status,
    };
  }
}
