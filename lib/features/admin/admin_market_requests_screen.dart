import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../core/theme/app_theme.dart';
import '../../data/models/market_purchase_model.dart';
import '../../data/supabase/admin_market_service.dart';

class AdminMarketRequestsScreen extends ConsumerStatefulWidget {
  const AdminMarketRequestsScreen({super.key});

  @override
  ConsumerState<AdminMarketRequestsScreen> createState() => _AdminMarketRequestsScreenState();
}

class _AdminMarketRequestsScreenState extends ConsumerState<AdminMarketRequestsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<MarketPurchaseModel> _purchases = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _selectedStatus = 'all';
  int _offset = 0;
  final int _limit = 15;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore && !_loading) {
        _loadMorePurchases();
      }
    }
  }

  Future<void> _loadPurchases({bool isRefresh = true}) async {
    if (isRefresh) {
      setState(() {
        _loading = true;
        _offset = 0;
        _purchases = [];
        _hasMore = true;
      });
    }

    try {
      final list = await ref.read(adminMarketServiceProvider).getAllPurchases(
            offset: _offset,
            limit: _limit,
            status: _selectedStatus,
            searchTerm: _searchController.text,
          );

      if (mounted) {
        setState(() {
          _purchases = isRefresh ? list : [..._purchases, ...list];
          _loading = false;
          _offset += list.length;
          if (list.length < _limit) _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMorePurchases() async {
    setState(() => _loadingMore = true);
    await _loadPurchases(isRefresh: false);
    if (mounted) setState(() => _loadingMore = false);
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadPurchases();
    });
  }

  Future<void> _updateStatus(MarketPurchaseModel purchase, String newStatus) async {
    try {
      await ref.read(adminMarketServiceProvider).updatePurchaseStatus(purchase, newStatus);
      _loadPurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'cancelled' ? 'Talep iptal edildi ve kredi iade edildi.' : 'Talep tamamlandı.'),
            backgroundColor: newStatus == 'cancelled' ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F8),
      appBar: AppBar(
        title: const Text('Market Talepleri', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _loadPurchases(),
                    child: _purchases.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _purchases.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _purchases.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              }
                              return _buildPurchaseCard(_purchases[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Kullanıcı veya ürün ara...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip('Hepsi', 'all'),
                _buildFilterChip('Bekleyen', 'pending'),
                _buildFilterChip('Tamamlanan', 'completed'),
                _buildFilterChip('İptal Edilen', 'cancelled'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String status) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          if (val) {
            setState(() => _selectedStatus = status);
            _loadPurchases();
          }
        },
        selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
        checkmarkColor: AppTheme.primaryNavy,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryNavy : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Sonuç bulunamadı',
            style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _selectedStatus = 'all');
              _loadPurchases();
            },
            child: const Text('Filtreleri Temizle'),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard(MarketPurchaseModel purchase) {
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(purchase.createdAt);
    final imageUrl = purchase.product?.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusBadge(purchase.status),
                    Text(dateStr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: hasImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.network(imageUrl, fit: BoxFit.cover),
                            )
                          : const Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            purchase.product?.title ?? 'Silinmiş Ürün',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.stars_rounded, color: AppTheme.creditGold, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${purchase.creditPaid} Kredi',
                                style: const TextStyle(color: AppTheme.creditGold, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => context.push('/profile/other/${purchase.userId}'),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.person, size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            purchase.userName ?? 'Bilinmeyen Kullanıcı',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.blue),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (purchase.status == 'pending')
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _showConfirmDialog(purchase, 'cancelled'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('İptal Et & İade Et', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(purchase, 'completed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Tamamlandı Onayla', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showConfirmDialog(MarketPurchaseModel purchase, String status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('İptal & İade Onayı', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bu talebi iptal etmek istediğinize emin misiniz? Kullanıcının kredisi anında iade edilecek ve stok geri yüklenecektir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(purchase, 'cancelled');
            },
            child: const Text('Evet, İptal ve İade Et', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'completed':
        color = Colors.green;
        text = 'TAMAMLANDI';
        break;
      case 'cancelled':
        color = Colors.red;
        text = 'İPTAL EDİLDİ';
        break;
      default:
        color = Colors.orange;
        text = 'BEKLEMEDE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
