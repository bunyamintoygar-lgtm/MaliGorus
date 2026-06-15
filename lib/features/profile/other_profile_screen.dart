import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/app_config_provider.dart';
import 'profile_provider.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../core/widgets/level_badge.dart';
import '../home/home_provider.dart';
import '../../core/utils/level_permissions.dart';
import 'follower_provider.dart';
import '../../data/repositories/follower_repository.dart';

final isBlockedProvider = FutureProvider.family<bool, String>((ref, userId) async {
  final repo = ref.read(chatRepositoryProvider);
  final blockedIds = await repo.getBlockedUserIds();
  return blockedIds.contains(userId);
});

class OtherProfileScreen extends ConsumerWidget {
  final String userId;

  const OtherProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(authorProfileProvider(userId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0,
        title: Text('profile_detail'.tr()),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('error_loading'.tr(args: [err.toString()]))),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text('common_error'.tr()));
          }

          final configAsync = ref.watch(appConfigProvider);
          final professionLabel = configAsync.maybeWhen(
            data: (config) {
              final professionsRaw = config['professions'] ?? config['profession'];
              List<dynamic> professions = [];
              if (professionsRaw is List) {
                professions = professionsRaw;
              } else if (professionsRaw is Map) {
                professions = professionsRaw.values.toList();
              }
              
              if (professions.isEmpty) return profile.profession ?? '-';

              for (var p in professions) {
                if (p is Map) {
                  final id = (p['id'] ?? p['ID'] ?? p['value'] ?? '').toString().trim().toUpperCase();
                  final currentProf = profile.profession?.trim().toUpperCase() ?? '';
                  if (id == currentProf && id.isNotEmpty) {
                    return (p['label'] ?? p['name'] ?? p['title'] ?? id).toString();
                  }
                }
              }
              return profile.profession ?? '-';
            },
            orElse: () => profile.profession ?? '-',
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildHeader(context, ref, profile, professionLabel),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, ProfileModel profile, String professionLabel) {
    final initial = (profile.fullName ?? '?').isNotEmpty ? profile.fullName![0].toUpperCase() : '?';
    final joinedDate = profile.createdAt != null 
        ? DateFormat('MMMM yyyy').format(profile.createdAt!) 
        : '-';

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
          backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
          child: profile.avatarUrl == null 
              ? Text(initial, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)) 
              : null,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              profile.displayName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
            ),
            const SizedBox(width: 8),
            LevelBadge(levelKey: profile.highestLevel, size: 16),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          professionLabel.toUpperCase(),
          style: const TextStyle(color: AppTheme.actionBlue, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 1.1),
        ),
        if (profile.companyName != null && profile.companyName!.isNotEmpty) ...[
          Consumer(builder: (context, ref, child) {
            final isAdmin = ref.watch(homeProvider).value?.profile?.isAdmin ?? false;
            if (!isAdmin) return const SizedBox.shrink();
            return Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  'company_name'.tr(),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    profile.companyName!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[800], fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          }),
        ],
        const SizedBox(height: 6),
        Text(
          '${'profile_member_since'.tr()}: $joinedDate',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.actionBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.actionBlue.withValues(alpha: 0.25),
              width: 0.6,
            ),
          ),
          child: Text(
            '${'profile_id'.tr()}: #${profile.id.substring(0, 8).toUpperCase()}',
            style: const TextStyle(
              color: AppTheme.actionBlue,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Followers & Following counts
        Consumer(
          builder: (context, ref, child) {
            final countsAsync = ref.watch(followCountsProvider(profile.id));
            return countsAsync.when(
              data: (counts) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => context.push('/profile/${profile.id}/follows?tab=followers'),
                      child: Text(
                        '${counts.followersCount} Takipçi',
                        style: const TextStyle(
                          color: AppTheme.actionBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '|',
                      style: TextStyle(color: Colors.grey[300]),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => context.push('/profile/${profile.id}/follows?tab=following'),
                      child: Text(
                        '${counts.followingCount} Takip Edilen',
                        style: const TextStyle(
                          color: AppTheme.actionBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(height: 18),
              error: (_, __) => const SizedBox(height: 18),
            );
          },
        ),
        const SizedBox(height: 16),
        if (Supabase.instance.client.auth.currentUser?.id != profile.id) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Consumer(
              builder: (context, ref, child) {
                final isFollowingAsync = ref.watch(isFollowingProvider(profile.id));
                return isFollowingAsync.when(
                  data: (isFollowing) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollowing
                                ? Colors.grey[200]
                                : const Color(0xFF4A3AFF),
                            foregroundColor: isFollowing
                                ? Colors.grey[800]
                                : Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isFollowing
                                  ? BorderSide(color: Colors.grey[300]!)
                                  : BorderSide.none,
                            ),
                          ),
                          onPressed: () async {
                            final repo = ref.read(followerRepositoryProvider);
                            if (isFollowing) {
                              await repo.unfollowUser(profile.id);
                            } else {
                              await repo.followUser(profile.id);
                            }
                            ref.invalidate(isFollowingProvider(profile.id));
                            ref.invalidate(followCountsProvider(profile.id));
                            final myId = Supabase.instance.client.auth.currentUser?.id;
                            if (myId != null) {
                              ref.invalidate(followCountsProvider(myId));
                              ref.invalidate(followingListProvider(myId));
                            }
                            ref.invalidate(followersListProvider(profile.id));
                          },
                          icon: Icon(
                            isFollowing ? Icons.check : Icons.add,
                            size: 18,
                          ),
                          label: Text(
                            isFollowing ? 'Takip Ediliyor' : 'Takip Et',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Takip ederek yeni paylaşımlarını akışında görebilirsin.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Divider(indent: 40, endIndent: 40),
          const SizedBox(height: 8),
          
          // Send Message Action Card
          _buildActionCard(
            context: context,
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: AppTheme.actionBlue,
            title: 'profile_send_message'.tr(),
            description: 'profile_send_message_desc'.tr(),
            onTap: () {
              final myLevel = ref.read(homeProvider).value?.profile?.highestLevel;
              final levels = ref.read(levelConfigProvider).value ?? [];
              if (!LevelPermissions.hasPermission(myLevel, AppPermission.sendDirectMessage, levels)) {
                LevelPermissions.showAccessDeniedDialog(context, AppPermission.sendDirectMessage);
                return;
              }
              context.push('/chat/detail', extra: {
                'userId': profile.id,
                'userName': profile.displayName,
                'userAvatar': profile.avatarUrl,
                'userTitle': professionLabel,
                'userHighestLevel': profile.highestLevel,
              });
            },
          ),

          // Gift Credits
          _buildActionCard(
            context: context,
            icon: Icons.card_giftcard,
            iconColor: AppTheme.creditGold,
            title: 'profile_gift_credits'.tr(),
            description: 'profile_gift_credits_desc'.tr(),
            onTap: () {
              final myLevel = ref.read(homeProvider).value?.profile?.highestLevel;
              final levels = ref.read(levelConfigProvider).value ?? [];
              if (!LevelPermissions.hasPermission(myLevel, AppPermission.giftCredits, levels)) {
                LevelPermissions.showAccessDeniedDialog(context, AppPermission.giftCredits);
                return;
              }
              context.push('/credit-gift', extra: {
                'userId': profile.id,
                'userName': profile.displayName,
              });
            },
          ),

          // Block/Unblock
          Consumer(
            builder: (context, ref, child) {
              final isBlockedAsync = ref.watch(isBlockedProvider(profile.id));
              return isBlockedAsync.when(
                data: (isBlocked) {
                  return _buildActionCard(
                    context: context,
                    icon: isBlocked ? Icons.lock_open : Icons.block,
                    iconColor: isBlocked ? Colors.green : Colors.red,
                    title: isBlocked ? 'profile_unblock_user'.tr() : 'profile_block_user'.tr(),
                    description: isBlocked ? 'profile_unblock_user_desc'.tr() : 'profile_block_user_desc'.tr(),
                    onTap: () async {
                      final repo = ref.read(chatRepositoryProvider);
                      if (isBlocked) {
                        await repo.unblockUser(profile.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('profile_unblocked_message'.tr())));
                        }
                      } else {
                        await repo.blockUser(profile.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('profile_blocked_message'.tr())));
                        }
                      }
                      ref.invalidate(isBlockedProvider(profile.id));
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                ),
                error: (error, stack) => const SizedBox(),
              );
            },
          ),

          // Report User (at the bottom)
          _buildActionCard(
            context: context,
            icon: Icons.report_problem_outlined,
            iconColor: Colors.orange,
            title: 'profile_report_user'.tr(),
            description: 'profile_report_user_desc'.tr(),
            onTap: () => context.push('/report', extra: {
              'reportedId': profile.id,
              'reportedTitle': profile.displayName,
              'contentType': 'user',
            }),
          ),
        ]

      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }


}
