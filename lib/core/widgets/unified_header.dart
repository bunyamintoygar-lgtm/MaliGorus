import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/auth_repository.dart';
import './profession_label.dart';

class UnifiedHeader extends ConsumerWidget {
  final ProfileModel? profile;
  final bool isAdmin;

  const UnifiedHeader({super.key, this.profile, this.isAdmin = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 20,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1a237e), Color(0xFF3949ab), Color(0xFF1a237e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    backgroundImage: profile?.avatarUrl != null ? NetworkImage(profile!.avatarUrl!) : null,
                    child: profile?.avatarUrl == null 
                        ? const Icon(Icons.person, color: Colors.white70, size: 28) 
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile?.fullName ?? '...',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (profile?.profession != null)
                          ProfessionLabel(
                            professionId: profile!.profession,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isAdmin) ...[
            _buildHeaderIconButton(
              icon: Icons.admin_panel_settings_rounded,
              onTap: () => context.push('/admin/dashboard'),
              iconColor: Colors.amber[300],
            ),
            const SizedBox(width: 8),
          ],
          _buildHeaderIconButton(
            icon: Icons.people_alt_rounded,
            onTap: () => context.push('/participants'),
          ),
          const SizedBox(width: 8),
          _buildHeaderIconButton(
            icon: Icons.person_outline_rounded,
            onTap: () => context.push('/profile'),
          ),
          const SizedBox(width: 8),
          _buildHeaderIconButton(
            icon: Icons.power_settings_new_rounded,
            onTap: () => _showLogoutDialog(context, ref),
            iconColor: Colors.redAccent[100],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({required IconData icon, required VoidCallback onTap, Color? iconColor}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: iconColor ?? Colors.white, size: 20),
        onPressed: onTap,
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // İkon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.power_settings_new_rounded, color: Color(0xFFF44336), size: 40),
              ),
              const SizedBox(height: 24),
              // Başlık
              const Text(
                'Oturumu Kapat',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A237E)),
              ),
              const SizedBox(height: 8),
              // Açıklama
              Text(
                'Oturumu kapatmak istediğinize emin misiniz?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 24),
              // Bilgi Kutusu
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F9FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: Color(0xFF1976D2), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Güvenliğiniz için oturumu kapattıktan sonra hesabınıza tekrar giriş yapmanız gerekecektir.',
                        style: TextStyle(fontSize: 13, color: const Color(0xFF1976D2), height: 1.4, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Vazgeç', style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF44336),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Çıkış Yap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }
}

class SliverUnifiedHeader extends StatelessWidget {
  final ProfileModel? profile;
  final bool isAdmin;

  const SliverUnifiedHeader({super.key, this.profile, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: UnifiedHeader(profile: profile, isAdmin: isAdmin),
    );
  }
}
