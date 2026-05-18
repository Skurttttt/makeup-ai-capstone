// lib/screens/admin_accounts_section.dart
// Accounts section: user table with search/filter/pagination,
// add/edit/delete dialogs, and CSV export.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../utils/export_helper.dart';
import '../utils/responsive.dart';
import 'admin_shared.dart';

class AdminAccountsSection extends StatefulWidget {
  const AdminAccountsSection({super.key});

  @override
  State<AdminAccountsSection> createState() => _AdminAccountsSectionState();
}

class _AdminAccountsSectionState extends State<AdminAccountsSection> {
  final _supabaseService = SupabaseService();
  final _searchController = TextEditingController();

  List<dynamic> _users = [];
  List<dynamic> _subscriptions = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _roleFilter = 'all';
  int _page = 0;
  static const int _pageSize = 10;
  bool _isExporting = false;
  double _exportProgress = 0.0;

  double get _sectionPadding =>
      context.responsive(compact: 16, medium: 20, expanded: 24, large: 28);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _supabaseService.getAllUsers(),
        _supabaseService.getAllSubscriptions(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<dynamic>;
        _subscriptions = results[1] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, Map<String, dynamic>> get _userSubMap {
    final map = <String, Map<String, dynamic>>{};
    for (var sub in _subscriptions) {
      final userId = sub['user_id']?.toString();
      if (userId != null && !map.containsKey(userId)) {
        map[userId] = Map<String, dynamic>.from(sub as Map);
      }
    }
    return map;
  }

  List<dynamic> get _filteredUsers {
    return _users.where((user) {
      final matchesSearch = _searchQuery.isEmpty ||
          (user['full_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (user['email']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesRole = _roleFilter == 'all' || user['role']?.toString() == _roleFilter;
      return matchesSearch && matchesRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AdminTheme.accentColor));
    }

    if (_error != null) {
      return Center(
        child: buildErrorState('Failed to load accounts',
            details: _error, onRetry: _loadData),
      );
    }

    final subMap = _userSubMap;
    final filtered = _filteredUsers;
    final totalPages = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
    final paginated = filtered.skip(_page * _pageSize).take(_pageSize).toList();

    final adminCount = _users.where((u) => u['role'] == 'admin').length;
    final subscriberCount = subMap.values
        .where((s) => s['status']?.toString() == 'active')
        .length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(_sectionPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ Header â”€â”€
          buildSectionHeader(
            context,
            'Account Management',
            actions: [
              ElevatedButton.icon(
                onPressed: _showAddAccountDialog,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Add Account'),
                style: primaryButtonStyle(AdminTheme.accentColor),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadData,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AdminTheme.cardColor,
                  side: const BorderSide(color: AdminTheme.borderColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // â”€â”€ KPI Cards â”€â”€
          buildAdaptiveCardGrid(
            minWidth: 160,
            children: [
              buildSummaryCard('Total Users', '${_users.length}',
                  Icons.people_rounded, AdminTheme.accentColor),
              buildSummaryCard('Active Subscribers', '$subscriberCount',
                  Icons.verified_rounded, AdminTheme.successColor),
              buildSummaryCard('Admins', '$adminCount',
                  Icons.shield_rounded, AdminTheme.warningColor),
              buildSummaryCard(
                  'Regular Users',
                  '${_users.where((u) => u['role'] == 'user').length}',
                  Icons.person_rounded,
                  AdminTheme.textSecondary),
            ],
          ),
          const SizedBox(height: 24),

          // â”€â”€ Filter Bar â”€â”€
          buildFilterBar(
            searchController: _searchController,
            searchHint: 'Search by name or email...',
            searchQuery: _searchQuery,
            onSearchChanged: (v) => setState(() { _searchQuery = v; _page = 0; }),
            onClearSearch: () {
              _searchController.clear();
              setState(() { _searchQuery = ''; _page = 0; });
            },
            filters: [
              FilterDropdown(
                value: _roleFilter,
                label: 'Role',
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Roles')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'user', child: Text('User')),
                ],
                onChanged: (v) => setState(() { _roleFilter = v ?? _roleFilter; _page = 0; }),
              ),
            ],
            onResetFilters: () {
              _searchController.clear();
              setState(() { _searchQuery = ''; _roleFilter = 'all'; _page = 0; });
            },
            showExport: true,
            onExport: () => _exportAccounts(filtered),
            isExporting: _isExporting,
            exportProgress: _exportProgress,
          ),
          const SizedBox(height: 12),

          // Results count
          if (_users.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} account${filtered.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AdminTheme.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                  if (_searchQuery.isNotEmpty || _roleFilter != 'all')
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text('(filtered)',
                          style: TextStyle(
                              fontSize: 12,
                              color: AdminTheme.accentColor.withOpacity(0.8))),
                    ),
                ],
              ),
            ),

          // â”€â”€ User Cards â”€â”€
          if (filtered.isEmpty)
            _buildEmptyState(
              _searchQuery.isNotEmpty || _roleFilter != 'all'
                  ? 'No accounts match your filters'
                  : 'No accounts yet',
              Icons.people_outline_rounded,
            )
          else ...[
            ...paginated.map((user) => _buildUserCard(user, subMap)).toList(),
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _page > 0 ? () => setState(() => _page--) : null,
                        icon: const Icon(Icons.chevron_left_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                      Text('Page ${_page + 1} of $totalPages',
                          style: const TextStyle(
                              fontSize: 13,
                              color: AdminTheme.textSecondary,
                              fontWeight: FontWeight.w500)),
                      IconButton(
                        onPressed: _page < totalPages - 1
                            ? () => setState(() => _page++)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        color: AdminTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderColor),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AdminTheme.textSecondary.withOpacity(0.08),
                  shape: BoxShape.circle),
              child: Icon(icon,
                  size: 40, color: AdminTheme.textSecondary.withOpacity(0.4)),
            ),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.textPrimary)),
            const SizedBox(height: 6),
            Text('Try adjusting your filters or adding a new account.',
                style: TextStyle(
                    fontSize: 13,
                    color: AdminTheme.textSecondary.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(
      Map<String, dynamic> user, Map<String, Map<String, dynamic>> subMap) {
    final name = user['full_name']?.toString() ?? 'Unknown';
    final email = user['email']?.toString() ?? '';
    final role = user['role']?.toString() ?? 'user';
    final createdAt = DateTime.tryParse(user['created_at']?.toString() ?? '');
    final sub = subMap[user['id']?.toString()];
    final planName = sub?['subscription_plans']?['name']?.toString() ??
        sub?['subscription_plans']?['display_name']?.toString() ??
        'Free';
    final subStatus = sub?['status']?.toString() ?? 'inactive';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isAdmin = role == 'admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AdminTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAdmin
              ? AdminTheme.warningColor.withOpacity(0.3)
              : AdminTheme.borderColor,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: isAdmin
                    ? LinearGradient(colors: [
                        AdminTheme.warningColor,
                        AdminTheme.warningColor.withOpacity(0.7)
                      ])
                    : AdminTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AdminTheme.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? AdminTheme.warningColor.withOpacity(0.12)
                              : AdminTheme.accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isAdmin
                                ? AdminTheme.warningColor.withOpacity(0.3)
                                : AdminTheme.accentColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAdmin
                                  ? Icons.shield_rounded
                                  : Icons.person_rounded,
                              size: 11,
                              color: isAdmin
                                  ? AdminTheme.warningColor
                                  : AdminTheme.accentColor,
                            ),
                            const SizedBox(width: 3),
                            Text(role.toUpperCase(),
                                style: TextStyle(
                                    color: isAdmin
                                        ? AdminTheme.warningColor
                                        : AdminTheme.accentColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(email,
                        style: const TextStyle(
                            fontSize: 12, color: AdminTheme.textSecondary),
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _infoChip(Icons.card_membership_rounded, planName,
                          subStatus == 'active'
                              ? AdminTheme.successColor
                              : AdminTheme.textSecondary),
                      _infoChip(
                          subStatus == 'active'
                              ? Icons.check_circle_outline_rounded
                              : Icons.radio_button_unchecked_rounded,
                          subStatus,
                          subStatus == 'active'
                              ? AdminTheme.successColor
                              : AdminTheme.textSecondary),
                      if (createdAt != null)
                        _infoChip(
                            Icons.calendar_today_outlined,
                            'Joined ${DateFormat('MMM yyyy').format(createdAt)}',
                            AdminTheme.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Actions
            Column(
              children: [
                buildTableActionButton(Icons.edit_rounded, 'Edit',
                    AdminTheme.accentColor, () => _showEditAccountDialog(user)),
                const SizedBox(height: 6),
                buildTableActionButton(Icons.delete_rounded, 'Delete',
                    AdminTheme.dangerColor,
                    () => _showDeleteAccountDialog(user)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withOpacity(0.85)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ==================== DIALOGS ====================

  void _showAddAccountDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'user';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AdminTheme.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.person_add_rounded,
                  color: AdminTheme.accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Add New Account'),
          ]),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter full name',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter email address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Password is required';
                      if (v.length < 6) return 'Minimum 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text('User')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => role = v ?? 'user'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);
                      try {
                        await _supabaseService.client.auth.admin.createUser(
                          AdminUserAttributes(
                            email: emailController.text.trim(),
                            password: passwordController.text,
                            emailConfirm: true,
                            userMetadata: {
                              'full_name': nameController.text.trim(),
                              'role': role,
                            },
                          ),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          _loadData();
                          showAdminSnackBar(context,
                              'Account created successfully',
                              isError: false);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showAdminSnackBar(context, 'Error: $e',
                              isError: true);
                        }
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => isLoading = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAccountDialog(Map<String, dynamic> account) {
    final formKey = GlobalKey<FormState>();
    final nameController =
        TextEditingController(text: account['full_name']?.toString() ?? '');
    String role = account['role']?.toString() ?? 'user';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AdminTheme.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.edit_rounded,
                  color: AdminTheme.accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Edit Account'),
          ]),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminTheme.borderColor),
                  ),
                  child: Row(children: [
                    const Icon(Icons.email_outlined,
                        size: 18, color: AdminTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text('Email: ${account['email']}',
                        style: const TextStyle(
                            color: AdminTheme.textSecondary, fontSize: 14)),
                  ]),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('User')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => role = v ?? 'user'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);
                      try {
                        await _supabaseService.updateUserProfile(
                          userId: account['id']?.toString() ?? '',
                          updates: {
                            'full_name': nameController.text.trim(),
                            'role': role,
                          },
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          _loadData();
                          showAdminSnackBar(
                              context, 'Account updated successfully',
                              isError: false);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showAdminSnackBar(context, 'Error: $e',
                              isError: true);
                        }
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => isLoading = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(Map<String, dynamic> account) {
    final name = account['full_name']?.toString() ?? 'this user';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AdminTheme.dangerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.warning_rounded,
                color: AdminTheme.dangerColor, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Delete Account'),
        ]),
        content: Text(
          'Are you sure you want to delete "$name"? This action cannot be undone.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _supabaseService.client.auth.admin
                    .deleteUser(account['id']?.toString() ?? '');
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadData();
                  showAdminSnackBar(
                      context, 'Account deleted successfully',
                      isError: false);
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  showAdminSnackBar(context, 'Error: $e', isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.dangerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ==================== EXPORT ====================

  void _exportAccounts(List<dynamic> accounts) async {
    setState(() {
      _isExporting = true;
      _exportProgress = 0;
    });
    try {
      final buffer = StringBuffer();
      buffer.writeln('Name,Email,Role,Created');
      for (var i = 0; i < accounts.length; i++) {
        final a = accounts[i];
        buffer.writeln(
            '${a['full_name']},${a['email']},${a['role']},${a['created_at']}');
        if (mounted) {
          setState(() => _exportProgress = (i + 1) / accounts.length);
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));
      await saveCsvFile('accounts_export.csv', buffer.toString());
      if (mounted) {
        showAdminSnackBar(context, 'Accounts exported successfully',
            isError: false);
      }
    } catch (e) {
      if (mounted) {
        showAdminSnackBar(context, 'Export failed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportProgress = 1.0;
        });
      }
    }
  }
}
