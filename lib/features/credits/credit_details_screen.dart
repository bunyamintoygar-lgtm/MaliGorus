import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'credit_provider.dart';
import '../home/home_provider.dart';
import '../../core/theme/app_theme.dart';

class CreditDetailsScreen extends ConsumerWidget {
  const CreditDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final logsState = ref.watch(creditLogsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text('credits_title'.tr()),
          backgroundColor: AppTheme.primaryNavy,
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: AppTheme.creditGold,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'credits_transactions'.tr()),
              Tab(text: 'credits_packages'.tr()),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildBalanceHeader(homeState.value?.profile?.creditBalance ?? 0),
            Expanded(
              child: TabBarView(
                children: [
                  if (logsState.loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    _CreditLogsList(logs: logsState.logs),
                  const _CreditPackagesList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceHeader(int balance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: const BoxDecoration(
        color: AppTheme.primaryNavy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Text('credits_current_balance'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars_rounded, color: AppTheme.creditGold, size: 40),
              const SizedBox(width: 12),
              Text(
                '$balance',
                style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreditLogsList extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const _CreditLogsList({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return Center(child: Text('credits_no_transactions'.tr()));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final amount = log['amount'] as int;
        final isEarned = amount > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isEarned ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                child: Icon(
                  isEarned ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: isEarned ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log['description'] ?? log['action'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(log['created_at'].toString().substring(0, 16), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              Text(
                (isEarned ? '+' : '') + amount.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isEarned ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CreditPackagesList extends StatelessWidget {
  const _CreditPackagesList();

  @override
  Widget build(BuildContext context) {
    final packages = [
      {'kredi': '100 Kredi', 'price': '₺49,99', 'isPopular': false},
      {'kredi': '250 Kredi', 'price': '₺99,99', 'isPopular': true},
      {'kredi': '500 Kredi', 'price': '₺179,99', 'isPopular': false},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: packages.length,
      itemBuilder: (context, index) {
        final p = packages[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (p['isPopular'] as bool) ? AppTheme.actionBlue : Colors.grey[200]!, width: 2),
          ),
          child: Row(
            children: [
              const Icon(Icons.stars_rounded, color: AppTheme.creditGold, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('credits_package_amount'.tr(args: [p['kredi'].toString().split(' ').first]), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  if (p['isPopular'] as bool)
                    Text('credits_popular'.tr(), style: TextStyle(color: AppTheme.actionBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.actionBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(p['price'] as String, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }
}
