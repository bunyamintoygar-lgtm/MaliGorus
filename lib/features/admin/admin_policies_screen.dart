import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'admin_provider.dart';

class AdminPoliciesScreen extends ConsumerStatefulWidget {
  const AdminPoliciesScreen({super.key});

  @override
  ConsumerState<AdminPoliciesScreen> createState() => _AdminPoliciesScreenState();
}

class _AdminPoliciesScreenState extends ConsumerState<AdminPoliciesScreen> {
  static const List<Map<String, String>> _policies = [
    {'key': 'privacy_policy', 'title': 'Gizlilik Politikası', 'icon': 'privacy'},
    {'key': 'terms_of_service', 'title': 'Kullanım Koşulları', 'icon': 'terms'},
    {'key': 'kvkk', 'title': 'KVKK Aydınlatma Metni', 'icon': 'kvkk'},
    {'key': 'cookie_policy', 'title': 'Çerez Politikası', 'icon': 'cookie'},
    {'key': 'membership_agreement', 'title': 'Üyelik Sözleşmesi', 'icon': 'membership'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0,
        title: const Text('Politikalar ve Sözleşmeler'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _policies.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final policy = _policies[index];
          return _buildPolicyCard(context, policy);
        },
      ),
    );
  }

  Widget _buildPolicyCard(BuildContext context, Map<String, String> policy) {
    IconData iconData;
    Color iconColor;

    switch (policy['icon']) {
      case 'privacy':
        iconData = Icons.privacy_tip_rounded;
        iconColor = Colors.indigo;
        break;
      case 'terms':
        iconData = Icons.gavel_rounded;
        iconColor = Colors.teal;
        break;
      case 'kvkk':
        iconData = Icons.shield_rounded;
        iconColor = Colors.blue;
        break;
      case 'cookie':
        iconData = Icons.cookie_outlined;
        iconColor = Colors.orange;
        break;
      case 'membership':
        iconData = Icons.handshake_outlined;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.description_outlined;
        iconColor = Colors.grey;
    }

    return InkWell(
      onTap: () => _openPolicyEditor(context, policy['key']!, policy['title']!),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(iconData, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    policy['title']!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'İçeriği düzenlemek için tıklayın',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_note_rounded, color: Colors.grey[300], size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _openPolicyEditor(BuildContext context, String key, String title) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PolicyEditorScreen(policyKey: key, policyTitle: title),
      ),
    );
  }
}

class _PolicyEditorScreen extends ConsumerStatefulWidget {
  final String policyKey;
  final String policyTitle;

  const _PolicyEditorScreen({required this.policyKey, required this.policyTitle});

  @override
  ConsumerState<_PolicyEditorScreen> createState() => _PolicyEditorScreenState();
}

class _PolicyEditorScreenState extends ConsumerState<_PolicyEditorScreen> {
  final _contentController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    final content = await ref.read(adminServiceProvider).getPolicy(widget.policyKey);
    _contentController.text = content;
    setState(() => _isLoading = false);
  }

  Future<void> _savePolicy() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İçerik alanı boş bırakılamaz.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final success = await ref.read(adminServiceProvider).savePolicy(
      key: widget.policyKey,
      content: _contentController.text.trim(),
    );
    setState(() => _isSaving = false);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.policyTitle} başarıyla kaydedildi.'), backgroundColor: Colors.green[700]),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Kaydetme başarısız. Tekrar deneyin.'), backgroundColor: Colors.red[700]),
      );
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0,
        title: Text(widget.policyTitle),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _savePolicy,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.actionBlue),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.indigo[400], size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bu metin uygulamadaki "${widget.policyTitle}" sayfasında görüntülenecektir. HTML veya düz metin olarak yazabilirsiniz.',
                            style: TextStyle(fontSize: 12, color: Colors.indigo[700], height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: '${widget.policyTitle} içeriğini buraya yazın...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          contentPadding: const EdgeInsets.all(20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14, height: 1.8, color: AppTheme.primaryNavy),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
