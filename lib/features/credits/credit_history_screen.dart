import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import 'credit_provider.dart';

class CreditHistoryScreen extends ConsumerStatefulWidget {
  const CreditHistoryScreen({super.key});

  @override
  ConsumerState<CreditHistoryScreen> createState() => _CreditHistoryScreenState();
}

class _CreditHistoryScreenState extends ConsumerState<CreditHistoryScreen> {

  @override
  Widget build(BuildContext context) {
    final logsState = ref.watch(creditLogsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'credits_history'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
            onSelected: (value) {
              ref.read(creditLogsProvider.notifier).setCategoryFilter(value == 'none' ? null : value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(enabled: false, child: Text('Kategoriye Göre Filtrele', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
              const PopupMenuItem(value: 'none', child: Text('Tüm Kategoriler', style: TextStyle(color: AppTheme.actionBlue, fontWeight: FontWeight.bold))),
              const PopupMenuItem(value: 'discussion', child: Text('Tartışmalar')),
              const PopupMenuItem(value: 'consultation', child: Text('Danışmalar')),
              const PopupMenuItem(value: 'message', child: Text('Mesajlar')),
              const PopupMenuItem(value: 'survey', child: Text('Anketler')),
              const PopupMenuItem(value: 'listing', child: Text('İlanlar')),
              const PopupMenuItem(value: 'referral', child: Text('Referanslar')),
              const PopupMenuItem(value: 'other', child: Text('Diğer')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTypeFilters(logsState),
          Expanded(child: _buildLogsList(logsState)),
        ],
      ),
    );
  }

  Widget _buildTypeFilters(CreditLogsState state) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildTypeChip('common_all'.tr(), 'all', state.filter),
            const SizedBox(width: 8),
            _buildTypeChip('credits_earnings'.tr(), 'earn', state.filter),
            const SizedBox(width: 8),
            _buildTypeChip('credits_spendings'.tr(), 'spend', state.filter),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String value, String currentValue) {
    final isActive = value == currentValue;
    return GestureDetector(
      onTap: () => ref.read(creditLogsProvider.notifier).setFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.actionBlue : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isActive ? AppTheme.actionBlue : Colors.grey[200]!),
          boxShadow: isActive ? [BoxShadow(color: AppTheme.actionBlue.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Text(
          label,
          style: TextStyle(color: isActive ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildLogsList(CreditLogsState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'credits_no_transactions'.tr(),
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            if (state.filter != 'all' || state.categoryFilter != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref.read(creditLogsProvider.notifier).setFilter('all');
                },
                child: const Text('Filtreleri Temizle'),
              ),
            ],
          ],
        ),
      );
    }

    // Gruplandırma yapalım
    final groupedLogs = _groupLogsByMonth(state.logs);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: groupedLogs.length,
      itemBuilder: (context, index) {
        final group = groupedLogs[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMonthHeader(group.monthName, group.totalEarned, group.totalSpent),
            ...group.logs.map((log) => _buildLogItem(log)),
          ],
        );
      },
    );
  }

  Widget _buildMonthHeader(String month, int earned, int spent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Text(
            month,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 20, color: AppTheme.primaryNavy),
          const Spacer(),
          Text(
            '+$earned',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Text(
            '-$spent',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final amount = (log['amount'] ?? 0) as int;
    final type = log['type'] as String? ?? (amount >= 0 ? 'earn' : 'spend');
    final action = (log['action'] ?? '') as String;
    final createdAt = log['created_at'] as String?;
    
    final isEarn = type == 'earn';
    final color = isEarn ? Colors.green : Colors.red;
    final prefix = isEarn ? '+' : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getIconColor(action).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getIcon(action), color: _getIconColor(action), size: 24),
        ),
        title: Text(
          _getActionTitle(action),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _formatDateTime(createdAt),
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ),
        trailing: Text(
          '$prefix$amount',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String action) {
    switch (action) {
      case 'survey_vote': return Icons.bar_chart_rounded;
      case 'discussion_reply': return Icons.chat_bubble_outline_rounded;
      case 'consultation_reply': return Icons.psychology_outlined;
      case 'app_review': return Icons.star_outline_rounded;
      case 'friend_referral': return Icons.person_add_outlined;
      case 'survey_create': return Icons.add_chart_rounded;
      case 'listing_create': return Icons.campaign_outlined;
      case 'discussion_create': return Icons.forum_outlined;
      case 'consultation_ask': return Icons.help_outline_rounded;
      case 'chat_message': return Icons.send_outlined;
      default: return Icons.history_rounded;
    }
  }

  Color _getIconColor(String action) {
    switch (action) {
      case 'survey_vote': return Colors.blue;
      case 'discussion_reply': return Colors.purple;
      case 'consultation_reply': return Colors.teal;
      case 'app_review': return Colors.orange;
      case 'friend_referral': return Colors.pink;
      case 'listing_create': return Colors.red;
      case 'chat_message': return Colors.indigo;
      default: return AppTheme.actionBlue;
    }
  }

  String _getActionTitle(String action) {
    switch (action) {
      case 'survey_vote': return 'Ankete oy verdiniz';
      case 'discussion_reply': return 'Tartışmaya cevap verdiniz';
      case 'consultation_reply': return 'Danışmaya cevap verdiniz';
      case 'app_review': return 'Uygulama hakkında yorum yaptınız';
      case 'friend_referral': return 'Arkadaşınızı önerdiniz';
      case 'survey_create': return 'Anket oluşturdunuz';
      case 'listing_create': return 'İlan yayınladınız';
      case 'discussion_create': return 'Tartışma başlattınız';
      case 'consultation_ask': return 'Bir uzmana danıştınız';
      case 'chat_message': return 'Mesaj gönderdiniz';
      default: return action;
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      
      final isToday = date.day == now.day && date.month == now.month && date.year == now.year;
      final isYesterday = date.day == now.day - 1 && date.month == now.month && date.year == now.year;
      
      final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      
      if (isToday) return 'Bugün, $timeStr';
      if (isYesterday) return 'Dün, $timeStr';
      
      return '${date.day} ${_getMonthName(date.month)} ${date.year}, $timeStr';
    } catch (e) {
      return dateStr;
    }
  }

  String _getMonthName(int month) {
    const months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return months[month - 1];
  }

  List<_MonthGroup> _groupLogsByMonth(List<Map<String, dynamic>> logs) {
    final Map<String, _MonthGroup> groups = {};
    
    for (final log in logs) {
      final createdAt = log['created_at'] as String?;
      if (createdAt == null) continue;
      
      try {
        final date = DateTime.parse(createdAt);
        final key = '${date.year}-${date.month}';
        
        if (!groups.containsKey(key)) {
          groups[key] = _MonthGroup(
            monthName: '${_getMonthName(date.month)} ${date.year}',
            logs: [],
          );
        }
        
        groups[key]!.logs.add(log);
        
        final amount = (log['amount'] ?? 0) as int;
        // Tip bilgisi yoksa tutardan çıkarım yap
        final type = log['type'] as String? ?? (amount >= 0 ? 'earn' : 'spend');
        
        if (type == 'earn') {
          groups[key]!.totalEarned += amount;
        } else {
          groups[key]!.totalSpent += amount.abs();
        }
      } catch (e) {
        continue;
      }
    }
    
    // Ayları kronolojik olarak tersten sıralayalım (En yeni en üstte)
    final sortedGroups = groups.values.toList()
      ..sort((a, b) {
        // monthName formatı "Mayıs 2024", bu yüzden basit string karşılaştırması yetmez.
        // Ama biz zaten keyleri 'YYYY-M' şeklinde oluşturduk, o yüzden keyleri saklayıp sıralayabilirdik.
        // Şimdilik logs'un içindeki tarihlere güvenelim.
        if (a.logs.isEmpty || b.logs.isEmpty) return 0;
        final dateA = DateTime.parse(a.logs.first['created_at']);
        final dateB = DateTime.parse(b.logs.first['created_at']);
        return dateB.compareTo(dateA);
      });
    
    return sortedGroups;
  }
}

class _MonthGroup {
  final String monthName;
  final List<Map<String, dynamic>> logs;
  int totalEarned = 0;
  int totalSpent = 0;

  _MonthGroup({required this.monthName, required this.logs});
}
