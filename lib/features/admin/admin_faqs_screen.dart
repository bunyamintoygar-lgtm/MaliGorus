import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'admin_provider.dart';

class AdminFAQsScreen extends ConsumerStatefulWidget {
  const AdminFAQsScreen({super.key});

  @override
  ConsumerState<AdminFAQsScreen> createState() => _AdminFAQsScreenState();
}

class _AdminFAQsScreenState extends ConsumerState<AdminFAQsScreen> {
  List<Map<String, String>> _faqs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFaqs();
  }

  Future<void> _loadFaqs() async {
    final faqs = await ref.read(adminServiceProvider).getFaqs();
    if (mounted) {
      setState(() {
        _faqs = faqs;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveFaqs() async {
    setState(() => _isLoading = true);
    final success = await ref.read(adminServiceProvider).saveFaqs(_faqs);
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'SSS listesi güncellendi.' : 'Hata oluştu.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _addFaq() {
    setState(() {
      _faqs.add({'q': '', 'a': ''});
    });
  }

  void _removeFaq(int index) {
    setState(() {
      _faqs.removeAt(index);
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSS Yönetimi'),
        actions: [
          IconButton(
            onPressed: _saveFaqs,
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Değişiklikleri Kaydet',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _faqs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Henüz soru eklenmemiş.'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addFaq,
                        icon: const Icon(Icons.add),
                        label: const Text('İlk Soruyu Ekle'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _faqs.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppTheme.primaryNavy,
                                  child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                                const SizedBox(width: 12),
                                const Text('Soru & Cevap', style: TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => _removeFaq(index),
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                            const Divider(),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Soru',
                                hintText: 'Kullanıcıların göreceği soru...',
                                border: InputBorder.none,
                              ),
                              controller: TextEditingController(text: _faqs[index]['q'])..selection = TextSelection.fromPosition(TextPosition(offset: _faqs[index]['q']!.length)),
                              onChanged: (val) => _faqs[index]['q'] = val,
                              maxLines: null,
                            ),
                            const Divider(),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Cevap',
                                hintText: 'Sorunun yanıtı...',
                                border: InputBorder.none,
                              ),
                              controller: TextEditingController(text: _faqs[index]['a'])..selection = TextSelection.fromPosition(TextPosition(offset: _faqs[index]['a']!.length)),
                              onChanged: (val) => _faqs[index]['a'] = val,
                              maxLines: null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _isLoading ? null : FloatingActionButton(
        onPressed: _addFaq,
        backgroundColor: AppTheme.primaryNavy,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
