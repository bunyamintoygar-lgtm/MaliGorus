import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/level_model.dart';
import '../../data/models/profile_model.dart';

class LevelDetailsDialog extends StatelessWidget {
  final ProfileModel? profile;
  final List<LevelModel> levels;
  final int currentIndex;

  const LevelDetailsDialog({
    super.key,
    required this.profile,
    required this.levels,
    required this.currentIndex,
  });

  static void show(BuildContext context, {
    required ProfileModel? profile,
    required List<LevelModel> levels,
    required int currentIndex,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LevelDetailsDialog(
        profile: profile,
        levels: levels,
        currentIndex: currentIndex,
      ),
    );
  }

  // Bütün ayrıcalıklar sırayla listeleniyor
  static final List<Map<String, dynamic>> _allAbilities = [
    {'titleKey': 'home_ability_surveys', 'levelIndex': 0},
    {'titleKey': 'home_ability_replies', 'levelIndex': 0},
    {'titleKey': 'home_ability_ask', 'levelIndex': 0},
    {'titleKey': 'home_ability_new_discussion', 'levelIndex': 1},
    {'titleKey': 'home_ability_private_message', 'levelIndex': 1},
    {'titleKey': 'home_ability_apply_listing', 'levelIndex': 1},
    {'titleKey': 'home_ability_new_survey', 'levelIndex': 2},
    {'titleKey': 'home_ability_new_listing', 'levelIndex': 2},
    {'titleKey': 'home_ability_answer_consultation', 'levelIndex': 2},
    {'titleKey': 'home_ability_market', 'levelIndex': 3},
    {'titleKey': 'home_ability_gift', 'levelIndex': 3},
  ];

  @override
  Widget build(BuildContext context) {
    final currentLevel = levels[currentIndex];
    final nextLevel = currentIndex + 1 < levels.length ? levels[currentIndex + 1] : null;
    final int currentCredits = profile?.creditBalance ?? 0;
    
    // Calculate progress to next level
    final int nextLevelCredits = nextLevel?.minCredits ?? currentCredits;
    final int remainingCredits = (nextLevelCredits - currentCredits).clamp(0, double.infinity).toInt();
    final double progress = nextLevel == null 
      ? 1.0 
      : (currentCredits / nextLevelCredits).clamp(0.0, 1.0);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF9F6), // Açık krem/gri arka plan
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mevcut Seviye Kartı
                  _buildCurrentLevelCard(
                    context, 
                    currentLevel: currentLevel,
                    nextLevel: nextLevel,
                    currentCredits: currentCredits,
                    nextLevelCredits: nextLevelCredits,
                    remainingCredits: remainingCredits,
                    progress: progress,
                  ),

                  const SizedBox(height: 32),

                  // Sonraki Seviyeler Başlığı
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sonraki Seviyeler',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                      Text(
                        'Daha fazla ayrıcalık seni bekliyor!',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sonraki Seviye Kartları
                  ...levels.sublist(currentIndex + 1).map((level) {
                    final isNextTarget = level == nextLevel;
                    return _buildNextLevelCard(
                      context, 
                      targetLevel: level, 
                      currentLevel: currentLevel,
                      currentCredits: currentCredits,
                      isNextTarget: isNextTarget,
                      levels: levels,
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLevelCard(
    BuildContext context, {
    required LevelModel currentLevel,
    required LevelModel? nextLevel,
    required int currentCredits,
    required int nextLevelCredits,
    required int remainingCredits,
    required double progress,
  }) {
    final Color levelColor = Color(int.parse(currentLevel.color.replaceAll('#', '0xFF')));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange[50]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Icon & Info)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shield Icon Placeholder
                _buildShieldIcon(currentLevel.icon ?? '🛡️', levelColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'MEVCUT SEVİYENİZ',
                          style: TextStyle(color: Colors.orange[800], fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentLevel.label,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${currentLevel.minCredits}+ Kredi',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Progress Side
                if (nextLevel != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Sonraki seviyeye',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        '$remainingCredits kredi kaldı',
                        style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 80,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.orange[500],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$currentCredits / $nextLevelCredits',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // Welcome text
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mali Görüş topluluğuna hoş geldiniz!',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                Text(
                  'Temel özelliklerden yararlanmaya başlayın.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                
                const SizedBox(height: 24),
                
                Text(
                  'Bu seviyenin ayrıcalıkları',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange[800]),
                ),
                const SizedBox(height: 16),
                
                // Abilities Grid (2 Columns)
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 5, // Genişliğe göre satır yüksekliği oranı
                  children: _allAbilities.map((ability) {
                    final hasAbility = currentIndex >= (ability['levelIndex'] as int);
                    return _buildAbilityItem(ability['titleKey']!.toString().tr(), hasAbility);
                  }).toList(),
                ),
              ],
            ),
          ),

          // Earn Credits Banner
          GestureDetector(
            onTap: () {
              Navigator.pop(context); // Close dialog
              context.push('/credit-earn');
            },
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7EF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFCD7F32), size: 36),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nasıl kredi kazanırım?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Anketlere katıl, sorular sor, cevap ver ve toplulukla etkileşime geçerek kredi kazan.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.orange),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextLevelCard(
    BuildContext context, {
    required LevelModel targetLevel,
    required LevelModel currentLevel,
    required int currentCredits,
    required bool isNextTarget,
    required List<LevelModel> levels,
  }) {
    final Color levelColor = Color(int.parse(targetLevel.color.replaceAll('#', '0xFF')));
    final targetLevelIndex = levels.indexOf(targetLevel);
    
    // Sadece bu seviyede açılan *yeni* yetenekleri bul
    final newAbilities = _allAbilities.where((a) => (a['levelIndex'] as int) == targetLevelIndex).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShieldIcon(targetLevel.icon ?? '🛡️', levelColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        targetLevel.label,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${targetLevel.minCredits}+ Kredi',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      
                      Text(
                        '${levels[targetLevelIndex-1].label.split(" ")[0]} ayrıcalıklarına ek olarak:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 4,
                        children: newAbilities.map((ability) {
                          return _buildAbilityItem(ability['titleKey']!.toString().tr(), true);
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isNextTarget ? AppTheme.actionBlue.withValues(alpha: 0.1) : Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isNextTarget ? 'Sıradaki Hedef' : 'Hedef: ${targetLevel.minCredits} kredi',
                    style: TextStyle(
                      color: isNextTarget ? AppTheme.actionBlue : Colors.orange[800], 
                      fontSize: 10, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress Bar for Next Target
          if (isNextTarget)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.actionBlue.withValues(alpha: 0.03),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up_rounded, color: AppTheme.actionBlue, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '${targetLevel.minCredits - currentCredits} kredi kazan, ${targetLevel.label} ol!',
                    style: const TextStyle(fontSize: 12, color: AppTheme.primaryNavy, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Container(
                    width: 60,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (currentCredits / targetLevel.minCredits).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.actionBlue,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$currentCredits / ${targetLevel.minCredits}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAbilityItem(String title, bool hasAbility) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: hasAbility ? Colors.green : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Icon(
            hasAbility ? Icons.check : Icons.close,
            size: 12,
            color: hasAbility ? Colors.white : Colors.grey[400],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: hasAbility ? Colors.grey[800] : Colors.grey[400],
              decoration: hasAbility ? null : TextDecoration.lineThrough,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Özel Kalkan (Shield) Çizimi (Görsel yoksa yedek)
  Widget _buildShieldIcon(String emoji, Color color) {
    return Container(
      width: 70,
      height: 80,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12), // Kalkan şekli idealde CustomPaint ile çizilir ama Container de iş görür
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield_rounded, size: 60, color: color.withValues(alpha: 0.5)),
          Text(emoji, style: const TextStyle(fontSize: 28)),
        ],
      ),
    );
  }
}
