import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../data/supabase/credit_service.dart';
import '../profile/profile_provider.dart';
import 'credit_gift_provider.dart';
import '../../core/providers/app_config_provider.dart';


class CreditGiftScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;

  const CreditGiftScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  ConsumerState<CreditGiftScreen> createState() => _CreditGiftScreenState();
}

class _CreditGiftScreenState extends ConsumerState<CreditGiftScreen> {
  int? _selectedAmount;
  bool _isLoading = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_selectedAmount == null) return;
    final amount = _selectedAmount!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kredi Gönder'),
        content: Text('$amount kredi sizden düşerek hediye edilecektir, emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.creditGold, foregroundColor: Colors.white),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final success = await ref.read(creditServiceProvider).giftCredits(
      receiverId: widget.userId,
      amount: amount,
    );
    setState(() => _isLoading = false);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('credit_gift_success'.tr(args: [amount.toString()]))),
      );
      setState(() {
        _selectedAmount = null;
      });
      ref.invalidate(giftLogsProvider(widget.userId));
      ref.invalidate(profileProvider); // Bakiyeyi güncellemek için
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hediye gönderilemedi. Bakiyenizi kontrol edin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final logsAsync = ref.watch(giftLogsProvider(widget.userId));
    final authorAsync = ref.watch(authorProfileProvider(widget.userId));
    final configAsync = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('credit_gift_title'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info (Recipient)
            authorAsync.when(
              data: (author) {
                if (author == null) return const SizedBox.shrink();
                
                final professionLabel = configAsync.maybeWhen(
                  data: (config) {
                    final professionsRaw = config['professions'] ?? config['profession'];
                    List<dynamic> professions = [];
                    if (professionsRaw is List) {
                      professions = professionsRaw;
                    } else if (professionsRaw is Map) {
                      professions = professionsRaw.values.toList();
                    }
                    
                    for (var p in professions) {
                      if (p is Map) {
                        final id = (p['id'] ?? p['ID'] ?? p['value'] ?? '').toString().trim().toUpperCase();
                        final currentProf = author.profession?.trim().toUpperCase() ?? '';
                        if (id == currentProf) {
                          return (p['label'] ?? p['name'] ?? author.profession ?? '').toString();
                        }
                      }
                    }
                    return author.profession ?? '';
                  },
                  orElse: () => author.profession ?? '',
                );

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.creditGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.creditGold.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.creditGold.withValues(alpha: 0.3), width: 2),
                          image: author.avatarUrl != null 
                            ? DecorationImage(image: NetworkImage(author.avatarUrl!), fit: BoxFit.cover)
                            : null,
                        ),
                        child: author.avatarUrl == null
                            ? Center(child: Text(author.fullName?[0].toUpperCase() ?? '?', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.creditGold, fontSize: 20)))
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              author.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryNavy),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              professionLabel.toUpperCase(),
                              style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => Container(
                height: 92,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),

            // Amount Selection
            Text(
              'credit_gift_amount'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 16),
            
            profileAsync.when(
              data: (myProfile) {
                final myBalance = myProfile?.creditBalance ?? 0;
                final amounts = [10, 20, 50, 100, 500];

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: amounts.map((amt) {
                    final isEnabled = myBalance >= amt;
                    final isSelected = _selectedAmount == amt;

                    return InkWell(
                      onTap: isEnabled ? () => setState(() => _selectedAmount = amt) : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.creditGold : (isEnabled ? Colors.grey[50] : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.creditGold : (isEnabled ? Colors.grey[200]! : Colors.grey[200]!),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '$amt',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSelected ? Colors.white : (isEnabled ? AppTheme.primaryNavy : Colors.grey[400]),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => const Text('Bakiye yüklenemedi'),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading || _selectedAmount == null ? null : _handleSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.creditGold,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'credit_gift_send'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
            
            const SizedBox(height: 12),
            Center(
              child: profileAsync.when(
                data: (p) => Text(
                  'credit_gift_balance'.tr(args: [p?.creditBalance.toString() ?? '0']),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),

            const SizedBox(height: 48),

            // History
            Text(
              'credit_gift_history'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 16),
            logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(Icons.history_rounded, size: 48, color: Colors.grey[200]),
                          const SizedBox(height: 12),
                          Text(
                            'credit_gift_empty_history'.tr(), 
                            style: TextStyle(color: Colors.grey[400], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final date = DateTime.parse(log['created_at']);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_upward_rounded, color: Colors.green[700], size: 20),
                      ),
                      title: Text(
                        '${log['amount']} Kredi',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                      subtitle: Text(DateFormat('dd MMMM yyyy, HH:mm').format(date)),
                    );
                  },
                );
              },
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'credit_gift_empty_history'.tr(), // Loading sırasında da bunu gösterelim veya şeffaf kalsın
                    style: TextStyle(color: Colors.grey[300], fontSize: 14),
                  ),
                ),
              ),
              error: (err, _) => Text('Hata: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
