import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_report_model.dart';
import '../reports/user_report_provider.dart';
import 'admin_provider.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 20;

  List<UserReportModel> _reports = [];
  String _statusFilter = 'all'; // all, pending, reviewed, dismissed

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMore = true;
      _reports = [];
    });

    final data = await ref.read(adminServiceProvider).getReports(
      page: 0,
      limit: _pageSize,
      status: _statusFilter,
    );

    if (mounted) {
      setState(() {
        _reports = data.map((e) => UserReportModel.fromJson(e)).toList();
        _hasMore = data.length == _pageSize;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    setState(() => _isLoadingMore = true);
    
    _currentPage++;
    final data = await ref.read(adminServiceProvider).getReports(
      page: _currentPage,
      limit: _pageSize,
      status: _statusFilter,
    );

    if (mounted) {
      setState(() {
        _reports.addAll(data.map((e) => UserReportModel.fromJson(e)).toList());
        _hasMore = data.length == _pageSize;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0,
        title: Text('admin_reports_title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('all', 'Tümü', Icons.list_alt_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('pending', 'Bekliyor', Icons.schedule_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('reviewed', 'İncelendi', Icons.check_circle_outline),
                const SizedBox(width: 8),
                _buildFilterChip('dismissed', 'Reddedildi', Icons.cancel_outlined),
              ],
            ),
          ),
          const Divider(height: 1),

          // Reports list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[200]),
                            const SizedBox(height: 16),
                            Text(
                              _statusFilter == 'all'
                                  ? 'Henüz şikayet bulunmuyor.'
                                  : 'Bu kategoride şikayet bulunmuyor.',
                              style: TextStyle(color: Colors.grey[400], fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _reports.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == _reports.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          return _buildReportCard(_reports[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final isActive = _statusFilter == key;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_statusFilter != key) {
            setState(() => _statusFilter = key);
            _loadInitialData();
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryNavy : Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? AppTheme.primaryNavy : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: isActive ? Colors.white : Colors.grey[500]),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(UserReportModel report) {
    final statusInfo = _getStatusInfo(report.status);
    final categoryLabel = _getCategoryLabel(report.category);
    final date = DateFormat('dd.MM.yyyy HH:mm').format(report.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Reporter -> Reported
          Row(
            children: [
              // Reporter avatar
              _buildAvatar(report.reporterName, report.reporterAvatar, Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.reporterName ?? 'Bilinmeyen',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.primaryNavy),
                    ),
                    Text('Şikayet Eden', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: Colors.grey[400], size: 20),
              const SizedBox(width: 8),
              _buildAvatar(report.reportedName, report.reportedAvatar, Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.reportedName ?? 'Bilinmeyen',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.primaryNavy),
                    ),
                    Text('Şikayet Edilen', style: TextStyle(fontSize: 10, color: Colors.red[400])),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Category & Date
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  categoryLabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange[800]),
                ),
              ),
              const SizedBox(width: 8),
              if (report.contentType != 'user')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.contentType.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                  ),
                ),
              const Spacer(),
              Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(date, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),

          // Content Section (New)
          if (report.contentTitle != null || report.contentBody != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.article_outlined, size: 14, color: Colors.blueGrey[700]),
                      const SizedBox(width: 6),
                      Text(
                        'Şikayet Edilen İçerik',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (report.contentTitle != null)
                    Text(
                      report.contentTitle!,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                    ),
                  if (report.contentTitle != null && report.contentBody != null)
                    const SizedBox(height: 4),
                  if (report.contentBody != null)
                    Text(
                      report.contentBody!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.4),
                      maxLines: 10,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],

          // Description (User's report message)
          if (report.description != null && report.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('Şikayet Notu:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.1)),
              ),
              child: Text(
                report.description!,
                style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Status chip + Actions
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusInfo['color'].withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusInfo['icon'], size: 14, color: statusInfo['color']),
                    const SizedBox(width: 4),
                    Text(
                      statusInfo['label'],
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusInfo['color']),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Actions
              if (report.status == 'pending') ...[
                _buildActionButton(
                  icon: Icons.check_circle_outline,
                  label: 'İncele',
                  color: Colors.green,
                  onTap: () => _updateStatus(report.id, 'reviewed'),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.cancel_outlined,
                  label: 'Reddet',
                  color: Colors.red,
                  onTap: () => _updateStatus(report.id, 'dismissed'),
                ),
              ],
              if (report.status != 'pending')
                _buildActionButton(
                  icon: Icons.delete_outline,
                  label: 'Şikayeti Sil',
                  color: Colors.grey,
                  onTap: () => _deleteReport(report.id),
                ),
            ],
          ),

          // Admin Action Buttons (New)
          if (report.status == 'pending') ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                if (report.contentType != 'user' && report.contentId != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _deleteContent(report),
                      icon: const Icon(Icons.delete_forever_rounded, size: 16),
                      label: const Text('İçeriği Sil', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red[700],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.red.shade100)),
                      ),
                    ),
                  ),
                if (report.contentType != 'user' && report.contentId != null)
                  const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _banUser(report),
                    icon: const Icon(Icons.gpp_bad_rounded, size: 16),
                    label: const Text('Kullanıcıyı Yasakla', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[900],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(String? name, String? avatarUrl, Color fallbackColor) {
    final initial = (name ?? '?').isNotEmpty ? name![0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 18,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
      backgroundColor: fallbackColor.withValues(alpha: 0.1),
      child: avatarUrl == null
          ? Text(initial, style: TextStyle(fontWeight: FontWeight.bold, color: fallbackColor, fontSize: 14))
          : null,
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'reviewed':
        return {'label': 'İncelendi', 'color': Colors.green, 'icon': Icons.check_circle};
      case 'dismissed':
        return {'label': 'Reddedildi', 'color': Colors.red, 'icon': Icons.cancel};
      default:
        return {'label': 'Bekliyor', 'color': Colors.orange, 'icon': Icons.schedule};
    }
  }

  String _getCategoryLabel(String key) {
    const labels = {
      'spam': 'Spam / İstenmeyen İçerik',
      'harassment': 'Taciz / Zorbalık',
      'inappropriate': 'Uygunsuz İçerik',
      'fake_profile': 'Sahte Profil',
      'fraud': 'Dolandırıcılık / Sahtecilik',
      'other': 'Diğer',
    };
    return labels[key] ?? key;
  }

  Future<void> _updateStatus(String reportId, String newStatus) async {
    final service = ref.read(userReportServiceProvider);
    final success = await service.updateReportStatus(reportId, newStatus);
    if (success) {
      _loadInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'reviewed' ? 'Şikayet incelendi olarak işaretlendi.' : 'Şikayet reddedildi.'),
            backgroundColor: newStatus == 'reviewed' ? Colors.green[700] : Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _deleteReport(String reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Şikayeti Sil'),
        content: const Text('Bu şikayeti kalıcı olarak silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final service = ref.read(userReportServiceProvider);
    final success = await service.deleteReport(reportId);
    if (success) {
      _loadInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şikayet silindi.'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _deleteContent(UserReportModel report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İçeriği Sil'),
        content: Text('Bu ${report.contentType} içeriğini kalıcı olarak silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final adminService = ref.read(adminServiceProvider);
    bool success = false;

    switch (report.contentType) {
      case 'discussion':
      case 'consultation':
        success = await adminService.deleteDiscussion(report.contentId!);
        break;
      case 'discussion_reply':
      case 'consultation_reply':
        success = await adminService.deleteReply(report.contentId!);
        break;
      case 'survey':
        success = await adminService.deleteSurvey(report.contentId!);
        break;
      case 'listing':
        success = await adminService.deleteListing(report.contentId!);
        break;
    }

    if (success) {
      // Şikayeti de otomatik olarak "İncelendi" yap
      await _updateStatus(report.id, 'reviewed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İçerik başarıyla silindi.'), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İçerik silinirken hata oluştu.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _banUser(UserReportModel report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Yasakla'),
        content: Text('${report.reportedName} isimli kullanıcıyı kalıcı olarak yasaklamak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Yasakla'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final adminService = ref.read(adminServiceProvider);
    final success = await adminService.banUser(report.reportedId);

    if (success) {
      // Şikayeti de otomatik olarak "İncelendi" yap
      await _updateStatus(report.id, 'reviewed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı yasaklandı.'), backgroundColor: Colors.green),
        );
      }
    }
  }
}
