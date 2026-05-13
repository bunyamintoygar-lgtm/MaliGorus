import '../../core/utils/name_formatter.dart';

class ProfileModel {
  final String id;
  final String? fullName;
  final String? profession;
  final String? companyName;
  final String? avatarUrl;
  final int creditBalance;
  final bool profileCompleted;
  final bool isVerified;
  final String role;
  final DateTime? createdAt;
  final int discussionCount;
  final int listingCount;
  final bool isAdmin;
  final bool isBanned;
  final DateTime? bannedAt;
  final String? verificationDocUrl;
  final String verificationStatus;
  final String highestLevel;

  // New moderation and restriction fields
  final int moderationStrikeCount;
  final DateTime? tempBlockedUntil;
  final int moderationBlockCountToday;
  final DateTime? lastBlockedAt;
  final bool isIndefiniteBlocked;
  final String? appealExplanation;
  final bool isAppealPending;

  String get displayName => NameFormatter.format(fullName);

  ProfileModel({
    required this.id,
    this.fullName,
    this.profession,
    this.companyName,
    this.avatarUrl,
    this.creditBalance = 0,
    this.profileCompleted = false,
    this.isVerified = false,
    this.role = 'user',
    this.createdAt,
    this.discussionCount = 0,
    this.listingCount = 0,
    this.isAdmin = false,
    this.isBanned = false,
    this.bannedAt,
    this.verificationDocUrl,
    this.verificationStatus = 'unverified',
    this.highestLevel = 'bronze',
    this.moderationStrikeCount = 0,
    this.tempBlockedUntil,
    this.moderationBlockCountToday = 0,
    this.lastBlockedAt,
    this.isIndefiniteBlocked = false,
    this.appealExplanation,
    this.isAppealPending = false,
  });

  ProfileModel copyWith({
    String? id,
    String? fullName,
    String? profession,
    String? companyName,
    String? avatarUrl,
    int? creditBalance,
    bool? profileCompleted,
    bool? isVerified,
    String? role,
    DateTime? createdAt,
    int? discussionCount,
    int? listingCount,
    bool? isAdmin,
    bool? isBanned,
    DateTime? bannedAt,
    String? verificationDocUrl,
    String? verificationStatus,
    String? highestLevel,
    int? moderationStrikeCount,
    DateTime? tempBlockedUntil,
    int? moderationBlockCountToday,
    DateTime? lastBlockedAt,
    bool? isIndefiniteBlocked,
    String? appealExplanation,
    bool? isAppealPending,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      profession: profession ?? this.profession,
      companyName: companyName ?? this.companyName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      creditBalance: creditBalance ?? this.creditBalance,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      isVerified: isVerified ?? this.isVerified,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      discussionCount: discussionCount ?? this.discussionCount,
      listingCount: listingCount ?? this.listingCount,
      isAdmin: isAdmin ?? this.isAdmin,
      isBanned: isBanned ?? this.isBanned,
      bannedAt: bannedAt ?? this.bannedAt,
      verificationDocUrl: verificationDocUrl ?? this.verificationDocUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      highestLevel: highestLevel ?? this.highestLevel,
      moderationStrikeCount: moderationStrikeCount ?? this.moderationStrikeCount,
      tempBlockedUntil: tempBlockedUntil ?? this.tempBlockedUntil,
      moderationBlockCountToday: moderationBlockCountToday ?? this.moderationBlockCountToday,
      lastBlockedAt: lastBlockedAt ?? this.lastBlockedAt,
      isIndefiniteBlocked: isIndefiniteBlocked ?? this.isIndefiniteBlocked,
      appealExplanation: appealExplanation ?? this.appealExplanation,
      isAppealPending: isAppealPending ?? this.isAppealPending,
    );
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'],
      fullName: json['full_name'],
      profession: json['profession'],
      companyName: json['company_name'],
      avatarUrl: json['avatar_url'],
      creditBalance: json['credit_balance'] ?? 0,
      profileCompleted: json['profile_completed'] ?? false,
      isVerified: json['is_verified'] ?? false,
      role: json['role'] ?? 'user',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      discussionCount: json['discussion_count'] ?? 0,
      listingCount: json['listing_count'] ?? 0,
      isAdmin: json['is_admin'] ?? false,
      isBanned: json['is_banned'] ?? false,
      bannedAt: json['banned_at'] != null ? DateTime.parse(json['banned_at']) : null,
      verificationDocUrl: json['verification_doc_url'],
      verificationStatus: json['verification_status'] ?? 'unverified',
      highestLevel: json['highest_level'] ?? 'bronze',
      moderationStrikeCount: json['moderation_strike_count'] ?? 0,
      tempBlockedUntil: json['temp_blocked_until'] != null ? DateTime.parse(json['temp_blocked_until']) : null,
      moderationBlockCountToday: json['moderation_block_count_today'] ?? 0,
      lastBlockedAt: json['last_blocked_at'] != null ? DateTime.parse(json['last_blocked_at']) : null,
      isIndefiniteBlocked: json['is_indefinite_blocked'] ?? false,
      appealExplanation: json['appeal_explanation'],
      isAppealPending: json['is_appeal_pending'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'profession': profession,
      'company_name': companyName,
      'avatar_url': avatarUrl,
      'credit_balance': creditBalance,
      'profile_completed': profileCompleted,
      'is_verified': isVerified,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
      'is_admin': isAdmin,
      'is_banned': isBanned,
      'banned_at': bannedAt?.toIso8601String(),
      'verification_doc_url': verificationDocUrl,
      'verification_status': verificationStatus,
      'highest_level': highestLevel,
      'moderation_strike_count': moderationStrikeCount,
      'temp_blocked_until': tempBlockedUntil?.toIso8601String(),
      'moderation_block_count_today': moderationBlockCountToday,
      'last_blocked_at': lastBlockedAt?.toIso8601String(),
      'is_indefinite_blocked': isIndefiniteBlocked,
      'appeal_explanation': appealExplanation,
      'is_appeal_pending': isAppealPending,
    };
  }
}
