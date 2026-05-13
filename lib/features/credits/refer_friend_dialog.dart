import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/referral_repository.dart';
import '../../data/supabase/credit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home/home_provider.dart';

class ReferFriendDialog extends ConsumerStatefulWidget {
  const ReferFriendDialog({super.key});

  @override
  ConsumerState<ReferFriendDialog> createState() => _ReferFriendDialogState();
}

class _ReferFriendDialogState extends ConsumerState<ReferFriendDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen ad soyad girin')),
      );
      return;
    }

    if (email.isEmpty && phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen e-posta veya telefon numarası girin')),
      );
      return;
    }

    setState(() => _loading = true);

    final repo = ref.read(referralRepositoryProvider);
    final success = await repo.referFriend(
      name: name,
      email: email.isNotEmpty ? email : null,
      phone: phone.isNotEmpty ? phone : null,
    );

    if (!mounted) return;

    if (success) {
      // Kredi ver
      await ref.read(creditServiceProvider).processCreditAction(
        actionKey: 'friend_referral',
        description: '$name kişisini önerdiniz',
      );

      // Email girilmişse otomatik davet maili gönder
      if (email.isNotEmpty) {
        try {
          final profile = ref.read(homeProvider).value?.profile;
          final referrerName = profile?.fullName ?? 'Bir meslektaşınız';
          await Supabase.instance.client.functions.invoke(
            'send-referral-email',
            body: {
              'candidate_email': email,
              'candidate_name': name,
              'referrer_name': referrerName,
              'type': 'friend_referral',
            },
          );
        } catch (_) {
          // Email gönderilemese bile referans kaydedildi
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(email.isNotEmpty
                ? 'Arkadaşınız önerildi ve davet e-postası gönderildi! +2 Kredi kazandınız 🎉'
                : 'Arkadaşınız önerildi! +2 Kredi kazandınız 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Öneri kaydedilemedi'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person_add_rounded, color: Colors.green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Arkadaşını Öner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy)),
                        Text('Her öneri için +2 Kredi kazanın!', style: TextStyle(color: Colors.green, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Ad Soyad
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Ad Soyad *',
                  hintText: 'Arkadaşınızın adı soyadı',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.actionBlue, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // E-posta
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-posta Adresi',
                  hintText: 'ornek@mail.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.actionBlue, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Telefon
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Cep Telefonu',
                  hintText: '05XX XXX XX XX',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.actionBlue, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Text('* En az biri (e-posta veya telefon) zorunludur', style: TextStyle(color: Colors.grey[500], fontSize: 11)),

              const SizedBox(height: 20),

              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Öner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
