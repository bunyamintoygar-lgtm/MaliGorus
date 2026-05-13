import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/app_config_provider.dart';
import '../../core/widgets/profession_label.dart';
import '../../core/widgets/level_badge.dart';
import '../../data/models/listing_model.dart';
import '../../data/repositories/listing_repository.dart';
import '../profile/profile_provider.dart';
import '../../core/utils/name_formatter.dart';
import '../../core/utils/level_permissions.dart';

import '../home/home_provider.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final ListingModel listing;
  const ListingDetailScreen({super.key, required this.listing});

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  bool _isLoading = false;
  bool _hasApplied = false;
  List<Map<String, dynamic>> _applications = [];
  final String? _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _checkApplicationStatus();
    if (widget.listing.authorId == _currentUserId) {
      _loadApplications();
    }
  }

  Future<void> _loadApplications() async {
    final apps = await ref.read(listingRepositoryProvider).getApplicationsForListing(widget.listing.id);
    if (mounted) {
      setState(() => _applications = apps);
    }
  }

  Future<void> _checkApplicationStatus() async {
    final hasApplied = await ref.read(listingRepositoryProvider).hasUserApplied(widget.listing.id);
    if (mounted) {
      setState(() => _hasApplied = hasApplied);
    }
  }

  Future<void> _handleApply() async {
    final userLevel = ref.read(homeProvider).value?.profile?.highestLevel;
    final levels = ref.read(levelConfigProvider).value ?? [];
    if (!LevelPermissions.hasPermission(userLevel, AppPermission.applyToListing, levels)) {
      LevelPermissions.showAccessDeniedDialog(context, AppPermission.applyToListing);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('listings_apply'.tr()),
        content: Text('listings_apply_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('listings_apply'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final success = await ref.read(listingRepositoryProvider).applyToListing(widget.listing.id);
      if (success) {
        if (mounted) {
          setState(() => _hasApplied = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('listings_apply_success'.tr())),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('discussions_error_no_credit'.tr())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String message = 'common_error_occurred'.tr(args: [e.toString()]);
        if (e.toString().contains('unique_violation') || e.toString().contains('23505')) {
          message = 'listings_already_applied'.tr();
          setState(() => _hasApplied = true);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleWithdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('listings_withdraw'.tr()),
        content: Text('listings_withdraw_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('common_delete'.tr(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final success = await ref.read(listingRepositoryProvider).withdrawApplication(widget.listing.id);
      if (success) {
        if (mounted) {
          setState(() => _hasApplied = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('listings_withdraw_success'.tr())),
          );
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
    final bool isOwner = widget.listing.authorId == _currentUserId;
    final authorAsync = ref.watch(authorProfileProvider(widget.listing.authorId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('listings_detail_title'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0.5,
        actions: [
          if (!isOwner)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: InkWell(
                  onTap: () => context.push('/report', extra: {
                    'reportedId': widget.listing.authorId,
                    'reportedTitle': widget.listing.title,
                    'contentType': 'listing',
                    'contentId': widget.listing.id,
                    'contentBody': widget.listing.description,
                  }),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'common_report'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/create-listing', extra: widget.listing),
            ),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('error_loading'.tr(args: [err.toString()]))),
        data: (config) {
          var rawValue = config['listing_categories'] ?? config['listing-categories'];
          List<dynamic> rawCategories = rawValue is List ? rawValue : [];
          
          String categoryLabel = widget.listing.category ?? '';
          for (var c in rawCategories) {
            if (c is Map && c['value'] == widget.listing.category) {
              categoryLabel = c['label'] ?? categoryLabel;
              break;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.listing.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (categoryLabel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.actionBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          categoryLabel,
                          style: const TextStyle(color: AppTheme.actionBlue, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    const Spacer(),
                    Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMMM yyyy', 'tr_TR').format(widget.listing.createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.primaryNavy),
                    const SizedBox(width: 8),
                    Text(
                      widget.listing.location ?? 'listings_not_specified'.tr(),
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ],
                ),
                const Divider(height: 48),
                Text('discussions_description'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Text(
                  widget.listing.description ?? '',
                  style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                ),
                const Divider(height: 48),

                Text('listings_author'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                authorAsync.when(
                  data: (profile) {
                    if (profile == null) return const SizedBox.shrink();
                    final name = profile.displayName;
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                    
                    return GestureDetector(
                      onTap: () => context.push('/profile/${profile.id}'),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                            backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                            child: profile.avatarUrl == null 
                                ? Text(initial, style: const TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.bold)) 
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(width: 4),
                                  LevelBadge(levelKey: profile.highestLevel, size: 12, transparent: true),
                                ],
                              ),
                              ProfessionLabel(
                                professionId: profile.profession,
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                if (isOwner) ...[
                  const Divider(height: 48),
                  _buildApplicationsSection(),
                ],
                const SizedBox(height: 120),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: configAsync.when(
        data: (config) {
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isOwner)
                    const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (isOwner || _isLoading) ? null : (_hasApplied ? () => _handleWithdraw() : () => _handleApply()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasApplied ? Colors.red.shade700 : AppTheme.primaryNavy,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _hasApplied ? 'listings_withdraw'.tr() : 'listings_apply'.tr(),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildApplicationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('listings_applications_received'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.primaryNavy, borderRadius: BorderRadius.circular(10)),
              child: Text(
                _applications.length.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_applications.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('listings_no_applications_yet'.tr())),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _applications.length,
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final app = _applications[index];
              final profile = app['profiles'] as Map<String, dynamic>?;
              if (profile == null) return const SizedBox.shrink();

              final name = NameFormatter.format(profile['full_name']);
              final avatar = profile['avatar_url'];
              final profession = profile['profession'];

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                  child: avatar == null 
                      ? Text(name[0].toUpperCase(), style: const TextStyle(color: AppTheme.primaryNavy)) 
                      : null,
                ),
                title: Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (profile['highest_level'] != null) ...[
                      const SizedBox(width: 4),
                      LevelBadge(levelKey: profile['highest_level'], size: 12, transparent: true),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfessionLabel(
                      professionId: profession,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(app['created_at'])),
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  ],
                ),
                trailing: TextButton(
                  onPressed: () {
                    context.push('/chat/detail', extra: {
                      'userId': profile['id'],
                      'userName': name,
                      'userAvatar': avatar,
                      'userTitle': '', // Title can be fetched if needed
                    });
                  },
                  child: Text('profile_send_message'.tr()),
                ),
                onTap: () => context.push('/profile/${profile['id']}'),
              );
            },
          ),
      ],
    );
  }
}
