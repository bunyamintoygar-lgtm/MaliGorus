import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/profile_repository.dart';
import '../../core/providers/app_config_provider.dart';
import '../../data/supabase/file_service.dart';
import '../../core/services/moderation_service.dart';
import '../../core/utils/moderation_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home/home_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends ConsumerState<ProfileCompletionScreen> {
  final _fullNameController = TextEditingController();
  final _companyController = TextEditingController();
  String? _selectedProfession;
  String? _avatarUrl;
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final profile = await ref.read(profileRepositoryProvider).getMyProfile();
      if (profile != null && mounted) {
        setState(() {
          _fullNameController.text = profile.fullName ?? '';
          _companyController.text = profile.companyName ?? '';
          _selectedProfession = profile.profession;
          _avatarUrl = profile.avatarUrl;
        });
      }

      if (_fullNameController.text.trim().isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final cachedName = prefs.getString('oauth_full_name');
        if (cachedName != null && cachedName.isNotEmpty && mounted) {
          setState(() {
            _fullNameController.text = cachedName;
          });
        } else {
          final currentUser = Supabase.instance.client.auth.currentUser;
          final meta = currentUser?.userMetadata;
          String? metaName = meta?['full_name'] ?? meta?['name'];
          if (metaName == null && (meta?['given_name'] != null || meta?['family_name'] != null)) {
            metaName = '${meta?['given_name'] ?? ''} ${meta?['family_name'] ?? ''}'.trim();
          }
          if (metaName != null && metaName.trim().isNotEmpty && mounted) {
            setState(() {
              _fullNameController.text = metaName!;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile_error_load'.tr(args: [e.toString()]))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToPhotoScreen() async {
    final result = await context.push<String>('/profile/photo', extra: _avatarUrl);
    if (result != null && mounted) {
      setState(() {
        _avatarUrl = result;
      });
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryNavy),
              title: Text('profile_take_photo'.tr()),
              onTap: () {
                Navigator.pop(context);
                _executePickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryNavy),
              title: Text('profile_select_gallery'.tr()),
              onTap: () {
                Navigator.pop(context);
                _executePickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _executePickImage(ImageSource source) async {
    final fileService = ref.read(fileServiceProvider);
    final file = await fileService.pickImage(source: source);
    if (file == null) return;

    setState(() => _isLoading = true);
    try {
      // AI Moderasyonu
      final bytes = await file.readAsBytes();
      final isSafe = await ModerationUI.checkImage(
        context, 
        ref.read(moderationServiceProvider), 
        bytes, 
        'image/jpeg' // Varsayılan mime type
      );

      if (!isSafe) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final url = await fileService.uploadFile(
        file: file,
        bucket: 'avatars',
        folder: 'profiles',
      );
      if (url != null) setState(() => _avatarUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile_error_upload'.tr(args: [e.toString()]))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleComplete() async {
    String? errorMessage;
    if (_fullNameController.text.trim().isEmpty) {
      errorMessage = 'error_full_name'.tr();
    } else if (RegExp(r'[0-9.,!?]').hasMatch(_fullNameController.text.trim())) {
      errorMessage = 'Lütfen rakam veya geçersiz özel karakter (.,!?) içermeyen, gerçek adınızı giriniz.';
    } else if (_fullNameController.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length < 2) {
      errorMessage = 'Lütfen ad ve soyadınızı birlikte giriniz (örn: Ahmet Yılmaz).';
    } else if (_selectedProfession == null) {
      errorMessage = 'error_profession'.tr();
    }

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // AI İsim Moderasyonu
    final isNameSafe = await ModerationUI.check(
      context, 
      ref.read(moderationServiceProvider), 
      _fullNameController.text.trim(),
      mode: ModerationMode.name
    );

    if (!isNameSafe) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      await ref.read(profileRepositoryProvider).completeProfile(
        fullName: _fullNameController.text,
        profession: _selectedProfession!,
        companyName: _companyController.text,
        avatarUrl: _avatarUrl,
      );

      // --- ARKA PLANDA GİZLİ REFERANS ÖDÜLÜ ---
      try {
        String? caughtRefCode;
        final prefs = await SharedPreferences.getInstance();
        caughtRefCode = prefs.getString('pending_referral_code');

        if (caughtRefCode == null || caughtRefCode.isEmpty) {
          final List<dynamic> refMatch = await Supabase.instance.client.rpc('match_referral_click');
          if (refMatch.isNotEmpty) {
            caughtRefCode = refMatch[0]['ref_code'];
          }
        }

        if (caughtRefCode != null && caughtRefCode.isNotEmpty) {
          await Supabase.instance.client.rpc('complete_referral_reward', params: {
            'p_new_user_id': Supabase.instance.client.auth.currentUser!.id,
            'p_ref_code': caughtRefCode,
          });
          await prefs.remove('pending_referral_code');
        }
      } catch (e) {
        debugPrint('Gizli referans hatası: $e');
      }
      // ----------------------------------------

      // Ana sayfa verilerini yenile (Profil ismi, firma vb. güncel gelmesi için)
      await ref.read(homeProvider.notifier).loadHomeData();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('oauth_full_name');
        await prefs.remove('pending_referral_code');
      } catch (_) {}

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('edit_profile'.tr()),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.primaryNavy,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : configAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('common_error_load_settings'.tr(args: [err.toString()]))),
            data: (config) {
              final professionsJson = List<dynamic>.from(config['professions'] as List? ?? []);
              professionsJson.sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
              
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAvatarPicker(),
                          const SizedBox(height: 32),
                          _buildTextField('full_name'.tr(), _fullNameController, Icons.person_outline),
                          const SizedBox(height: 16),
                          _buildProfessionDropdown(professionsJson),
                          const SizedBox(height: 16),
                          _buildTextField('company_name'.tr(), _companyController, Icons.business_outlined, isOptional: true),
                          const SizedBox(height: 40),
                          _buildSubmitButton(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildAvatarPicker() {
    return Center(
      child: Stack(
        children: [
          InkWell(
            onTap: _navigateToPhotoScreen,
            borderRadius: BorderRadius.circular(50),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[200],
              backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
              child: _avatarUrl == null 
                ? const Icon(Icons.person, size: 50, color: AppTheme.primaryNavy) 
                : null,
            ),
          ),
          // Resim yüklüyse silme butonu göster (Sağ Üst)
          if (_avatarUrl != null)
            Positioned(
              top: 0,
              right: 0,
              child: InkWell(
                onTap: () => setState(() => _avatarUrl = null),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          // Kamera ikonu (Sağ Alt)
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: _navigateToPhotoScreen,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: AppTheme.actionBlue, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isOptional = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (!isOptional)
              const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.primaryNavy),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }



  Widget _buildProfessionDropdown(List<dynamic> professions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('profession'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedProfession,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.work_outline, color: AppTheme.primaryNavy),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          hint: Text('select'.tr()),
          items: professions.map((p) {
            final map = p as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: map['id'] as String,
              child: Text(map['label'] as String),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedProfession = val),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleComplete,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.actionBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          'save'.tr(),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
