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

          return Markdown(
            data: content,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
              h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, height: 2),
              h2: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, height: 2),
              listBullet: const TextStyle(fontSize: 15, height: 1.6),
            ),
          );
        },
      ),
    );
  }
}
