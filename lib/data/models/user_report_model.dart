class UserReportModel {
  final String id;
  final String reporterId;
  final String reportedId;
  final String category;
  final String? description;
  final DateTime createdAt;
  final String status; // pending, reviewed, dismissed
  final String contentType;
  final String? contentTitle;
  final String? contentId;
  final String? contentBody;

  // Joined fields (admin view)
  final String? reporterName;
  final String? reporterAvatar;
  final String? reportedName;
  final String? reportedAvatar;

  UserReportModel({
    required this.id,
    required this.reporterId,
    required this.reportedId,
    required this.category,
    this.description,
    required this.createdAt,
    this.status = 'pending',
    this.contentType = 'user',
    this.contentTitle,
    this.contentId,
    this.contentBody,
    this.reporterName,
    this.reporterAvatar,
    this.reportedName,
    this.reportedAvatar,
  });

  factory UserReportModel.fromJson(Map<String, dynamic> json) {
    // Handle joined profile data
    final reporter = json['reporter'] as Map<String, dynamic>?;
    final reported = json['reported'] as Map<String, dynamic>?;

    return UserReportModel(
      id: json['id'],
      reporterId: json['reporter_id'],
      reportedId: json['reported_id'],
      category: json['category'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      status: json['status'] ?? 'pending',
      contentType: json['content_type'] ?? 'user',
      contentTitle: json['content_title'],
      contentId: json['content_id'],
      contentBody: json['content_body'],
      reporterName: reporter?['full_name'],
      reporterAvatar: reporter?['avatar_url'],
      reportedName: reported?['full_name'] ?? json['content_title'],
      reportedAvatar: reported?['avatar_url'],
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'reporter_id': reporterId,
    'reported_id': reportedId,
    'category': category,
    'content_type': contentType,
    if (contentTitle != null) 'content_title': contentTitle,
    if (contentId != null) 'content_id': contentId,
    if (contentBody != null) 'content_body': contentBody,
    if (description != null && description!.isNotEmpty) 'description': description,
  };
}
