import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/supabase/credit_service.dart';

class AdminCreditConfigScreen extends ConsumerStatefulWidget {
  const AdminCreditConfigScreen({super.key});

  @override
  ConsumerState<AdminCreditConfigScreen> createState() => _AdminCreditConfigScreenState();
}

class _AdminCreditConfigScreenState extends ConsumerState<AdminCreditConfigScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;
  bool _isSaving = false;

  final List<Map<String, String>> _configItems = [
    {'label': 'Anket Oluşturma', 'key': 'survey_create'},
    {'label': 'Anket Oylama', 'key': 'survey_vote'},
    {'label': 'Tartışma Başlatma', 'key': 'discussion_create'},
    {'label': 'Tartışmaya Cevap Verme', 'key': 'discussion_reply'},
    {'label': 'Danışma Sorusu', 'key': 'consultation_ask'},
    {'label': 'Danışmaya Cevap Verme', 'key': 'consultation_reply'},
    {'label': 'İlan Yayınlama', 'key': 'listing_create'},
    {'label': 'Bağlantı İsteği', 'key': 'connection_request'},
    {'label': 'Mesaj Gönderme', 'key': 'chat_message'},
    {'label': 'Hoşgeldin Bonusu', 'key': 'welcome_bonus'},
    {'label': 'Arkadaş Önerisi', 'key': 'friend_referral'},
    {'label': 'Link Paylaşımı', 'key': 'link_referral'},
    {'label': 'Yorum Yapma', 'key': 'app_review'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    try {
      final prices = await ref.read(creditServiceProvider).getCreditPrices();
      if (mounted) {
        setState(() {
          for (var item in _configItems) {
            final key = item['key']!;
            final value = prices[key]?.toString() ?? '0';
            _controllers[key] = TextEditingController(text: value);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fiyatlar yüklenirken hata oluştu.')),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    
    final Map<String, int> newPrices = {};
    _controllers.forEach((key, controller) {
      newPrices[key] = int.tryParse(controller.text) ?? 0;
    });

    final success = await ref.read(creditServiceProvider).updateCreditPrices(newPrices);
    
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Kredi fiyatları başarıyla güncellendi.' : 'Güncelleme sırasında hata oluştu.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Kredi Konfigürasyonu'),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aksiyon Ücretlerini Belirleyin',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pozitif değerler kazanç, negatif değerler harcama miktarını ifade eder.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ..._configItems.map((item) => _buildConfigItem(item['label']!, item['key']!)),
                const SizedBox(height: 32),
                _buildSaveButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  Widget _buildConfigItem(String label, String key) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _controllers[key],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.actionBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSaving 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('Değişiklikleri Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
