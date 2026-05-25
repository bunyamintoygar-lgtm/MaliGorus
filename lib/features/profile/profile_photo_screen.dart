import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/supabase/file_service.dart';
import '../../core/services/moderation_service.dart';
import '../../core/utils/moderation_ui.dart';
import '../home/home_provider.dart';

class ProfilePhotoScreen extends ConsumerStatefulWidget {
  final String? initialAvatarUrl;
  const ProfilePhotoScreen({super.key, this.initialAvatarUrl});

  @override
  ConsumerState<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends ConsumerState<ProfilePhotoScreen> {
  String? _currentAvatarUrl;
  bool _isLoading = false;
  bool _isNewPhotoUploaded = false;
  Uint8List? _originalImageBytes; // used only to show/hide the Re-align button
  String? _originalImagePath;     // used by image_cropper for re-cropping

  // Example/guideline portrait URLs from Unsplash showing ideal profile photos
  final List<Map<String, String>> _examplePhotos = [
    {
      'url': 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=300',
      'title': 'Aydınlık ve Sade Arka Plan',
      'desc': 'Arka planın sade, nötr ve tek renk olması yüzünüzün ön plana çıkmasını sağlar. Sertifikalarda ve toplulukta en profesyonel sonucu verir.',
      'label': 'Örnek 1',
    },
    {
      'url': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300',
      'title': 'Doğrudan Bakış ve Gülümseme',
      'desc': 'Kameraya doğrudan bakmak ve samimi bir tebessüm, profilinizde güvenilir ve profesyonel bir duruş sergiler.',
      'label': 'Örnek 2',
    },
    {
      'url': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=300',
      'title': 'Doğru Odaklama ve Kadraj',
      'desc': 'Yüzünüzün fotoğrafın tam merkezinde (kadrajın %60-70\'ini kaplayacak şekilde) konumlanması kimliğinizin net tanınmasını sağlar.',
      'label': 'Örnek 3',
    },
  ];

  String _translate(String key, String fallback) {
    final translated = key.tr();
    return translated == key ? fallback : translated;
  }

  @override
  void initState() {
    super.initState();
    _currentAvatarUrl = widget.initialAvatarUrl;
    if (_currentAvatarUrl == null || _currentAvatarUrl!.isEmpty) {
      _loadCurrentProfile();
    }
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final profile = await ref.read(profileRepositoryProvider).getMyProfile();
      if (profile != null && mounted) {
        setState(() {
          _currentAvatarUrl = profile.avatarUrl;
        });
      }
    } catch (_) {}
  }

  /// Picks an image from [source] then opens the native image_cropper.
  Future<void> _pickImage(ImageSource source) async {
    final fileService = ref.read(fileServiceProvider);
    final file = await fileService.pickImage(
      source: source,
      preferredCameraDevice: source == ImageSource.camera
          ? CameraDevice.front
          : CameraDevice.rear,
    );
    if (file == null) return;

    _originalImageBytes = await file.readAsBytes();
    await _cropAndUpload(file.path);
  }

  /// Re-opens the cropper on the already-picked original file path.
  Future<void> _realignImage() async {
    if (_originalImagePath == null) return;
    await _cropAndUpload(_originalImagePath!);
  }

  /// Core crop → moderate → upload logic shared by both pick and realign flows.
  Future<void> _cropAndUpload(String sourcePath) async {
    setState(() => _isLoading = true);
    try {
      if (!mounted) return;

      // Open native image_cropper with circle mode + purple theme
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        compressFormat: ImageCompressFormat.png,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Fotoğrafı Düzenle',
            toolbarColor: const Color(0xFF5C33CF),
            toolbarWidgetColor: Colors.white,
            statusBarColor: const Color(0xFF3B1FAA),
            backgroundColor: Colors.black,
            activeControlsWidgetColor: const Color(0xFF5C33CF),
            cropStyle: CropStyle.circle,
            lockAspectRatio: true,
            hideBottomControls: false,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: 'Fotoğrafı Düzenle',
            doneButtonTitle: 'Uygula',
            cancelButtonTitle: 'İptal',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
            resetButtonHidden: false,
            rotateButtonsHidden: false,
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 520, height: 520),
            viewwMode: WebViewMode.mode_1,
            initialAspectRatio: 1.0,
            guides: true,
            center: true,
            highlight: true,
            background: true,
            movable: true,
            rotatable: true,
            scalable: true,
            zoomable: true,
            cropBoxMovable: false,
            cropBoxResizable: false,
          ),
        ],
      );

      if (croppedFile == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Remember the original source path for future re-align
      _originalImagePath = sourcePath;

      if (!mounted) return;
      final croppedBytes = await croppedFile.readAsBytes();

      // AI Moderation
      final isSafe = await ModerationUI.checkImage(
        context,
        ref.read(moderationServiceProvider),
        croppedBytes,
        'image/png',
      );

      if (!isSafe) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Upload
      final fileService = ref.read(fileServiceProvider);
      final url = await fileService.uploadBytes(
        bytes: croppedBytes,
        name: 'cropped_avatar.png',
        bucket: 'avatars',
        folder: 'profiles',
        contentType: 'image/png',
      );
      if (url != null && mounted) {
        setState(() {
          _currentAvatarUrl = url;
          _isNewPhotoUploaded = true;
        });
      }
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

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    try {
      // Update avatar in database
      await ref.read(profileRepositoryProvider).updateAvatar(_currentAvatarUrl);
      
      // Reload home/profile state
      await ref.read(homeProvider.notifier).loadHomeData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(_translate('profile_photo_saved_success', 'Profil fotoğrafınız başarıyla güncellendi.')),
              ],
            ),
            backgroundColor: Colors.green[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop(_currentAvatarUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF5C33CF);
    const lightPurple = Color(0xFFF3EFFF);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _translate('profile_photo_title', 'Profil Fotoğrafı'),
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // Circular Avatar Preview Area with sparkles
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Left Sparkle
                        Positioned(
                          left: 10,
                          top: 40,
                          child: Opacity(
                            opacity: 0.3,
                            child: Icon(Icons.star_rounded, color: primaryColor.withValues(alpha: 0.5), size: 24),
                          ),
                        ),
                        // Right Sparkle
                        Positioned(
                          right: 15,
                          top: 50,
                          child: Opacity(
                            opacity: 0.3,
                            child: Icon(Icons.star_rounded, color: primaryColor.withValues(alpha: 0.5), size: 28),
                          ),
                        ),
                        // Tiny bottom sparkle
                        Positioned(
                          right: 40,
                          bottom: 20,
                          child: Opacity(
                            opacity: 0.3,
                            child: Icon(Icons.star_rounded, color: primaryColor.withValues(alpha: 0.5), size: 16),
                          ),
                        ),

                        // Main Avatar Frame
                        Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.15),
                              width: 3,
                            ),
                          ),
                          alignment: Alignment.center,
                           child: GestureDetector(
                            onTap: () {
                              if (_originalImageBytes != null) {
                                _realignImage();
                              } else {
                                _pickImage(ImageSource.camera);
                              }
                            },
                            child: Container(
                              width: 176,
                              height: 176,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFE2D9FF), Color(0xFFF3EFFF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.08),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(88),
                                child: _currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty
                                    ? Image.network(
                                        _currentAvatarUrl!,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(
                                            child: CircularProgressIndicator(color: primaryColor),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(Icons.person, size: 80, color: Color(0xFF94A3B8));
                                        },
                                      )
                                    : const Icon(Icons.person, size: 80, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                        ),

                        // Camera Badge Button
                        Positioned(
                          bottom: 8,
                          right: 12,
                          child: InkWell(
                            onTap: () => _pickImage(ImageSource.gallery),
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    _translate('profile_photo_header', 'Profil fotoğrafınız'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _translate('profile_photo_desc', 'Profil fotoğrafınız, toplulukta ve sertifikanızda görünecektir.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_originalImageBytes != null) ...[
                          TextButton.icon(
                            onPressed: _realignImage,
                            icon: const Icon(Icons.crop_rounded, color: primaryColor, size: 20),
                            label: const Text(
                              'Yeniden Hizala',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: primaryColor.withOpacity(0.05),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _currentAvatarUrl = null;
                              _isNewPhotoUploaded = true;
                              _originalImageBytes = null;
                            });
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          label: const Text(
                            'Fotoğrafı Kaldır',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: Colors.red.withOpacity(0.05),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Option List Items
                  // Galeriden Seç
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: ListTile(
                      onTap: () => _pickImage(ImageSource.gallery),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.image_outlined,
                          color: primaryColor,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        _translate('profile_photo_select_gallery', 'Galeriden Seç'),
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        _translate('profile_photo_select_gallery_sub', 'Cihazınızdan fotoğraf seçin'),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Fotoğraf Çek
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: ListTile(
                      onTap: () => _pickImage(ImageSource.camera),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: primaryColor,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        _translate('profile_photo_take_photo', 'Fotoğraf Çek'),
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        _translate('profile_photo_take_photo_sub', 'Hemen yeni bir fotoğraf çekin'),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tips / Guidelines Box with a shield
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: lightPurple.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _translate('profile_photo_tip_1', 'En iyi sonuç için yüzünüzün net göründüğü bir fotoğraf kullanın.'),
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Options Presets list (Example guidelines)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ...List.generate(_examplePhotos.length, (index) {
                        final ex = _examplePhotos[index];
                        return GestureDetector(
                          onTap: () => _showExampleDetailBottomSheet(context, ex),
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(36),
                                  child: Image.network(
                                    ex['url']!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  ex['title']!,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // More Button (Daha Fazlası)
                      GestureDetector(
                        onTap: () => _showAllGuidelinesBottomSheet(context),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                              ),
                              child: const Icon(
                                Icons.more_horiz_rounded,
                                color: primaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 80,
                              child: Text(
                                _translate('profile_photo_more', 'Daha Fazlası'),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Action Buttons (Kaydet & İptal)
                  ElevatedButton(
                    onPressed: _isNewPhotoUploaded ? _handleSave : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isNewPhotoUploaded ? primaryColor : const Color(0xFFCBD5E1),
                      foregroundColor: _isNewPhotoUploaded ? Colors.white : const Color(0xFF94A3B8),
                      elevation: 0,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'save'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'cancel'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  void _showExampleDetailBottomSheet(BuildContext context, Map<String, String> example) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      example['label'] ?? '',
                      style: const TextStyle(
                        color: Color(0xFF5C33CF),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(60),
                      child: Image.network(example['url']!, fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  example['title']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  example['desc']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C33CF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Anladım', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAllGuidelinesBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'İdeal Profil Fotoğrafı Kılavuzu',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sertifikalarınızda ve toplulukta en iyi görünümü elde etmek için bu kurallara dikkat edin.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Horizontal list of example photos
                  SizedBox(
                    height: 116,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _examplePhotos.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final ex = _examplePhotos[index];
                        return Container(
                          width: 125,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.network(ex['url']!, width: 56, height: 56, fit: BoxFit.cover),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ex['title']!,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // Do's List
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Yapılması Gerekenler',
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildGuidelineItem(Icons.done, 'Sade, nötr renkli arka planlar tercih edin.'),
                  _buildGuidelineItem(Icons.done, 'Yüzünüze ışığın doğrudan vurduğu, aydınlık ortamları seçin.'),
                  _buildGuidelineItem(Icons.done, 'Kameraya doğrudan bakın ve hafifçe gülümseyin.'),
                  _buildGuidelineItem(Icons.done, 'Yüzünüzün net göründüğü güncel fotoğraflar kullanın.'),
                  
                  const SizedBox(height: 24),
                  
                  // Don'ts List
                  const Row(
                    children: [
                      Icon(Icons.cancel_rounded, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Yapılmaması Gerekenler',
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildGuidelineItem(Icons.close, 'Çok uzaktan çekilmiş manzara/boy fotoğrafları yüklemeyin.'),
                  _buildGuidelineItem(Icons.close, 'Grup fotoğrafları veya arka planda başkalarının olduğu resimler kullanmayın.'),
                  _buildGuidelineItem(Icons.close, 'Aşırı filtre uygulanmış, karanlık veya flu görseller yüklemeyin.'),
                  _buildGuidelineItem(Icons.close, 'Resmi evraklar dışındaki logolar veya manzara resimlerini profil yapmayın.'),
                  
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C33CF),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Anladım, Kapat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGuidelineItem(IconData icon, String text) {
    final isDone = icon == Icons.done;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDone ? Icons.check_rounded : Icons.close_rounded,
            color: isDone ? Colors.green[700] : Colors.red[700],
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// image_cropper v12.2.1 handles all cropping natively
