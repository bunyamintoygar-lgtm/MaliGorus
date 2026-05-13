import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/discussion_model.dart';
import '../../data/repositories/discussion_repository.dart';
import 'discussion_provider.dart';
import '../../core/widgets/community_guidelines_text.dart';
import '../../core/utils/level_permissions.dart';
import '../../core/providers/app_config_provider.dart';
import '../../core/services/moderation_service.dart';
import '../../core/utils/moderation_ui.dart';

class CreateDiscussionScreen extends ConsumerStatefulWidget {
  final DiscussionModel? discussion;

  const CreateDiscussionScreen({super.key, this.discussion});

  @override
  ConsumerState<CreateDiscussionScreen> createState() => _CreateDiscussionScreenState();
}

class _CreateDiscussionScreenState extends ConsumerState<CreateDiscussionScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  String? _selectedCategory;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.discussion?.title);
    _bodyController = TextEditingController(text: widget.discussion?.body);
    _selectedCategory = widget.discussion?.category;
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
        SnackBar(content: Text(_selectedCategory == null ? 'discussions_error_select_category'.tr() : 'discussions_error_empty'.tr())),
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
      final success = widget.discussion != null
          ? await ref.read(discussionRepositoryProvider).updateDiscussion(
              widget.discussion!.id,
              _titleController.text.trim(),
              _bodyController.text.trim(),
              category: _selectedCategory,
            )
          : await ref.read(discussionRepositoryProvider).createDiscussion(
              title: _titleController.text.trim(),
              body: _bodyController.text.trim(),
              category: _selectedCategory,
              type: 'tartisma',
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
            : 'discussions_success_discussion'.tr())),
        );
      } else {
        if (mounted) {
          if (widget.discussion != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('discussions_error_update'.tr())),
            );
          } else {
            LevelPermissions.showInsufficientCreditDialog(context, requiredCredits: 5);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.discussion != null ? 'discussions_edit'.tr() : 'discussions_start_discussion'.tr()),
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
                  'discussions_title_hint_discussion'.tr()
                ),
                const SizedBox(height: 24),
                _buildLabel('discussions_category'.tr()),
                _buildCategoryDropdown(),
                const SizedBox(height: 24),
                _buildLabel('discussions_description'.tr()),
                _buildTextField(
                  _bodyController, 
                  'discussions_description_hint'.tr(), 
                  maxLines: 6
                ),
                const SizedBox(height: 24),
                const CommunityGuidelinesText(),
                _buildSubmitButton(),
                if (widget.discussion == null) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'discussions_credit_info'.tr(),
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

  Widget _buildCategoryDropdown() {
    final configAsync = ref.watch(appConfigProvider);
    
    return configAsync.when(
      data: (config) {
        final List<dynamic> rawCategories = config['discussion_categories'] ?? [
          {'value': 'gelir_kurumlar', 'label': 'Gelir/Kurumlar Vergisi'},
          {'value': 'kdv_diger', 'label': 'KDV ve Diğer Vergiler'},
          {'value': 'sgk_is_hukuku', 'label': 'SGK ve İş Hukuku'},
          {'value': 'muhasebe', 'label': 'Muhasebe Standartları'},
          {'value': 'donem_sonu', 'label': 'Dönem Sonu İşlemleri'},
          {'value': 'mevzuat', 'label': 'Mevzuat Değişiklikleri'},
          {'value': 'diger', 'label': 'Diğer'}
        ];
        
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
}
