import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/profile_model.dart';
import '../../data/supabase/admin_service.dart';
import 'admin_provider.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

enum _SortOption { dateDesc, dateAsc, creditDesc, creditAsc }

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _searchQuery;
  String? _selectedProfession;
  _SortOption _sortOption = _SortOption.dateDesc;


  static const Map<String, String> _professions = {
    'mali_musavir': 'Mali Müşavir',
    'muhasebe_uzmani': 'Muhasebe Uzmanı',
    'ymm': 'YMM',
    'denetci': 'Denetçi',
    'vergi_mufattisi': 'Vergi Müfettişi',
    'sgk_uzmani': 'SGK Uzmanı',
  };

  String get _sortBy {
    switch (_sortOption) {
      case _SortOption.dateDesc:
      case _SortOption.dateAsc:
        return 'created_at';
      case _SortOption.creditDesc:
      case _SortOption.creditAsc:
        return 'credit_balance';
    }
  }

  bool get _sortAsc {
    switch (_sortOption) {
      case _SortOption.dateAsc:
      case _SortOption.creditAsc:
        return true;
      case _SortOption.dateDesc:
      case _SortOption.creditDesc:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreUsers();
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMore = true;
    });

    try {
      final users = await ref.read(adminServiceProvider).getAllUsers(
        search: _searchQuery,
        page: 0,
        sortBy: _sortBy,
        sortAsc: _sortAsc,
        profession: _selectedProfession,
      );
      setState(() {
        _users = users;
        _isLoading = false;
        _hasMore = users.length >= AdminService.usersPageSize;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);
    _currentPage++;

    try {
      final newUsers = await ref.read(adminServiceProvider).getAllUsers(
        search: _searchQuery,
        page: _currentPage,
        sortBy: _sortBy,
        sortAsc: _sortAsc,
        profession: _selectedProfession,
      );
      setState(() {
        _users.addAll(newUsers);
        _isLoading = false;
        _hasMore = newUsers.length >= AdminService.usersPageSize;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String val) {
    _searchQuery = val.isEmpty ? null : val;
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryNavy,
        elevation: 0,
        title: const Text('Kullanıcı Yönetimi'),
      ),
      body: Column(
        children: [
          // Arama + Filtre alanı
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                // Arama çubuğu
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'İsim ile ara... (Türkçe karakter destekli)',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                    suffixIcon: _searchQuery != null
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Sıralama + Unvan filtresi
                Row(
                  children: [
                    // Sıralama
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<_SortOption>(
                            value: _sortOption,
                            isExpanded: true,
                            icon: Icon(Icons.sort_rounded, size: 18, color: Colors.grey[600]),
                            style: TextStyle(fontSize: 12, color: AppTheme.primaryNavy, fontWeight: FontWeight.w600),
                            items: const [
                              DropdownMenuItem(value: _SortOption.dateDesc, child: Text('Yeni üyeler önce')),
                              DropdownMenuItem(value: _SortOption.dateAsc, child: Text('Eski üyeler önce')),
                              DropdownMenuItem(value: _SortOption.creditDesc, child: Text('Kredi: Çoktan aza')),
                              DropdownMenuItem(value: _SortOption.creditAsc, child: Text('Kredi: Azdan çoğa')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _sortOption = val);
                                _loadUsers();
                              }
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Unvan filtresi
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: _selectedProfession != null
                              ? AppTheme.primaryNavy.withValues(alpha: 0.06)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: _selectedProfession != null
                              ? Border.all(color: AppTheme.primaryNavy.withValues(alpha: 0.2))
                              : null,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedProfession,
                            isExpanded: true,
                            hint: Text('Tüm Unvanlar', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            icon: Icon(Icons.badge_outlined, size: 18, color: Colors.grey[600]),
                            style: TextStyle(fontSize: 12, color: AppTheme.primaryNavy, fontWeight: FontWeight.w600),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Tüm Unvanlar', style: TextStyle(color: Colors.grey[600])),
                              ),
                              ..._professions.entries.map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              )),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedProfession = val);
                              _loadUsers();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sonuç sayısı
          if (_users.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    '${_users.length} kullanıcı${_hasMore ? '+' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (_selectedProfession != null || _searchQuery != null)
                    InkWell(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = null;
                          _selectedProfession = null;
                          _sortOption = _SortOption.dateDesc;
                        });
                        _loadUsers();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_alt_off, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text('Filtreleri Temizle', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Kullanıcı listesi
          Expanded(
            child: _users.isEmpty && _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_rounded, size: 64, color: Colors.grey[200]),
                            const SizedBox(height: 12),
                            Text('Kullanıcı bulunamadı', style: TextStyle(color: Colors.grey[400])),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadUsers(),
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _users.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index >= _users.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                              );
                            }
                            return _buildUserCard(_users[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final profile = ProfileModel.fromJson(user);
    final isAdmin = profile.isAdmin;
    final isBanned = profile.isBanned;
    final initial = (profile.fullName != null && profile.fullName!.isNotEmpty) ? profile.fullName![0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBanned ? Colors.red[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isAdmin
            ? Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1.5)
            : isBanned
                ? Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1.5)
                : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                child: profile.avatarUrl == null
                    ? Text(initial, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_rounded, size: 12, color: Colors.amber[800]),
                                const SizedBox(width: 2),
                                Text('Admin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber[800])),
                              ],
                            ),
                          ),
                        ],
                        if (profile.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 16, color: AppTheme.actionBlue),
                        ],
                        if (isBanned) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.block_rounded, size: 11, color: Colors.red[700]),
                                const SizedBox(width: 2),
                                Text('Yasaklı', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.red[700])),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _professions[profile.profession] ?? profile.profession?.toUpperCase() ?? 'BELİRTİLMEDİ',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, size: 14, color: AppTheme.creditGold),
                      const SizedBox(width: 4),
                      Text('${profile.creditBalance}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.companyName ?? '',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
                    // Moderasyon Bilgileri
          if ((user['moderation_strike_count'] ?? 0) > 0 || user['is_indefinite_blocked'] == true || user['temp_blocked_until'] != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        'Uyarı Sayısı: ${user['moderation_strike_count'] ?? 0}/3',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      if (user['is_indefinite_blocked'] == true) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.gavel_rounded, size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        const Text('Süresiz Bloklu', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ],
                  ),
                  if (user['is_appeal_pending'] == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      'İtiraz Gerekçesi: ${user['appeal_explanation'] ?? 'Belirtilmedi'}',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          Row(
            children: [
              _buildSmallAction(
                icon: Icons.person_outline,
                label: 'Profil',
                color: AppTheme.actionBlue,
                onTap: () => context.push('/profile/other/${profile.id}'),
              ),
              const SizedBox(width: 8),
              _buildSmallAction(
                icon: isAdmin ? Icons.person_remove : Icons.admin_panel_settings,
                label: isAdmin ? 'Admin Kaldır' : 'Admin Yap',
                color: isAdmin ? Colors.red : Colors.amber[700]!,
                onTap: () => _toggleAdmin(profile.id, !isAdmin),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSmallAction(
                icon: isBanned ? Icons.lock_open_rounded : Icons.block_rounded,
                label: isBanned ? 'Üyeliği Geri Aç' : 'Üyeliği Sonlandır',
                color: isBanned ? Colors.green : Colors.red[800]!,
                onTap: () => _toggleBan(profile.id, profile.fullName ?? 'Kullanıcı', !isBanned),
              ),
              const SizedBox(width: 8),
              _buildSmallAction(
                icon: Icons.refresh_rounded,
                label: 'Uyarıları Sıfırla',
                color: Colors.deepPurple,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Moderasyonu Sıfırla'),
                      content: const Text('Kullanıcının tüm uyarılarını, geçici ve süresiz engellemelerini sıfırlamak istediğinize emin misiniz?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sıfırla'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    final success = await ref.read(adminServiceProvider).clearModerationStrike(profile.id);
                    if (success) {
                      _loadUsers();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı moderasyon cezaları sıfırlandı.')));
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildSmallAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleAdmin(String userId, bool makeAdmin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(makeAdmin ? 'Admin Yap' : 'Admin Kaldır'),
        content: Text(makeAdmin
            ? 'Bu kullanıcıyı admin yapmak istediğinize emin misiniz?'
            : 'Bu kullanıcının admin yetkisini kaldırmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: makeAdmin ? Colors.amber[700] : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(makeAdmin ? 'Admin Yap' : 'Kaldır'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ref.read(adminServiceProvider).toggleAdmin(userId, makeAdmin);
    if (success) {
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(makeAdmin ? 'Kullanıcı admin yapıldı.' : 'Admin yetkisi kaldırıldı.'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    }
  }

  Future<void> _toggleBan(String userId, String userName, bool ban) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          ban ? Icons.block_rounded : Icons.lock_open_rounded,
          color: ban ? Colors.red[700] : Colors.green[700],
          size: 36,
        ),
        title: Text(ban ? 'Üyeliği Sonlandır' : 'Üyeliği Geri Aç'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ban
                  ? '"$userName" kullanıcısının üyeliğini sonlandırmak istediğinize emin misiniz?'
                  : '"$userName" kullanıcısının üyeliğini yeniden aktifleştirmek istediğinize emin misiniz?',
              textAlign: TextAlign.center,
            ),
            if (ban) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kullanıcı uygulamaya giriş yapamayacak.',
                        style: TextStyle(fontSize: 12, color: Colors.red[700], fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ban ? Colors.red[700] : Colors.green[700],
              foregroundColor: Colors.white,
            ),
            child: Text(ban ? 'Üyeliği Sonlandır' : 'Üyeliği Geri Aç'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = ban
        ? await ref.read(adminServiceProvider).banUser(userId)
        : await ref.read(adminServiceProvider).unbanUser(userId);
    
    if (success) {
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ban
                ? '"$userName" üyeliği sonlandırıldı.'
                : '"$userName" üyeliği yeniden aktifleştirildi.'),
            backgroundColor: ban ? Colors.red[700] : Colors.green[700],
          ),
        );
      }
    }
  }
}
