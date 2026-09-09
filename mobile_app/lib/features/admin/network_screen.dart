import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/user.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import 'user_detail_screen.dart';

/// Network tab (ADM-09..12): Shippers / Carriers / Drivers / Expiring docs.
class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: AppColors.bitume,
          indicatorColor: AppColors.sangle,
          isScrollable: true,
          tabs: [
            Tab(text: tr(context, 'shippers')),
            Tab(text: tr(context, 'carriers')),
            Tab(text: tr(context, 'drivers')),
            Tab(text: tr(context, 'expiring_docs')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _DirectoryList(role: 'shipper'),
              _DirectoryList(role: 'carrier'),
              _DirectoryList(role: 'driver'),
              _ExpiringDocsList(),
            ],
          ),
        ),
      ],
    );
  }
}

class _DirectoryList extends StatefulWidget {
  const _DirectoryList({required this.role});
  final String role;

  @override
  State<_DirectoryList> createState() => _DirectoryListState();
}

class _DirectoryListState extends State<_DirectoryList> {
  List<AppUser> _users = const [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = <String, dynamic>{'role': widget.role};
      if (_statusFilter != null) query['status'] = _statusFilter;
      if (_searchCtrl.text.trim().isNotEmpty) query['search'] = _searchCtrl.text.trim();
      final res = await ApiClient.instance.get('/users', query: query);
      final list = (res.data as List).map((e) => AppUser.fromJson(e)).toList();
      setState(() {
        _users = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = tr(context, 'error_generic');
        _loading = false;
      });
    }
  }

  Future<void> _setStatus(AppUser u, String status) async {
    try {
      await ApiClient.instance.put('/users/${u.id}/status', data: {'status': status});
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'error_generic'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = context.watch<AuthService>().currentUser?.adminSubRole == 'lecture';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(labelText: tr(context, 'search_users'), prefixIcon: const Icon(Icons.search)),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), _load);
                  },
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _statusFilter,
                hint: Text(tr(context, 'account_status')),
                items: [
                  DropdownMenuItem(value: null, child: Text(tr(context, 'all_statuses'))),
                  DropdownMenuItem(value: 'pending', child: Text(tr(context, 'status_pending'))),
                  DropdownMenuItem(value: 'active', child: Text(tr(context, 'status_active'))),
                  DropdownMenuItem(value: 'blocked', child: Text(tr(context, 'status_blocked'))),
                  DropdownMenuItem(value: 'rejected', child: Text(tr(context, 'status_rejected'))),
                ],
                onChanged: (v) {
                  setState(() => _statusFilter = v);
                  _load();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _users.isEmpty
                      ? EmptyState(message: tr(context, 'no_users_found'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                              final u = _users[i];
                              return Card(
                                child: ListTile(
                                  title: Text(u.displayName),
                                  subtitle: Text(u.phone),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.statusColor(u.status).withValues(alpha: 0.15),
                                    child: Icon(Icons.person, color: AppColors.statusColor(u.status)),
                                  ),
                                  trailing: readOnly
                                      ? Text(tr(context, 'status_${u.status}'))
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (u.status == 'pending') ...[
                                              IconButton(
                                                tooltip: tr(context, 'approve'),
                                                icon: const Icon(Icons.check_circle_outline, color: AppColors.convoi),
                                                onPressed: () => _setStatus(u, 'active'),
                                              ),
                                              IconButton(
                                                tooltip: tr(context, 'reject'),
                                                icon: const Icon(Icons.cancel_outlined, color: AppColors.halte),
                                                onPressed: () => _setStatus(u, 'rejected'),
                                              ),
                                            ] else if (u.status == 'active')
                                              IconButton(
                                                tooltip: tr(context, 'block'),
                                                icon: const Icon(Icons.block, color: AppColors.halte),
                                                onPressed: () => _setStatus(u, 'blocked'),
                                              ),
                                          ],
                                        ),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => UserDetailScreen(userId: u.id)),
                                    );
                                    _load();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _ExpiringDocsList extends StatefulWidget {
  const _ExpiringDocsList();

  @override
  State<_ExpiringDocsList> createState() => _ExpiringDocsListState();
}

class _ExpiringDocsListState extends State<_ExpiringDocsList> {
  List<dynamic> _users = const [];
  List<dynamic> _vehicles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get('/users/alerts/documents', query: {'days': 30});
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _users = data['users'] as List? ?? const [];
        _vehicles = data['vehicles'] as List? ?? const [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_users.isEmpty && _vehicles.isEmpty) {
      return EmptyState(message: tr(context, 'no_document_alerts'), icon: Icons.verified_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final u in _users)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person, color: AppColors.halte),
                title: Text((u['companyName'] ?? u['fullName'] ?? u['phone'] ?? '').toString()),
                subtitle: Text(u['role']?.toString() ?? ''),
                onTap: () {
                  if (u['_id'] != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => UserDetailScreen(userId: u['_id'].toString())),
                    );
                  }
                },
              ),
            ),
          for (final v in _vehicles)
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_shipping, color: AppColors.halte),
                title: Text((v['plateNumber'] ?? v['brand'] ?? '').toString()),
                subtitle: Text(v['model']?.toString() ?? ''),
              ),
            ),
        ],
      ),
    );
  }
}
