import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supabase/credit_service.dart';
import '../../data/models/level_model.dart';
import '../providers/app_config_provider.dart';

class LevelBadge extends ConsumerWidget {
  final String levelKey;
  final double size;
  final bool transparent;

  const LevelBadge({
    super.key,
    required this.levelKey,
    this.size = 18,
    this.transparent = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(levelConfigProvider);

    return configAsync.maybeWhen(
      data: (config) {
        final level = config.firstWhere(
          (l) => l.key.toLowerCase() == levelKey.toLowerCase(),
          orElse: () => LevelModel(key: 'bronze', label: 'Bronz Üye', minCredits: 0, color: '#CD7F32', icon: '🛡️'),
        );

        return Tooltip(
          message: level.label,
          child: Container(
            padding: transparent ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: transparent 
              ? null 
              : BoxDecoration(
                  color: Color(int.parse(level.color.replaceAll('#', '0xFF'))).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Color(int.parse(level.color.replaceAll('#', '0xFF'))).withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
            child: Transform.translate(
              offset: Offset(0, transparent ? -1 : 0), // Şeffaf modda emojiyi hafif yukarı al
              child: Text(
                level.icon ?? '🎖️',
                style: TextStyle(fontSize: size),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
