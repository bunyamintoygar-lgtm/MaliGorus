import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  bool _pushEnabled = true;
  bool _notifyMessages = true;
  bool _notifyDiscussions = true;
  bool _notifyConsultations = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await _supabase
          .from('profiles')
          .select('push_enabled, notify_messages, notify_discussions, notify_consultations')
          .eq('id', userId)
          .single();

      setState(() {
        _pushEnabled = data['push_enabled'] ?? true;
        _notifyMessages = data['notify_messages'] ?? true;
        _notifyDiscussions = data['notify_discussions'] ?? true;
        _notifyConsultations = data['notify_consultations'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'common_error'.tr()}: $e')),
        );
      }
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      if (key == 'push_enabled') _pushEnabled = value;
      if (key == 'notify_messages') _notifyMessages = value;
      if (key == 'notify_discussions') _notifyDiscussions = value;
      if (key == 'notify_consultations') _notifyConsultations = value;
    });

    try {
      await _supabase.from('profiles').update({key: value}).eq('id', userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'common_error'.tr()}: $e')),
        );
        _loadSettings();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('notification_settings_title'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 16),
                _buildSectionHeader('notification_general'.tr()),
                _buildSwitchTile(
                  title: 'notification_push_enable'.tr(),
                  subtitle: 'notification_push_desc'.tr(),
                  value: _pushEnabled,
                  onChanged: (val) => _updateSetting('push_enabled', val),
                ),
                const Divider(),
                _buildSectionHeader('notification_categories'.tr()),
                _buildSwitchTile(
                  title: 'notification_messages'.tr(),
                  subtitle: 'notification_messages_desc'.tr(),
                  value: _notifyMessages,
                  onChanged: (val) => _updateSetting('notify_messages', val),
                  enabled: _pushEnabled,
                ),
                _buildSwitchTile(
                  title: 'notification_discussions'.tr(),
                  subtitle: 'notification_discussions_desc'.tr(),
                  value: _notifyDiscussions,
                  onChanged: (val) => _updateSetting('notify_discussions', val),
                  enabled: _pushEnabled,
                ),
                _buildSwitchTile(
                  title: 'notification_consultations'.tr(),
                  subtitle: 'notification_consultations_desc'.tr(),
                  value: _notifyConsultations,
                  onChanged: (val) => _updateSetting('notify_consultations', val),
                  enabled: _pushEnabled,
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.chat_bubble_outline,
                        'notification_info_messages'.tr(),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.forum_outlined,
                        'notification_info_discussions'.tr(),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.psychology_outlined,
                        'notification_info_consultations'.tr(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'notification_footer_note'.tr(),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Container(
      color: Colors.white,
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: enabled ? AppTheme.primaryNavy : Colors.grey,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
        activeThumbColor: AppTheme.actionBlue,
      ),
    );
  }
}
