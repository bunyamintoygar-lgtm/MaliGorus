import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'admin_provider.dart';
import 'package:intl/intl.dart';

class AdminSupportRequestsScreen extends ConsumerStatefulWidget {
  const AdminSupportRequestsScreen({super.key});

  @override
  ConsumerState<AdminSupportRequestsScreen> createState() => _AdminSupportRequestsScreenState();
}

class _AdminSupportRequestsScreenState extends ConsumerState<AdminSupportRequestsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 20;

  List<Map<String, dynamic>> _requests = [];
  String _searchQuery = '';
  String _selectedStatus = 'all';

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
      _requests = [];
    });

    final data = await ref.read(adminServiceProvider).getSupportRequests(
      page: 0,
      limit: _pageSize,
      status: _selectedStatus,
      searchQuery: _searchQuery,
    );

    if (mounted) {
      setState(() {
        _requests = data;
        _hasMore = data.length == _pageSize;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    setState(() => _isLoadingMore = true);
    
    _currentPage++;
    final data = await ref.read(adminServiceProvider).getSupportRequests(
      page: _currentPage,
      limit: _pageSize,
      status: _selectedStatus,
      searchQuery: _searchQuery,
    );

    if (mounted) {
      setState(() {
        _requests.addAll(data);
        _hasMore = data.length == _pageSize;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    final success = await ref.read(adminServiceProvider).updateSupportRequestStatus(id, newStatus);
    if (success && context.mounted) {
      _loadInitialData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Durum güncellendi.')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'resolved': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Bekliyor';
      case 'in_progress': return 'İnceleniyor';
      case 'resolved': return 'Çözüldü';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Destek Talepleri'),
        actions: [
          IconButton(
            onPressed: _loadInitialData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                    ? const Center(child: Text('Talep bulunamadı.'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _requests.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final req = _requests[index];
                          final profile = req['profiles'] as Map<String, dynamic>?;
                          final date = DateTime.parse(req['created_at']).toLocal();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(req['status']).withValues(alpha: 0.1),
                                child: Icon(Icons.help_outline_rounded, color: _getStatusColor(req['status'])),
                              ),
                              title: Text(req['subject'] ?? 'Konu Yok', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${profile?['full_name'] ?? 'Bilinmeyen Kullanıcı'} • ${DateFormat('dd.MM.yyyy HH:mm').format(date)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(req['status']).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusText(req['status']),
                                  style: TextStyle(color: _getStatusColor(req['status']), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Mesaj:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text(req['message'] ?? '-', style: const TextStyle(color: Colors.black87)),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildStatusButton(req['id'], 'pending', 'Beklet'),
                                          _buildStatusButton(req['id'], 'in_progress', 'İncele'),
                                          _buildStatusButton(req['id'], 'resolved', 'Çözüldü'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            onChanged: (val) {
              _searchQuery = val;
              _loadInitialData();
            },
            decoration: InputDecoration(
              hintText: 'Konu veya kullanıcı adı ara...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'Hepsi'),
                const SizedBox(width: 8),
                _buildFilterChip('pending', 'Bekleyenler'),
                const SizedBox(width: 8),
                _buildFilterChip('in_progress', 'İncelenenler'),
                const SizedBox(width: 8),
                _buildFilterChip('resolved', 'Çözülenler'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status, String label) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStatus = status;
            _loadInitialData();
          });
        }
      },
      selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryNavy : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildStatusButton(String id, String status, String label) {
    return TextButton(
      onPressed: () => _updateStatus(id, status),
      child: Text(label, style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold)),
    );
  }
}
