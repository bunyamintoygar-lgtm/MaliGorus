import '../../core/utils/name_formatter.dart';

class SurveyModel {
  final String id;
  final String authorId;
  final String title;
  final String? description;
  final List<SurveyOption> options;
  final String status;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final String? authorName;
  final String? authorProfession;
  final String? authorHighestLevel;

  SurveyModel({
    required this.id,
    required this.authorId,
    required this.title,
    this.description,
    required this.options,
    this.status = 'active',
    this.expiresAt,
    required this.createdAt,
    this.authorName,
    this.authorProfession,
    this.authorHighestLevel,
  });

  factory SurveyModel.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'] as Map<String, dynamic>?;
    
    return SurveyModel(
      id: json['id'],
      authorId: json['author_id'],
      title: json['title'],
      description: json['description'],
      options: (json['options'] as List).map((e) => SurveyOption.fromJson(e)).toList(),
      status: json['status'] ?? 'active',
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      authorName: profiles?['full_name'],
      authorProfession: profiles?['profession'],
      authorHighestLevel: profiles?['highest_level'],
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }

  String get formattedAuthorName => NameFormatter.format(authorName);
}

class SurveyOption {
  final String id;
  final String text;
  final int votes;

  SurveyOption({required this.id, required this.text, this.votes = 0});

  factory SurveyOption.fromJson(Map<String, dynamic> json) {
    return SurveyOption(
      id: json['id'],
      text: json['text'],
      votes: json['votes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'votes': votes};
}
