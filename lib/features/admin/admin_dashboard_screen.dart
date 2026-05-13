import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import 'admin_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final growthAsync = ref.watch(adminGrowthProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F8),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Compact single-line header
          SliverAppBar(
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0D1B2A),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Admin Paneli',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // İstatistik Kartları
                  statsAsync.when(
                    data: (stats) => _buildStatsGrid(stats),
                    loading: () => _buildStatsGridPlaceholder(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 24),

                  // Kullanıcı Büyüme Grafiği
                  _buildSectionTitle('Kullanıcı Büyümesi', Icons.trending_up_rounded, Colors.blue),
                  const SizedBox(height: 12),
                  growthAsync.when(
                    data: (data) => _buildGrowthChart(data),
                    loading: () => Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (err, _) => Container(
                      height: 120,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          'Grafik yüklenemedi: $err',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Yönetim Modülleri
                  _buildSectionTitle('Yönetim Modülleri', Icons.dashboard_customize_rounded, Colors.deepPurple),
                  const SizedBox(height: 12),

                  _buildModuleCard(
                    context,
                    icon: Icons.contact_support_rounded,
                    color: Colors.cyan,
                    title: 'Destek Talepleri',
                    description: 'Kullanıcılardan gelen soruları yanıtla',
                    route: '/admin/support-requests',
                  ),

                  _buildModuleCard(
                    context,
                    icon: Icons.people_alt_rounded,
                    color: Colors.blue,
                    title: 'Kullanıcı Yönetimi',
                    description: 'Kullanıcıları görüntüle, admin ata, profilleri yönet',
                    route: '/admin/users',
                  ),

                  _buildModuleCard(
                    context,
                    icon: Icons.report_problem_rounded,
                    color: Colors.orange,
                    title: 'Şikayet Yönetimi',
                    description: 'Kullanıcı şikayetlerini incele ve yönet',
                    route: '/admin/reports',
                    badgeCount: statsAsync.value?['pending_reports'],
                  ),

                  _buildModuleCard(
                    context,
                    icon: Icons.monetization_on_rounded,
                    color: AppTheme.creditGold,
                    title: 'Kredi Konfigürasyonu',
                    description: 'Aksiyon başına kredi miktarlarını ayarla',
                    route: '/admin/config',
                  ),

                  _buildModuleCard(
                    context,
                    icon: Icons.workspace_premium_rounded,
                    color: Colors.amber,
                    title: 'Rozet Ayarları',
                    description: 'Üye seviyeleri ve rozetleri yönet',
                    route: '/admin/levels',
                  ),

                  _buildModuleCard(
                    context,
                    icon: Icons.list_alt_rounded,
                    color: Colors.teal,
                    title: 'İlan Yönetimi',
                    description: 'Aktif ilanları görüntüle ve yönet',
                    route: '/admin/listings',
                  ),
                  
                  _buildModuleCard(
                    context,
                    icon: Icons.card_giftcard_rounded,
                    color: Colors.pink,
                    title: 'Promosyon Yönetimi',
                    description: 'Kredi marketi ürünlerini yönet',
                    route: '/admin/promotions',
                  ),

                  _buildModuleCard(
                    context,
                    icon: Icons.shopping_basket_rounded,
                    color: Colors.indigo,
                    title: 'Market Talepleri',
                    description: 'Kullanıcılardan gelen satın almaları yönet',
                    route: '/admin/market-requests',
                  ),

                  _buildModuleCard(
                    context,
                    icon: Icons.campaign_rounded,
                    color: Colors.purple,
                    title: 'Duyuru Gönder',
                    description: 'Tüm kullanıcılara duyuru ve bildirim gönder',
                    route: '/admin/announcements',
                  ),

                  _buildModuleCard(
                    context,
                    icon: Icons.policy_rounded,
                    color: Colors.indigo,
                    title: 'Politikalar ve Sözleşmeler',
                    description: 'Gizlilik politikası, kullanım koşulları ve KVKK',
                    route: '/admin/policies',
                  ),

                  _buildModuleCard(
                    context,
                    icon: Icons.help_center_rounded,
                    color: Colors.deepOrange,
                    title: 'SSS Yönetimi',
                    description: 'Sıkça sorulan soruları düzenle ve yayınla',
                    route: '/admin/faqs',
                  ),



                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy)),
      ],
    );
  }

  Widget _buildStatsGrid(Map<String, int> stats) {
    final items = [
      {'value': stats['users'] ?? 0, 'icon': Icons.people_alt_rounded, 'color': Colors.blue},
      {'value': stats['discussions'] ?? 0, 'icon': Icons.forum_rounded, 'color': Colors.purple},
      {'value': stats['listings'] ?? 0, 'icon': Icons.list_alt_rounded, 'color': Colors.teal},
      {'value': stats['pending_reports'] ?? 0, 'icon': Icons.report_problem_rounded, 'color': Colors.orange},
    ];

    return Row(
      children: items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        final color = item['color'] as Color;
        final isAlert = i == 3 && (item['value'] as int) > 0;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item['icon'] as IconData, color: color, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      '${item['value']}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
                    ),
                  ],
                ),
                if (isAlert)
                  Positioned(
                    top: 0, right: 8,
                    child: Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatsGridPlaceholder() {
    return Row(
      children: List.generate(4, (i) => Expanded(
        child: Container(
          margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      )),
    );
  }

  Widget _buildGrowthChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Center(child: Text('Grafik verisi bulunamadı', style: TextStyle(color: Colors.grey[400]))),
      );
    }

    final maxY = data.fold<double>(0, (prev, e) => (e['count'] as int) > prev ? (e['count'] as int).toDouble() : prev);

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.blue.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxY + 2).ceilToDouble(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.toInt()} kayıt',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      data[index]['date'],
                      style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[100]!, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: (entry.value['count'] as int).toDouble(),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildModuleCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required String route,
    int? badgeCount,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy)),
                        if (badgeCount != null && badgeCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                            child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
