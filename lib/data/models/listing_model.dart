import '../../core/utils/name_formatter.dart';

class ListingModel {
  final String id;
  final String authorId;
  final String title;
  final String? description;
  final String? category;
  final String? location;
  final int creditCost;
  final DateTime createdAt;
  final int applicationCount;
  final String? authorName;
  final String? authorProfession;
  final String? authorHighestLevel;

  ListingModel({
    required this.id,
    required this.authorId,
    required this.title,
    this.description,
    this.category,
    this.location,
    this.creditCost = 30,
    required this.createdAt,
    this.applicationCount = 0,
    this.authorName,
    this.authorProfession,
    this.authorHighestLevel,
  });

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    // Supabase count mapping
    final countData = json['application_count'];
    int count = 0;
    if (countData is List && countData.isNotEmpty) {
      count = countData[0]['count'] ?? 0;
    } else if (countData is int) {
      count = countData;
    } else if (countData is Map) {
      count = countData['count'] ?? 0;
    }

    final profiles = json['profiles'] as Map<String, dynamic>?;
    
    return ListingModel(
      id: json['id'],
      authorId: json['author_id'],
      title: json['title'],
      description: json['description'],
      category: json['category'],
      location: json['location'],
      creditCost: json['credit_cost'] ?? 30,
      createdAt: DateTime.parse(json['created_at']),
      applicationCount: count,
      authorName: profiles?['full_name'],
      authorProfession: profiles?['profession'],
      authorHighestLevel: profiles?['highest_level'],
    );
  }

  String get formattedAuthorName => authorName != null ? NameFormatter.format(authorName) : 'İşveren';
}
