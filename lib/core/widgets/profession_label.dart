import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_config_provider.dart';

class ProfessionLabel extends ConsumerWidget {
  final String? professionId;
  final TextStyle? style;

  const ProfessionLabel({
    super.key,
    required this.professionId,
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (professionId == null || professionId!.isEmpty) {
      return Text('-', style: style);
    }

    final configAsync = ref.watch(appConfigProvider);

    return configAsync.maybeWhen(
      data: (config) {
        final professionsRaw = config['professions'] ?? config['profession'];
        List<dynamic> professions = [];
        if (professionsRaw is List) {
          professions = professionsRaw;
        } else if (professionsRaw is Map) {
          professions = professionsRaw.values.toList();
        }

        String label = professionId!;
        final currentId = professionId!.trim().toUpperCase();

        for (var p in professions) {
          if (p is Map) {
            final id = (p['id'] ?? p['ID'] ?? p['value'] ?? '').toString().trim().toUpperCase();
            if (id == currentId && id.isNotEmpty) {
              label = (p['label'] ?? p['name'] ?? p['title'] ?? id).toString();
              break;
            }
          }
        }

        return Text(label, style: style);
      },
      orElse: () => Text(professionId!, style: style),
    );
  }
}
