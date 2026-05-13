import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/level_model.dart';

final appConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.from('app_config').select();
  
  final Map<String, dynamic> config = {};
  for (var item in response) {
    final key = item['key'];
    final value = item['value'];
    
    if (value is String && (value.startsWith('[') || value.startsWith('{'))) {
      try {
        config[key] = jsonDecode(value);
      } catch (e) {
        config[key] = value;
      }
    } else {
      config[key] = value;
    }
  }
  return config;
});

final levelConfigProvider = Provider<AsyncValue<List<LevelModel>>>((ref) {
  final configAsync = ref.watch(appConfigProvider);
  return configAsync.whenData((config) {
    final levelsJson = config['level_config'] as List<dynamic>? ?? [];
    return levelsJson.map((l) => LevelModel.fromJson(l as Map<String, dynamic>)).toList();
  });
});
