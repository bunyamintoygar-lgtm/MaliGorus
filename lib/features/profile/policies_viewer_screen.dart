import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'dart:convert';
import '../../core/theme/app_theme.dart';

final policiesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('app_config')
      .select('key, value');
  
  final List<Map<String, dynamic>> processed = [];
  for (var item in response) {
    var value = item['value'];
    if (value is String && (value.startsWith('{') || value.startsWith('['))) {
      try {
        value = json.decode(value);
      } catch (_) {}
    }
    processed.add({
      'key': item['key'],
      'value': value,
    });
  }
  return processed;
});

class PoliciesViewerScreen extends ConsumerWidget {
  const PoliciesViewerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policiesAsync = ref.watch(policiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Politikalar ve Sözleşmeler'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: policiesAsync.when(
        data: (policies) {
          if (policies.isEmpty) {
            return const Center(child: Text('Henüz politika eklenmemiş.'));
          }
          
          final policyKeys = {
            'privacy_policy': 'Gizlilik Politikası',
            'terms_of_service': 'Kullanım Koşulları',
            'kvkk': 'KVKK Aydınlatma Metni',
            'cookie_policy': 'Çerez Politikası',
            'membership_agreement': 'Üyelik Sözleşmesi',
          };

          final availablePolicies = policies.where((p) => policyKeys.containsKey(p['key'])).toList();
          
          if (availablePolicies.isEmpty) {
            return const Center(child: Text('Gösterilecek politika bulunamadı.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: availablePolicies.length,
            itemBuilder: (context, index) {
              final policy = availablePolicies[index];
              final key = policy['key'] as String;
              final valueRaw = policy['value'];
              final Map<String, dynamic> value = valueRaw is Map ? Map<String, dynamic>.from(valueRaw) : {};
              final content = value['content'] as String? ?? '';
              
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.description_outlined, color: AppTheme.primaryNavy, size: 20),
                  ),
                  title: Text(
                    policyKeys[key] ?? key,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryNavy),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PolicyDetailScreen(
                          title: policyKeys[key] ?? key,
                          content: content,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata oluştu. İnternet bağlantınızı kontrol edin.')),
      ),
    );
  }
}

class PolicyDetailScreen extends StatelessWidget {
  final String title;
  final String content;

  const PolicyDetailScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: content.isEmpty
          ? const Center(child: Text('İçerik bulunamadı.'))
          : Markdown(
              data: content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
                h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, height: 2),
                h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, height: 2),
                h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, height: 2),
                listBullet: const TextStyle(fontSize: 14, height: 1.6),
                blockquote: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic),
                blockquoteDecoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(left: BorderSide(color: AppTheme.primaryNavy, width: 4)),
                ),
              ),
            ),
    );
  }
}
class StandalonePolicyScreen extends ConsumerWidget {
  final String slug;
  const StandalonePolicyScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policiesAsync = ref.watch(policiesProvider);

    return policiesAsync.when(
      data: (policies) {
        final policyKeys = {
          'privacy_policy': 'Gizlilik Politikası',
          'terms_of_service': 'Kullanım Koşulları',
          'kvkk': 'KVKK Aydınlatma Metni',
          'cookie_policy': 'Çerez Politikası',
          'membership_agreement': 'Üyelik Sözleşmesi',
        };

        final policy = policies.firstWhere(
          (p) => p['key'] == slug,
          orElse: () => {'key': slug, 'value': {'content': ''}},
        );

        final valueRaw = policy['value'];
        final Map<String, dynamic> value = valueRaw is Map ? Map<String, dynamic>.from(valueRaw) : {};
        final content = value['content'] as String? ?? '';

        return PolicyDetailScreen(
          title: policyKeys[slug] ?? slug,
          content: content,
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Hata oluştu: $err'))),
    );
  }
}
