import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../home/main_shell.dart';

class MarketBottomNavigationBar extends ConsumerWidget {
  const MarketBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BottomNavigationBar(
      currentIndex: 0, // Giriş (Home) tab is index 0
      onTap: (index) {
        ref.read(mainTabIndexProvider.notifier).setTab(index);
        context.go('/home');
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.actionBlue,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: [
        BottomNavigationBarItem(icon: const Icon(Icons.home_filled), label: 'home'.tr()),
        BottomNavigationBarItem(icon: const Icon(Icons.chat_bubble_outline_rounded), label: 'discussions'.tr()),
        BottomNavigationBarItem(icon: const Icon(Icons.psychology_alt_rounded), label: 'discussions_consultation'.tr()),
        BottomNavigationBarItem(icon: const Icon(Icons.poll_rounded), label: 'surveys'.tr()),
        BottomNavigationBarItem(icon: const Icon(Icons.list_alt_rounded), label: 'listings'.tr()),
        BottomNavigationBarItem(icon: const Icon(Icons.message_outlined), label: 'messages'.tr()),
      ],
    );
  }
}
