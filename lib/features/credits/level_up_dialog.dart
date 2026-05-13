import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LevelUpDialog extends StatelessWidget {
  final String level;
  final List<String> perks;

  const LevelUpDialog({
    super.key,
    required this.level,
    required this.perks,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getLevelColor(level);
    final icon = _getLevelIcon(level);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      backgroundColor: Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TEBRİKLER!',
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${level.toUpperCase()} SEVİYESİNE YÜKSELDİNİZ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Yeni Yetenekleriniz:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                ...perks.map((perk) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          perk,
                          style: const TextStyle(fontSize: 14, color: AppTheme.primaryNavy),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'MÜKEMMEL!',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -50,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Text(
                icon,
                style: const TextStyle(fontSize: 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'silver': return AppTheme.creditGold; // Gümüş rengi temada altın gibi duruyor
      case 'gold': return Colors.orange;
      case 'platin': return Colors.deepPurple;
      default: return AppTheme.actionBlue;
    }
  }

  String _getLevelIcon(String level) {
    switch (level.toLowerCase()) {
      case 'silver': return '🥈';
      case 'gold': return '🥇';
      case 'platin': return '💎';
      default: return '🎖️';
    }
  }
}
