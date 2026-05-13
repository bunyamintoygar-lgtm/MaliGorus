import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/home_provider.dart';
import '../../data/supabase/file_service.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/models/profile_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/profession_label.dart';
import '../../core/widgets/level_badge.dart';
import '../../data/models/level_model.dart';
import '../../core/providers/app_config_provider.dart';
import '../../core/services/moderation_service.dart';
import '../../core/utils/moderation_ui.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final user = homeState.value?.profile;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('profile'.tr()),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.primaryNavy,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/profile-completion'),
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: Text('common_edit'.tr()),
            style: TextButton.styleFrom(foregroundColor: AppTheme.actionBlue),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(context, user),
            const SizedBox(height: 32),
            _buildLevelCard(context, ref, user),
            const SizedBox(height: 32),
            _buildSettingsList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ProfileModel? user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
          backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
          child: user?.avatarUrl == null ? const Icon(Icons.person, size: 50, color: AppTheme.primaryNavy) : null,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              user?.fullName ?? 'common_user'.tr(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (user?.highestLevel != null) ...[
              const SizedBox(width: 8),
              LevelBadge(levelKey: user!.highestLevel, size: 16),
            ],
          ],
        ),
        const SizedBox(height: 4),
        ProfessionLabel(
          professionId: user?.profession,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (user?.companyName != null && user!.companyName!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            user.companyName!,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
            ),
          ),
        ],
        if (user?.createdAt != null) ...[
          const SizedBox(height: 6),
          Text(
            '${'profile_member_since'.tr()}: ${DateFormat('MMMM yyyy').format(user!.createdAt!)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
        if (user?.id != null) ...[
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
              '${'profile_id'.tr()}: #${user!.id.substring(0, 8).toUpperCase()}',
              style: const TextStyle(
                color: AppTheme.actionBlue,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLevelCard(BuildContext context, WidgetRef ref, ProfileModel? user) {
    if (user?.highestLevel == null) return const SizedBox.shrink();
    
    final levelConfig = ref.watch(levelConfigProvider);
    
    return levelConfig.maybeWhen(
      data: (levels) {
        final currentLevel = levels.firstWhere(
          (l) {
            final k = l.key.toLowerCase();
            final search = user!.highestLevel.toLowerCase();
            return k == search || 
                   (k == 'bronze' && search == 'bronz') ||
                   (k == 'silver' && search == 'gümüş') ||
                   (k == 'gold' && search == 'altın') ||
                   (k == 'platinum' && search == 'platin');
          },
          orElse: () => levels.first,
        );
        
        final currentIndex = levels.indexOf(currentLevel);
        final nextLevel = currentIndex < levels.length - 1 ? levels[currentIndex + 1] : null;
        
        double progress = 0;
        if (nextLevel != null) {
          final range = nextLevel.minCredits - currentLevel.minCredits;
          final currentProgress = (user?.creditBalance ?? 0) - currentLevel.minCredits;
          progress = (currentProgress / range).clamp(0.0, 1.0);
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(int.parse(currentLevel.color.replaceAll('#', '0xFF'))).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      currentLevel.icon ?? '🥉',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                               'profile_current_level'.tr(),
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                            InkWell(
                              onTap: () => context.push('/credit-earn'),
                              child: Container(
                                width: 90,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B4513),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'home_earn_credits'.tr(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              currentLevel.label,
                              style: TextStyle(
                                color: Color(int.parse(currentLevel.color.replaceAll('#', '0xFF'))),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            InkWell(
                              onTap: () => _showLevelAbilities(context, levels),
                              child: Container(
                                width: 90,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.actionBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.actionBlue.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'profile_abilities'.tr(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppTheme.actionBlue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (nextLevel != null) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'profile_next_level'.tr(args: [nextLevel.label]),
                      style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'profile_credits_remaining'.tr(args: [(nextLevel.minCredits - (user?.creditBalance ?? 0)).toString()]),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(int.parse(currentLevel.color.replaceAll('#', '0xFF'))),
                    ),
                    minHeight: 8,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 20),
                Text(
                  'profile_max_level_congrats'.tr(),
                  style: const TextStyle(color: AppTheme.primaryNavy, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  void _showLevelAbilities(BuildContext context, List<LevelModel> levels) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('home_levels_and_abilities'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: levels.length,
                itemBuilder: (context, index) {
                  final level = levels[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(int.parse(level.color.replaceAll('#', '0xFF'))).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Color(int.parse(level.color.replaceAll('#', '0xFF'))).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(level.icon ?? '🎖️', style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Text(level.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text('profile_level_min_credits'.tr(args: [level.minCredits.toString()]), style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildAbilityRow(index >= 0, 'profile_ability_surveys'.tr()),
                        _buildAbilityRow(index >= 0, 'profile_ability_discussions_reply'.tr()),
                        _buildAbilityRow(index >= 0, 'profile_ability_consultation_ask'.tr()),
                        _buildAbilityRow(index >= 1, 'profile_ability_discussions_new'.tr()),
                        _buildAbilityRow(index >= 1, 'profile_ability_dm'.tr()),
                        _buildAbilityRow(index >= 1, 'profile_ability_listings_apply'.tr()),
                        _buildAbilityRow(index >= 2, 'profile_ability_surveys_new'.tr()),
                        _buildAbilityRow(index >= 2, 'profile_ability_listings_new'.tr()),
                        _buildAbilityRow(index >= 2, 'profile_ability_consultation_reply'.tr()),
                        _buildAbilityRow(index >= 3, 'profile_ability_market'.tr()),
                        _buildAbilityRow(index >= 3, 'profile_ability_gift'.tr()),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbilityRow(bool hasPermission, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            hasPermission ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: hasPermission ? Colors.green : Colors.grey[300],
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: hasPermission ? Colors.black87 : Colors.grey[400],
              decoration: hasPermission ? null : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSettingsList(BuildContext context) {
    final settings = [
      {
        'icon': Icons.person_off_rounded,
        'label': 'profile_blocked_users'.tr(),
        'subtitle': 'Engellediğiniz kullanıcıları yönetin', // tr() anahtarı varsa eklenmeli
        'route': '/blocked-users',
        'iconColor': const Color(0xFF5C6BC0)
      },
      {
        'icon': Icons.notifications_rounded,
        'label': 'profile_notification_settings'.tr(),
        'subtitle': 'Bildirim tercihlerinizi yönetin',
        'route': '/notification-settings',
        'iconColor': const Color(0xFF1A237E)
      },
      {
        'icon': Icons.security_rounded,
        'label': 'profile_security_settings'.tr(),
        'subtitle': 'Hesap güvenliğinizi sağlayın',
        'route': '/security',
        'iconColor': const Color(0xFF283593)
      },
      {
        'icon': Icons.description_rounded,
        'label': 'profile_policies'.tr(),
        'subtitle': 'Kullanım koşulları ve gizlilik politikaları',
        'route': '/policies',
        'iconColor': const Color(0xFF1A237E)
      },
      {
        'icon': Icons.help_rounded,
        'label': 'profile_help_support'.tr(),
        'subtitle': 'Sıkça sorulan sorular ve destek',
        'route': '/help-support',
        'iconColor': const Color(0xFF1976D2)
      },
      {
        'icon': Icons.info_rounded,
        'label': 'profile_about_us'.tr(),
        'subtitle': 'Hakkımızda bilgi edinin',
        'route': '/about',
        'iconColor': const Color(0xFF1565C0)
      },
    ];

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < settings.length; i++) ...[
                _buildSettingsItem(
                  context,
                  icon: settings[i]['icon'] as IconData,
                  label: settings[i]['label'] as String,
                  subtitle: settings[i]['subtitle'] as String,
                  route: settings[i]['route'] as String,
                  iconColor: settings[i]['iconColor'] as Color,
                ),
                if (i < settings.length - 1)
                  Divider(height: 1, indent: 70, color: Colors.grey[100]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildSettingsItem(
            context,
            icon: Icons.delete_outline_rounded,
            label: 'profile_delete_account'.tr(),
            subtitle: 'Hesabınızı kalıcı olarak silin',
            onTap: () => _showTerminationDialog(context),
            iconColor: Colors.red,
            isDestructive: true,
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    String? route,
    VoidCallback? onTap,
    required Color iconColor,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap ?? (route != null ? () => context.push(route) : null),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive ? Colors.red.withValues(alpha: 0.05) : iconColor.withValues(alpha: 0.05),
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
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDestructive ? Colors.red : const Color(0xFF263238),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDestructive ? Colors.red : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showTerminationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('profile_delete_account'.tr()),
        content: Text('profile_delete_account_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _terminateMembership(context);
            },
            child: Text('profile_delete_account'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _terminateMembership(BuildContext context) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Önce SharedPreferences'a bayrak kaydet
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('show_account_deleted_dialog', true);
      } catch (_) {}

      // Veritabanı işlemini yap
      await Supabase.instance.client.rpc('terminate_user_membership', params: {
        'target_user_id': userId,
      });

      // Çıkış yap
      await Supabase.instance.client.auth.signOut();

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e')),
        );
      }
    }
  }
}
