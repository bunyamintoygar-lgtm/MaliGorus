import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/survey_model.dart';
import '../../data/repositories/survey_repository.dart';
import '../home/home_provider.dart';
import '../../core/widgets/community_guidelines_text.dart';
import '../../core/utils/level_permissions.dart';
import '../../core/services/moderation_service.dart';
import '../../core/utils/moderation_ui.dart';

class CreateSurveyScreen extends ConsumerStatefulWidget {
  final SurveyModel? survey;
  const CreateSurveyScreen({super.key, this.survey});

  @override
  ConsumerState<CreateSurveyScreen> createState() => _CreateSurveyScreenState();
}

class _CreateSurveyScreenState extends ConsumerState<CreateSurveyScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  String _selectedDuration = '3 Gün';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.survey != null) {
      _titleController.text = widget.survey!.title;
      _descController.text = widget.survey!.description ?? '';
      _optionControllers.clear();
      for (var opt in widget.survey!.options) {
        _optionControllers.add(TextEditingController(text: opt.text));
      }
    }
  }

  Future<void> _handlePublish() async {
    if (_titleController.text.isEmpty || _optionControllers.any((c) => c.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('surveys_error_empty_fields'.tr())),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool isOffTopic = false;
    // AI Moderasyonu
    final optionsText = _optionControllers.map((c) => c.text).join('\n');
    final isSafe = await ModerationUI.check(
      context, 
      ref.read(moderationServiceProvider), 
      '${_titleController.text}\n${_descController.text}\n$optionsText',
      isNewTopic: true,
      onOffTopicApproved: () => isOffTopic = true,
    );

    if (!isSafe) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final options = _optionControllers.map((c) => c.text).toList();
    final days = int.parse(_selectedDuration.split(' ')[0]);
    final expiresAt = DateTime.now().add(Duration(days: days));

    final bool success;
    if (widget.survey != null) {
      success = await ref.read(surveyRepositoryProvider).updateSurvey(
        surveyId: widget.survey!.id,
        title: _titleController.text,
        description: _descController.text,
        options: options,
        expiresAt: expiresAt,
      );
    } else {
      success = await ref.read(surveyRepositoryProvider).createSurvey(
        title: _titleController.text,
        description: _descController.text,
        options: options,
        expiresAt: expiresAt,
        isOffTopic: isOffTopic,
      );
    }


    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        // Ana sayfayı ve kredi bilgisini yenile
        ref.read(homeProvider.notifier).loadHomeData();
        context.pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.survey != null ? 'surveys_update_success'.tr() : 'surveys_create_success'.tr())),
        );
      } else {
        if (mounted) {
          if (widget.survey != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('surveys_error_unauthorized'.tr())),
            );
          } else {
            LevelPermissions.showInsufficientCreditDialog(context, requiredCredits: 20);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.survey != null ? 'surveys_edit_title'.tr() : 'surveys_create_title'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0.5,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('surveys_title_label'.tr()),
                _buildTextField(_titleController, 'surveys_title_hint'.tr()),
                const SizedBox(height: 20),
                _buildLabel('surveys_description_label'.tr()),
                _buildTextField(_descController, 'surveys_description_hint'.tr(), maxLines: 3),
                const SizedBox(height: 24),
                _buildLabel('surveys_options_label'.tr()),
                ..._optionControllers.asMap().entries.map((entry) => _buildOptionField(entry.key)),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _optionControllers.add(TextEditingController()));
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: Text('surveys_add_option'.tr()),
                ),
                const SizedBox(height: 24),
                _buildLabel('surveys_duration_label'.tr()),
                _buildDurationPicker(),
                const CommunityGuidelinesText(),
                _buildPublishButton(),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'surveys_cost_info'.tr(),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
      ),
    );
  }

  Widget _buildOptionField(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: _buildTextField(_optionControllers[index], 'surveys_option_hint'.tr(args: [(index + 1).toString()]))),
          if (_optionControllers.length > 2)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => setState(() => _optionControllers.removeAt(index)),
            ),
        ],
      ),
    );
  }

  Widget _buildDurationPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDuration,
          isExpanded: true,
          items: ['1', '3', '7', '30']
              .map((d) => DropdownMenuItem(value: '$d Gün', child: Text('surveys_duration_day'.tr(args: [d]))))
              .toList(),
          onChanged: (val) => setState(() => _selectedDuration = val!),
        ),
      ),
    );
  }

  Widget _buildPublishButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _handlePublish,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.actionBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('surveys_publish'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
