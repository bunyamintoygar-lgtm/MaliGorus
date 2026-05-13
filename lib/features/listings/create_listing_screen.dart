import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/app_config_provider.dart';
import '../../data/repositories/listing_repository.dart';
import '../../data/models/listing_model.dart';
import 'listing_provider.dart';
import '../../core/widgets/community_guidelines_text.dart';
import '../../core/utils/level_permissions.dart';
import '../../core/services/moderation_service.dart';
import '../../core/utils/moderation_ui.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  final ListingModel? listing;
  const CreateListingScreen({super.key, this.listing});

  @override
  ConsumerState<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  String? _selectedCategory;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.listing?.title);
    _descriptionController = TextEditingController(text: widget.listing?.description);
    _locationController = TextEditingController(text: widget.listing?.location);
    _selectedCategory = widget.listing?.category;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) return;

    setState(() => _isLoading = true);

    bool isOffTopic = false;
    // AI Moderasyonu
    final isSafe = await ModerationUI.check(
      context, 
      ref.read(moderationServiceProvider), 
      '${_titleController.text}\n${_descriptionController.text}',
      isNewTopic: true,
      onOffTopicApproved: () => isOffTopic = true,
    );

    if (!isSafe) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      bool success;
      if (widget.listing != null) {
        // Güncelleme
        success = await ref.read(listingRepositoryProvider).updateListing(
          id: widget.listing!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory!,
          location: _locationController.text.trim(),
        );
      } else {
        // Yeni Kayıt
        success = await ref.read(listingRepositoryProvider).createListing(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory!,
          location: _locationController.text.trim(),
          isOffTopic: isOffTopic,
        );
      }


      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('listings_success'.tr())),
          );
          ref.invalidate(listingListProvider);
          context.pop();
        }
      } else {
        if (mounted) {
          if (widget.listing != null) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('listings_error_update'.tr())),
            );
          } else {
            // Config'den maliyeti çek
            final config = ref.read(appConfigProvider).value;
            final creditPrices = config?['credit_prices'] as Map<String, dynamic>?;
            final listingCost = (creditPrices?['listing_create'] as num?)?.abs().toInt() ?? 40;
            
            LevelPermissions.showInsufficientCreditDialog(context, requiredCredits: listingCost);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common_error_occurred'.tr(args: [e.toString()]))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(appConfigProvider);
    final isEditing = widget.listing != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEditing ? 'common_edit'.tr() : 'listings_new'.tr()), // edit_profile reuse or add new key
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0.5,
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('error_loading'.tr(args: [err.toString()]))),
        data: (config) {
          // Kredi miktarını çek
          final creditPrices = config['credit_prices'] as Map<String, dynamic>?;
          final listingCost = (creditPrices?['listing_create'] as num?)?.abs().toInt() ?? 40;

          // Hem alt çizgili hem tireli anahtarı kontrol et
          var rawValue = config['listing_categories'] ?? config['listing-categories'];
          
          List<dynamic> rawCategories;
          if (rawValue is List) {
            rawCategories = rawValue;
          } else {
            rawCategories = [
              {'value': 'is_ilani', 'label': 'listings_category_job'.tr()},
              {'value': 'ortaklık', 'label': 'listings_category_partner'.tr()},
              {'value': 'stajyer', 'label': 'listings_category_intern'.tr()},
            ];
          }
          
          final categories = rawCategories.map((c) {
            if (c is Map) {
              return Map<String, String>.from(c.map((k, v) => MapEntry(k.toString(), v.toString())));
            }
            return {'value': c.toString(), 'label': c.toString()};
          }).toList();
          
          if (_selectedCategory == null && categories.isNotEmpty) {
            _selectedCategory = categories[0]['value'];
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Text('listings_title_field'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    maxLength: 150,
                    decoration: InputDecoration(
                      hintText: 'listings_title_hint'.tr(),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'listings_error_title'.tr() : null,
                  ),
                  const SizedBox(height: 24),

                  // Kategori
                  Text('listings_category'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                    ),
                    items: categories.map((c) => DropdownMenuItem<String>(
                      value: c['value'],
                      child: Text(c['label']!),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),
                  const SizedBox(height: 24),

                  // Konum
                  Text('listings_location'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _locationController,
                    maxLength: 50,
                    decoration: InputDecoration(
                      hintText: 'listings_location_hint'.tr(),
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'listings_error_location'.tr() : null,
                  ),
                  const SizedBox(height: 24),

                  // Açıklama
                  Text('listings_detail'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 8,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      hintText: 'listings_detail_hint'.tr(),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'listings_error_detail'.tr() : null,
                  ),
                  const CommunityGuidelinesText(),
                  const SizedBox(height: 8),

                  // Gönder Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.actionBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(isEditing ? 'common_save'.tr() : 'listings_publish'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (!isEditing) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'listings_cost_info'.tr(args: [listingCost.toString()]),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
