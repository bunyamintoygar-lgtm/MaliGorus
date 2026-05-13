import '../../core/utils/name_formatter.dart';

class DiscussionModel {
  final String id;
  final String authorId;
  final String type; // 'tartisma' | 'danisma'
  final String title;
  final String body;
  final String? authorName;
  final String? authorProfession;
  final String? authorAvatarUrl;
  final String? authorHighestLevel;
  final List<String> targetProfessions;
  final String visibilityType; // 'everyone' | 'connections'
  final int replyLimit;
  final String? category;
  final String status; // 'active' | 'closed'
  final List<String> attachmentUrls;
  final bool isResolved;
  final int replyCount;
  final DateTime createdAt;
  final DateTime lastActivityAt;
  final bool isAnonymous;

  final int viewCount;
  final int likeCount;
  final bool isLiked;

  DiscussionModel({
    required this.id,
    required this.authorId,
    this.authorName,
    this.authorProfession,
    this.authorAvatarUrl,
    this.authorHighestLevel,
    this.targetProfessions = const [],
    this.visibilityType = 'everyone',
    this.replyLimit = 3,
    this.status = 'active',
    this.category,
    this.attachmentUrls = const [],
    required this.type,
    required this.title,
    required this.body,
    this.isResolved = false,
    this.replyCount = 0,
    this.viewCount = 0,
    this.likeCount = 0,
    this.isLiked = false,
    required this.createdAt,
    DateTime? lastActivityAt,
    this.isAnonymous = false,
  }) : lastActivityAt = lastActivityAt ?? createdAt;

  factory DiscussionModel.fromJson(Map<String, dynamic> json) {
    // Supabase count subquery format: "reply_count": [{"count": 5}]
    int count = 0;
    if (json['reply_count'] is List) {
      final list = json['reply_count'] as List;
      if (list.isNotEmpty) {
        count = list.first['count'] ?? 0;
      }
    } else if (json['reply_count'] is int) {
      count = json['reply_count'];
    }

    final createdAt = DateTime.parse(json['created_at']);
    DateTime? lastActivityAt = json['last_activity_at'] != null 
        ? DateTime.parse(json['last_activity_at']) 
        : null;

    // Repository tarafından sağlanan senkronize edilmiş tarih varsa onu önceliklendir
    if (json['last_activity_at_sync'] != null) {
      final syncDate = DateTime.parse(json['last_activity_at_sync']);
      if (lastActivityAt == null || syncDate.isAfter(lastActivityAt)) {
        lastActivityAt = syncDate;
      }
    }

    final profile = json['profiles'] as Map<String, dynamic>?;

    return DiscussionModel(
      id: json['id'],
      authorId: json['author_id'],
      authorName: profile?['full_name'],
      authorProfession: profile?['profession'],
      authorAvatarUrl: profile?['avatar_url'],
      authorHighestLevel: profile?['highest_level'],
      targetProfessions: (json['target_professions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      visibilityType: json['visibility_type'] ?? 'everyone',
      replyLimit: json['reply_limit'] ?? 3,
      status: json['status'] ?? 'active',
      category: json['category'],
      attachmentUrls: (json['attachment_urls'] as List?)?.map((e) => e.toString()).toList() ?? [],
      type: json['type'],
      title: json['title'],
      body: json['body'],
      isResolved: json['is_resolved'] ?? false,
      replyCount: count,
      viewCount: json['view_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      isLiked: _parseIsLiked(json['is_liked']),
      createdAt: createdAt,
      lastActivityAt: lastActivityAt,
      isAnonymous: json['is_anonymous'] ?? false,
    );
  }

  static bool _parseIsLiked(dynamic isLikedData) {
    if (isLikedData == null) return false;
    if (isLikedData is bool) return isLikedData;
    if (isLikedData is List) {
      if (isLikedData.isEmpty) return false;
      final first = isLikedData[0];
      if (first is Map && first.containsKey('count')) {
        return (first['count'] as int) > 0;
      }
      return true;
    }
    return false;
  }

  DiscussionModel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorProfession,
    String? authorAvatarUrl,
    String? authorHighestLevel,
    List<String>? targetProfessions,
    String? visibilityType,
    int? replyLimit,
    String? category,
    String? status,
    List<String>? attachmentUrls,
    String? type,
    String? title,
    String? body,
    bool? isResolved,
    int? replyCount,
    int? viewCount,
    int? likeCount,
    bool? isLiked,
    DateTime? createdAt,
    DateTime? lastActivityAt,
    bool? isAnonymous,
  }) {
    return DiscussionModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorProfession: authorProfession ?? this.authorProfession,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      authorHighestLevel: authorHighestLevel ?? this.authorHighestLevel,
      targetProfessions: targetProfessions ?? this.targetProfessions,
      visibilityType: visibilityType ?? this.visibilityType,
      replyLimit: replyLimit ?? this.replyLimit,
      category: category ?? this.category,
      status: status ?? this.status,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      isResolved: isResolved ?? this.isResolved,
      replyCount: replyCount ?? this.replyCount,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  String get formattedAuthorName => NameFormatter.format(authorName);


  String get professionLabel {
    switch (authorProfession) {
      case 'mali_musavir': return 'Mali Müşavir';
      case 'muhasebe_uzmani': return 'Muhasebe Uzmanı';
      case 'ymm': return 'YMM';
      default: return 'Üye';
    }
  }
}

class ReplyModel {
  final String id;
  final String discussionId;
  final String authorId;
  final String? authorName;
  final String? authorProfession;
  final String? authorAvatarUrl;
  final String? authorHighestLevel;
  final String body;
  final bool isAccepted;
  final int likeCount;
  final bool isLiked;
  final DateTime createdAt;
  final String? parentId;

  ReplyModel({
    required this.id,
    required this.discussionId,
    required this.authorId,
    this.authorName,
    this.authorProfession,
    this.authorAvatarUrl,
    this.authorHighestLevel,
    required this.body,
    this.isAccepted = false,
    this.likeCount = 0,
    this.isLiked = false,
    required this.createdAt,
    this.parentId,
  });

  factory ReplyModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return ReplyModel(
      id: json['id'],
      discussionId: json['discussion_id'],
      authorId: json['author_id'],
      authorName: profile?['full_name'],
      authorProfession: profile?['profession'],
      authorAvatarUrl: profile?['avatar_url'],
      authorHighestLevel: profile?['highest_level'],
      body: json['body'],
      isAccepted: json['is_accepted'] ?? false,
      likeCount: json['like_count'] ?? 0,
      isLiked: _parseIsLiked(json['is_liked']),
      createdAt: DateTime.parse(json['created_at']),
      parentId: json['parent_id'],
    );
  }

  static bool _parseIsLiked(dynamic isLikedData) {
    if (isLikedData == null) return false;
    if (isLikedData is bool) return isLikedData;
    if (isLikedData is List) {
      if (isLikedData.isEmpty) return false;
      // Eğer count geliyorsa ve 0'dan büyükse true (Ama repository'de filtreleme olmalı)
      final first = isLikedData[0];
      if (first is Map && first.containsKey('count')) {
        return (first['count'] as int) > 0;
      }
      return true; // Liste doluysa ve count değilse (örn. id listesi) true kabul et
    }
    return false;
  }

  ReplyModel copyWith({
    String? id,
    String? discussionId,
    String? authorId,
    String? authorName,
    String? authorProfession,
    String? authorAvatarUrl,
    String? authorHighestLevel,
    String? body,
    bool? isAccepted,
    int? likeCount,
    bool? isLiked,
    DateTime? createdAt,
    String? parentId,
  }) {
    return ReplyModel(
      id: id ?? this.id,
      discussionId: discussionId ?? this.discussionId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorProfession: authorProfession ?? this.authorProfession,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      authorHighestLevel: authorHighestLevel ?? this.authorHighestLevel,
      body: body ?? this.body,
      isAccepted: isAccepted ?? this.isAccepted,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
      parentId: parentId ?? this.parentId,
    );
  }

  String get formattedAuthorName => NameFormatter.format(authorName);


  String get professionLabel {
    switch (authorProfession) {
      case 'mali_musavir': return 'Mali Müşavir';
      case 'muhasebe_uzmani': return 'Muhasebe Uzmanı';
      case 'ymm': return 'YMM';
      default: return 'Üye';
    }
  }
}
