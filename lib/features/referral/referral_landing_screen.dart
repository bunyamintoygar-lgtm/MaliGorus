import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/referral_repository.dart';
import '../../core/utils/name_formatter.dart';

class ReferralLandingScreen extends ConsumerStatefulWidget {
  final String referralCode;
  const ReferralLandingScreen({super.key, required this.referralCode});

  @override
  ConsumerState<ReferralLandingScreen> createState() => _ReferralLandingScreenState();
}

class _ReferralLandingScreenState extends ConsumerState<ReferralLandingScreen> {
  Map<String, dynamic>? _profileData;
  bool _loading = true;
  bool _formSubmitted = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedProfession = 'mali_musavir';
  bool _submitting = false;

  final _professions = {
    'mali_musavir': 'Mali Müşavir',
    'muhasebe_uzmani': 'Muhasebe Uzmanı',
    'ymm': 'Yeminli Mali Müşavir (YMM)',
    'denetci': 'Denetçi',
    'finans_uzmani': 'Finans Uzmanı',
    'diger': 'Diğer',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_referral_code', widget.referralCode);
    } catch (_) {}

    final repo = ref.read(referralRepositoryProvider);
    final data = await repo.getReferralProfile(widget.referralCode);
    if (mounted) {
      setState(() {
        _profileData = data;
        _loading = false;
      });
    }
  }

  Future<void> _submitForm() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm zorunlu alanları doldurun')),
      );
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir e-posta adresi girin')),
      );
      return;
    }

    setState(() => _submitting = true);

    final repo = ref.read(referralRepositoryProvider);
    final result = await repo.registerCandidate(
      referralCode: widget.referralCode,
      name: name,
      profession: _selectedProfession,
      email: email,
    );

    if (mounted) {
      setState(() => _submitting = false);

      if (result['success'] == true) {
        setState(() => _formSubmitted = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Bir hata oluştu'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profileData == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Geçersiz referans linki', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    final profile = _profileData!['profile'] as Map<String, dynamic>;
    final review = _profileData!['review'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero başlık
            _buildHeroSection(),

            // Öneren kullanıcı kartı
            _buildReferrerCard(profile, review),

            // Uygulama özellikleri
            _buildFeaturesSection(),

            // İndirme linkleri
            _buildDownloadSection(),

            // Kayıt formu veya başarı mesajı
            if (_formSubmitted)
              _buildSuccessMessage()
            else
              _buildRegistrationForm(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1a237e), Color(0xFF3949ab)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          // Logo alanı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'MaliGörüş',
            style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            'Mali Müşavirler İçin Profesyonel Ağ',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReferrerCard(Map<String, dynamic> profile, Map<String, dynamic>? review) {
    final name = NameFormatter.format(profile['full_name']);
    final profession = profile['profession'];
    final avatarUrl = profile['avatar_url'];
    final company = profile['company_name'];

    String profLabel = 'Üye';
    switch (profession) {
      case 'mali_musavir': profLabel = 'Mali Müşavir'; break;
      case 'muhasebe_uzmani': profLabel = 'Muhasebe Uzmanı'; break;
      case 'ymm': profLabel = 'YMM'; break;
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            const Text('Sizi Davet Eden', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primaryNavy)),
            const SizedBox(height: 4),
            Text(profLabel, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            if (company != null) ...[
              const SizedBox(height: 2),
              Text(company, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ],

            // Yorum
            if (review != null) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return Icon(
                    i < (review['rating'] ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 24,
                  );
                }),
              ),
              const SizedBox(height: 12),
              Text(
                '"${review['review_text']}"',
                style: TextStyle(color: Colors.grey[700], fontSize: 14, fontStyle: FontStyle.italic, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    final features = [
      {'icon': Icons.poll_rounded, 'title': 'Anketler', 'desc': 'Mesleki konularda anketler oluşturun ve katılın'},
      {'icon': Icons.forum_rounded, 'title': 'Tartışmalar', 'desc': 'Güncel konuları meslektaşlarınızla tartışın'},
      {'icon': Icons.psychology_alt_rounded, 'title': 'Danışma', 'desc': 'Uzman meslektaşlarınızdan görüş alın'},
      {'icon': Icons.message_rounded, 'title': 'Mesajlaşma', 'desc': 'Güvenli ve özel mesajlaşma imkanı'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const Text('Neler Yapabilirsiniz?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primaryNavy)),
          const SizedBox(height: 16),
          ...features.map((f) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.actionBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(f['icon'] as IconData, color: AppTheme.actionBlue, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(f['desc'] as String, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDownloadSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Text('Uygulamayı İndirin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primaryNavy)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStoreButton(
                  icon: Icons.android_rounded,
                  label: 'Google Play',
                  color: Colors.green,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Google Play linki yakında eklenecek')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStoreButton(
                  icon: Icons.apple_rounded,
                  label: 'App Store',
                  color: Colors.black87,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('App Store linki yakında eklenecek')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.actionBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.actionBlue, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Hemen Kaydolun', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primaryNavy)),
            const SizedBox(height: 8),
            Text(
              'Bilgilerinizi girin, size hoşgeldiniz e-postası gönderelim!',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Ad Soyad
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Ad Soyad *',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.actionBlue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Unvan
            DropdownButtonFormField<String>(
              initialValue: _selectedProfession,
              decoration: InputDecoration(
                labelText: 'Unvan *',
                prefixIcon: const Icon(Icons.work_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.actionBlue, width: 2),
                ),
              ),
              items: _professions.entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value));
              }).toList(),
              onChanged: (val) => setState(() => _selectedProfession = val!),
            ),
            const SizedBox(height: 16),

            // E-posta
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'E-posta Adresi *',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.actionBlue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Kayıt butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.actionBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Kayıt Ol', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))],
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('Kayıt Başarılı! 🎉', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppTheme.primaryNavy)),
            const SizedBox(height: 12),
            Text(
              'Hoşgeldiniz e-postanız gönderildi.\nUygulamayı indirip hemen kullanmaya başlayabilirsiniz!',
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStoreButton(
                    icon: Icons.android_rounded,
                    label: 'Google Play',
                    color: Colors.green,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStoreButton(
                    icon: Icons.apple_rounded,
                    label: 'App Store',
                    color: Colors.black87,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
