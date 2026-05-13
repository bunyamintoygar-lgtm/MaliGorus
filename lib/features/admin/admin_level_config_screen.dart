import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/supabase/credit_service.dart';
import '../../data/models/level_model.dart';
import '../../core/providers/app_config_provider.dart';

class AdminLevelConfigScreen extends ConsumerStatefulWidget {
  const AdminLevelConfigScreen({super.key});

  @override
  ConsumerState<AdminLevelConfigScreen> createState() => _AdminLevelConfigScreenState();
}

class _AdminLevelConfigScreenState extends ConsumerState<AdminLevelConfigScreen> {
  List<LevelModel> _levels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await ref.read(creditServiceProvider).getConfigValue('level_config');
      if (config != null && config is List) {
        setState(() {
          _levels = config.map((e) => LevelModel.fromJson(e)).toList();
          _loading = false;
        });
      } else {
        // Varsayılan konfigürasyon
        setState(() {
          _levels = [
            LevelModel(key: 'bronze', label: 'Bronz Üye', minCredits: 0, color: '#CD7F32', icon: '🥉'),
            LevelModel(key: 'silver', label: 'Gümüş Üye', minCredits: 1000, color: '#C0C0C0', icon: '🥈'),
            LevelModel(key: 'gold', label: 'Altın Üye', minCredits: 5000, color: '#FFD700', icon: '🥇'),
          ];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _loading = true);
    // Küçükten büyüğe sırala
    _levels.sort((a, b) => a.minCredits.compareTo(b.minCredits));
    
    final success = await ref.read(creditServiceProvider).updateConfigValue(
      'level_config', 
      _levels.map((e) => e.toJson()).toList()
    );

    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Ayarlar kaydedildi' : 'Hata oluştu')),
      );
      if (success) {
        ref.invalidate(levelConfigProvider);
      }
    }
  }

  void _addLevel() {
    setState(() {
      _levels.add(LevelModel(
        key: 'level_${_levels.length}',
        label: 'Yeni Seviye',
        minCredits: (_levels.lastOrNull?.minCredits ?? 0) + 1000,
        color: '#808080',
        icon: '🎖️',
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rozet ve Seviye Ayarları'),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _saveConfig,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLevel,
        backgroundColor: AppTheme.primaryNavy,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _levels.length,
              itemBuilder: (context, index) {
                final level = _levels[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Color(int.parse(level.color.replaceAll('#', '0xFF'))),
                              child: Text(level.icon ?? '?', style: const TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                level.label,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() => _levels.removeAt(index));
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: level.label,
                                decoration: const InputDecoration(labelText: 'Seviye İsmi'),
                                onChanged: (val) => setState(() => _levels[index] = LevelModel(
                                  key: level.key,
                                  label: val,
                                  minCredits: level.minCredits,
                                  color: level.color,
                                  icon: level.icon,
                                )),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: level.minCredits.toString(),
                                decoration: const InputDecoration(labelText: 'Min Kredi'),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() => _levels[index] = LevelModel(
                                  key: level.key,
                                  label: level.label,
                                  minCredits: int.tryParse(val) ?? 0,
                                  color: level.color,
                                  icon: level.icon,
                                )),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: level.color,
                                decoration: const InputDecoration(labelText: 'Renk (Hex)'),
                                onChanged: (val) => setState(() => _levels[index] = LevelModel(
                                  key: level.key,
                                  label: level.label,
                                  minCredits: level.minCredits,
                                  color: val,
                                  icon: level.icon,
                                )),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: level.icon,
                                decoration: const InputDecoration(labelText: 'İkon (Emoji)'),
                                onChanged: (val) => setState(() => _levels[index] = LevelModel(
                                  key: level.key,
                                  label: level.label,
                                  minCredits: level.minCredits,
                                  color: level.color,
                                  icon: val,
                                )),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
