import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import 'admin_provider.dart';

class AdminListingsScreen extends ConsumerWidget {
  const AdminListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(adminListingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0,
        title: const Text('İlan Yönetimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminListingsProvider),
          ),
        ],
      ),
      body: listingsAsync.when(
        data: (listings) {
          if (listings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.list_alt_rounded, size: 64, color: Colors.grey[200]),
                  const SizedBox(height: 12),
                  Text('Henüz ilan bulunmuyor.', style: TextStyle(color: Colors.grey[400])),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: listings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildListingCard(context, ref, listings[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Hata: $err')),
      ),
    );
  }

  Widget _buildListingCard(BuildContext context, WidgetRef ref, Map<String, dynamic> listing) {
    final author = listing['author'] as Map<String, dynamic>?;
    final authorName = author?['full_name'] ?? 'Bilinmeyen';
    final title = listing['title'] ?? 'Başlıksız';
    final category = listing['category'] ?? '';
    final location = listing['location'] ?? '';
    final createdAt = listing['created_at'] != null
        ? DateFormat('dd.MM.yyyy').format(DateTime.parse(listing['created_at']))
        : '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.article_outlined, color: Colors.teal, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(category, style: TextStyle(fontSize: 11, color: Colors.teal[700], fontWeight: FontWeight.w600)),
                          ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(location, style: TextStyle(fontSize: 11, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(authorName, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const Spacer(),
              Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(createdAt, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => _deleteListing(context, ref, listing['id']),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, size: 14, color: Colors.red[400]),
                      const SizedBox(width: 4),
                      Text('Kaldır', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red[400])),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteListing(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('İlanı Kaldır'),
        content: const Text('Bu ilanı kalıcı olarak silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ref.read(adminServiceProvider).deleteListing(id);
    if (success) {
      ref.invalidate(adminListingsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İlan başarıyla kaldırıldı.'), backgroundColor: Colors.green),
      );
    }
  }
}
