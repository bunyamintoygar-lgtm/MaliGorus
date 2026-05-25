import 'package:flutter/material.dart';

/// String ikon isimlerini Flutter Material IconData'ya çevirir.
/// app_config JSON'daki 'icon' alanları bu helper ile çözümlenir.
class MarketIconHelper {
  static const Map<String, IconData> _iconMap = {
    // Genel
    'category': Icons.category_outlined,
    'label': Icons.label_outline,
    'more_horiz': Icons.more_horiz,

    // Doküman / Şablon
    'description': Icons.description_outlined,
    'folder_open': Icons.folder_open_outlined,
    'article': Icons.article_outlined,
    'file_copy': Icons.file_copy_outlined,
    'edit_note': Icons.edit_note,
    'receipt_long': Icons.receipt_long_outlined,
    'table_chart': Icons.table_chart_outlined,
    'bar_chart': Icons.bar_chart,
    'assessment': Icons.assessment_outlined,

    // İş / Hukuk / Finans
    'handshake': Icons.handshake_outlined,
    'account_balance': Icons.account_balance_outlined,
    'gavel': Icons.gavel,
    'announcement': Icons.announcement_outlined,
    'menu_book': Icons.menu_book_outlined,
    'balance': Icons.balance_outlined,
    'percent': Icons.percent,
    'calculate': Icons.calculate_outlined,
    'trending_up': Icons.trending_up,
    'business': Icons.business_outlined,
    'verified': Icons.verified_outlined,
    'workspace_premium': Icons.workspace_premium_outlined,

    // Eğitim / Gelişim
    'school': Icons.school_outlined,
    'psychology': Icons.psychology_outlined,
    'computer': Icons.computer_outlined,
    'functions': Icons.functions,
    'analytics': Icons.analytics_outlined,
    'auto_awesome': Icons.auto_awesome_outlined,
    'stars': Icons.stars_outlined,

    // Danışmanlık / Destek
    'support_agent': Icons.support_agent_outlined,

    // Araçlar
    'construction': Icons.construction_outlined,
    'inventory_2': Icons.inventory_2_outlined,
    'build': Icons.build_outlined,
  };

  /// String ikon adından IconData döner. Bulunamazsa varsayılan ikon kullanılır.
  static IconData get(String iconName, {IconData fallback = Icons.category_outlined}) {
    return _iconMap[iconName] ?? fallback;
  }

  /// Hex renk kodundan (ör: '4F46E5') Color nesnesi üretir.
  static Color colorFromHex(String hex) {
    try {
      final sanitized = hex.replaceAll('#', '');
      return Color(int.parse('FF$sanitized', radix: 16));
    } catch (_) {
      return const Color(0xFF4F46E5);
    }
  }
}
