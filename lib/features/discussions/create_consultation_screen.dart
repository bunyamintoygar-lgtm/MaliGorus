import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/discussion_model.dart';
import '../../data/repositories/discussion_repository.dart';
import '../../data/supabase/file_service.dart';
import 'discussion_provider.dart';
import '../../core/widgets/community_guidelines_text.dart';
import '../../core/utils/level_permissions.dart';
import '../../core/providers/app_config_provider.dart';
import '../../core/services/moderation_service.dart';
import '../../core/utils/moderation_ui.dart';

class CreateConsultationScreen extends ConsumerStatefulWidget {
  final DiscussionModel? discussion;

  const CreateConsultationScreen({super.key, this.discussion});

  @override
  ConsumerState<CreateConsultationScreen> createState() => _CreateConsultationScreenState();
}

class _CreateConsultationScreenState extends ConsumerState<CreateConsultationScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _isLoading = false;
  bool _isAnonymous = false;
  String? _selectedCategory;
  final List<PlatformFile> _selectedFiles = [];
  final List<String> _existingAttachmentUrls = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.discussion?.title);
    _bodyController = TextEditingController(text: widget.discussion?.body);
    _isAnonymous = widget.discussion?.isAnonymous ?? false;
    _selectedCategory = widget.discussion?.category;
    if (widget.discussion != null) {
      _existingAttachmentUrls.addAll(widget.discussion!.attachmentUrls);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_selectedCategory == null ? 'discussions_error_select_category'.tr() : 'common_error_fill_all'.tr())),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool isOffTopic = false;
    // AI Moderasyonu
    final isSafe = await ModerationUI.check(
      context, 
      ref.read(moderationServiceProvider), 
      '${_titleController.text} ${_bodyController.text}',
      isNewTopic: true,
      onOffTopicApproved: () => isOffTopic = true,
    );

    if (!isSafe) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final fileService = ref.read(fileServiceProvider);
      final List<String> uploadedUrls = [..._existingAttachmentUrls];
      
      for (final file in _selectedFiles) {
        final url = await fileService.uploadFile(
          file: file,
          bucket: 'discussions',
          folder: 'attachments',
        );
        if (url != null) uploadedUrls.add(url);
      }

      final success = widget.discussion != null
          ? await ref.read(discussionRepositoryProvider).updateDiscussion(
              widget.discussion!.id,
              _titleController.text.trim(),
              _bodyController.text.trim(),
              category: _selectedCategory,
              attachmentUrls: uploadedUrls,
            )
          : await ref.read(discussionRepositoryProvider).createDiscussion(
              title: _titleController.text.trim(),
              body: _bodyController.text.trim(),
              category: _selectedCategory,
              type: 'danisma',
              isAnonymous: _isAnonymous,
              attachmentUrls: uploadedUrls,
              isOffTopic: isOffTopic,
            );


      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          if (widget.discussion != null) {
            ref.invalidate(singleDiscussionProvider(widget.discussion!.id));
          }
          context.pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.discussion != null 
              ? 'discussions_updated'.tr() 
              : 'discussions_success_consultation'.tr())),
          );
        } else {
          if (mounted) {
            if (widget.discussion != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('discussions_error_update'.tr())),
              );
            } else {
              LevelPermissions.showInsufficientCreditDialog(context, requiredCredits: 15);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common_error_occurred'.tr(args: [e.toString()]))),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    if (_selectedFiles.length + _existingAttachmentUrls.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('discussions_error_max_files'.tr())),
      );
      return;
    }

    final fileService = ref.read(fileServiceProvider);
    final file = await fileService.pickDocument();
    
    if (file != null) {
      setState(() {
        _selectedFiles.add(file);
      });
    }
  }

  void _removeNewFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _removeExistingFile(int index) {
    setState(() {
      _existingAttachmentUrls.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.discussion != null ? 'discussions_edit_consultation'.tr() : 'discussions_ask_question'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('discussions_title'.tr()),
                _buildTextField(
                  _titleController, 
                  'discussions_title_hint_consultation'.tr()
                ),
                const SizedBox(height: 24),
                _buildLabel('discussions_category'.tr()),
                _buildCategoryDropdown(),
                const SizedBox(height: 24),
                _buildLabel('discussions_detail'.tr()),
                _buildTextField(
                  _bodyController, 
                  'discussions_detail_hint'.tr(), 
                  maxLines: 8
                ),
                const SizedBox(height: 16),
                _buildAnonymousToggle(),
                const SizedBox(height: 24),
                _buildLabel('discussions_attachments'.tr()),
                Text(
                  'discussions_attachments_hint'.tr(),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 12),
                
                if (_existingAttachmentUrls.isNotEmpty) ...[
                  ..._existingAttachmentUrls.asMap().entries.map((entry) {
                    final index = entry.key;
                    final url = entry.value;
                    final fileName = url.split('/').last.split('?').first;
                    return _buildFileItem(fileName, () => _removeExistingFile(index), isExisting: true);
                  }),
                ],
                
                if (_selectedFiles.isNotEmpty) ...[
                  ..._selectedFiles.asMap().entries.map((entry) {
                    final index = entry.key;
                    final file = entry.value;
                    return _buildFileItem(file.name, () => _removeNewFile(index));
                  }),
                ],
                
                if (_selectedFiles.length + _existingAttachmentUrls.length < 5)
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: Text('discussions_pick_file'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.actionBlue,
                      side: const BorderSide(color: AppTheme.actionBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                
                const SizedBox(height: 24),
                const CommunityGuidelinesText(),
                _buildSubmitButton(),
                if (widget.discussion == null) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'discussions_consultation_credit_info'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
    );
  }



  Widget _buildAnonymousToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isAnonymous ? AppTheme.actionBlue.withValues(alpha: 0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isAnonymous ? AppTheme.actionBlue.withValues(alpha: 0.2) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isAnonymous ? Icons.visibility_off : Icons.visibility,
            color: _isAnonymous ? AppTheme.actionBlue : Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'discussions_anonymous_toggle'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryNavy,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'discussions_anonymous_toggle_hint'.tr(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAnonymous,
            onChanged: (val) => setState(() => _isAnonymous = val),
            activeThumbColor: AppTheme.actionBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, fontSize: 14),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final configAsync = ref.watch(appConfigProvider);
    
    return configAsync.when(
      data: (config) {
        final List<dynamic> rawCategories = config['consultation_categories'] ?? [];
        
        final categories = rawCategories.map((c) {
          if (c is Map) {
            return {'value': c['value']?.toString() ?? '', 'label': c['label']?.toString() ?? ''};
          }
          return {'value': c.toString(), 'label': c.toString()};
        }).toList();

        categories.sort((a, b) => a['label']!.toLowerCase().compareTo(b['label']!.toLowerCase()));

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              hint: Text('discussions_select_category'.tr(), style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryNavy),
              items: categories.map((cat) => DropdownMenuItem<String>(
                value: cat['value'],
                child: Text(cat['label']!, style: const TextStyle(fontSize: 14, color: AppTheme.primaryNavy)),
              )).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Text('discussions_error_categories_load'.tr()),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.actionBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          'save'.tr(), 
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }

  Widget _buildFileItem(String name, VoidCallback onRemove, {bool isExisting = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isExisting ? Colors.blue[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isExisting ? Colors.blue[100]! : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file, size: 18, color: isExisting ? Colors.blue : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
            onPressed: onRemove,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );

  }
}
