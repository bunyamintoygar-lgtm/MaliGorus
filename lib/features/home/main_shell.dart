import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';
import '../surveys/survey_list_screen.dart';
import '../chat/chat_list_screen.dart';
import '../listings/listings_screen.dart';

import '../discussions/discussion_list_screen.dart';
import '../discussions/consultation_list_screen.dart';
import '../credits/level_up_dialog.dart';
import 'home_provider.dart';

// Global tab index provider — herhangi bir ekrandan sekme değişikliği yapılabilir
class MainTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

final mainTabIndexProvider = NotifierProvider<MainTabIndexNotifier, int>(MainTabIndexNotifier.new);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const List<Widget> _pages = [
    HomeScreen(),
    DiscussionListScreen(key: ValueKey('tartisma')),
    ConsultationListScreen(key: ValueKey('danisma')),
    SurveyListScreen(),
    ListingsScreen(),
    ChatListScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(mainTabIndexProvider);

    // --- Seviye Atlama Takibi (Global) ---
    ref.listen<AsyncValue<HomeState>>(homeProvider, (previous, next) {
      final oldLevel = previous?.value?.profile?.highestLevel;
      final newLevel = next.value?.profile?.highestLevel;

      if (oldLevel != null && newLevel != null && oldLevel != newLevel) {
        final levels = ['bronze', 'silver', 'gold', 'platin'];
        if (levels.indexOf(newLevel.toLowerCase()) > levels.indexOf(oldLevel.toLowerCase())) {
          // Seviye yükselmiş! Kutlamayı göster.
          _showLevelUpCelebration(context, newLevel);
        }
      }
    });

    return Scaffold(
      body: _pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => ref.read(mainTabIndexProvider.notifier).setTab(index),
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
      ),
    );
  }

  void _showLevelUpCelebration(BuildContext context, String level) {
    List<String> perks = [];
    switch (level.toLowerCase()) {
      case 'silver':
        perks = ['perks_silver_1'.tr(), 'perks_silver_2'.tr(), 'perks_silver_3'.tr()];
        break;
      case 'gold':
        perks = ['perks_gold_1'.tr(), 'perks_gold_2'.tr(), 'perks_gold_3'.tr()];
        break;
      case 'platin':
        perks = ['perks_platin_1'.tr(), 'perks_platin_2'.tr(), 'perks_platin_3'.tr()];
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LevelUpDialog(level: level, perks: perks),
    );
  }
}
