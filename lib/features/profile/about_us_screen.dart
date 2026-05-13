import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../core/theme/app_theme.dart';

class AboutUsScreen extends ConsumerWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('profile_about_us'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: Supabase.instance.client
            .from('app_config')
            .select('value')
            .eq('key', 'about_us'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
            return Center(child: Text('about_no_content'.tr()));
          }

          final data = snapshot.data!.first;
          final value = data['value'] as Map<String, dynamic>;
          final content = value['content'] as String? ?? '';

          if (content.isEmpty) {
            return Center(child: Text('about_error_content'.tr()));
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Markdown(
                  data: content,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                    h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, height: 2),
                    h2: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, height: 2),
                    listBullet: const TextStyle(fontSize: 15, height: 1.6),
                  ),
                ),
                const _FinancialDisclaimerCard(),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FinancialDisclaimerCard extends StatelessWidget {
  const _FinancialDisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_rounded, color: Color(0xFFF57F17), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Yasal Uyarı',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFFF57F17),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'MaliGörüş, kullanıcıların finansal deneyimlerini paylaştığı bir sosyal platformdur. Uygulama içindeki hiçbir içerik yatırım tavsiyesi, finansal danışmanlık veya resmi öneri niteliği taşımaz. Finansal kararlarınız için lisanslı bir mali müşavire başvurmanızı öneririz.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5D4037),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
