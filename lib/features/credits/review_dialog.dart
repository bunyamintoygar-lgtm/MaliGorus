import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/referral_repository.dart';
import '../../data/supabase/credit_service.dart';

class ReviewDialog extends ConsumerStatefulWidget {
  const ReviewDialog({super.key});

  @override
  ConsumerState<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<ReviewDialog> {
  final _controller = TextEditingController();
  int _rating = 0;
  bool _loading = false;
  bool _hasExistingReview = false;

  @override
  void initState() {
    super.initState();
    _loadExistingReview();
  }

  Future<void> _loadExistingReview() async {
    final review = await ref.read(referralRepositoryProvider).getMyReview();
    if (review != null && mounted) {
      setState(() {
        _controller.text = review['review_text'] ?? '';
        _rating = review['rating'] ?? 0;
        _hasExistingReview = true;
      });
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir puan verin')),
      );
      return;
    }
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen yorumunuzu yazın')),
      );
      return;
    }

    setState(() => _loading = true);

    final repo = ref.read(referralRepositoryProvider);
    final success = await repo.submitReview(
      text: _controller.text.trim(),
      rating: _rating,
    );

    if (!mounted) return;

    if (success) {
      // İlk kez yorum yapıyorsa kredi ver
      if (!_hasExistingReview) {
        await ref.read(creditServiceProvider).processCreditAction(
          actionKey: 'app_review',
          description: 'Uygulama yorumu yapıldı',
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_hasExistingReview
                ? 'Yorumunuz güncellendi!'
                : 'Yorumunuz kaydedildi! +5 Kredi kazandınız 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yorum kaydedilemedi'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.rate_review_rounded, color: Colors.amber, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasExistingReview ? 'Yorumunuzu Güncelleyin' : 'Uygulama Hakkında Yorum Yapın',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                        ),
                        if (!_hasExistingReview)
                          Text('İlk yorumunuz için +5 Kredi kazanın!', style: TextStyle(color: Colors.green[600], fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Yıldız seçimi
              const Text('Puanınız', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    onPressed: () => setState(() => _rating = i + 1),
                    icon: Icon(
                      i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 36,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Yorum alanı
              TextField(
                controller: _controller,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'MaliGörüş hakkında düşüncelerinizi paylaşın...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.actionBlue, width: 2),
                  ),
                ),
              ),

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
                        backgroundColor: AppTheme.actionBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_hasExistingReview ? 'Güncelle' : 'Gönder', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
