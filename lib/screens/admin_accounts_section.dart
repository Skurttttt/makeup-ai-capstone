// lib/screens/admin_accounts_section.dart
// Accounts section: user table with search/filter/pagination,
// add/edit/delete dialogs, and CSV export.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../utils/export_helper.dart';
import '../utils/responsive.dart';
import 'admin_shared.dart';
import '../widgets/admin_dialog.dart';

class AdminAccountsSection extends StatefulWidget {
  final bool isSuperAdmin;
  const AdminAccountsSection({super.key, this.isSuperAdmin = false});

  @override
  State<AdminAccountsSection> createState() => _AdminAccountsSectionState();
}

class _AdminAccountsSectionState extends State<AdminAccountsSection> {
  final _supabaseService = SupabaseService();
  final _searchController = TextEditingController();

  List<dynamic> _users = [];
  List<dynamic> _subscriptions = [];
  List<Map<String, dynamic>> _plans = [];
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _supabaseService.getAllUsers(),
        _supabaseService.getAllSubscriptions(),
        _supabaseService.getAllPlans(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<dynamic>;
        _subscriptions = results[1] as List<dynamic>;
        _plans = List<Map<String, dynamic>>.from(results[2] as List<dynamic>);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
          (user['full_name']
                  ?.toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ??
              false) ||
          (user['email']
                  ?.toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ??
              false);
      final matchesRole =
          _roleFilter == 'all' || user['role']?.toString() == _roleFilter;
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
    final totalPages =
        filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
    final paginated =
        filtered.skip(_page * _pageSize).take(_pageSize).toList();

    final subscriberCount = subMap.values
        .where((s) => s['status']?.toString() == 'active')
        .length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(_sectionPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
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

          // ── KPI Cards ──
          buildAdaptiveCardGrid(
            minWidth: 160,
            children: [
              buildSummaryCard('Total Accounts', '${_users.length}',
                  Icons.people_rounded, AdminTheme.accentColor),
              buildSummaryCard('Active Subscribers', '$subscriberCount',
                  Icons.verified_rounded, AdminTheme.successColor),
              buildSummaryCard('Admins / Super',
                  '${_users.where((u) => u['role'] == 'admin' || u['role'] == 'super_admin').length}',
                  Icons.shield_rounded, AdminTheme.warningColor),
              buildSummaryCard('Staff',
                  '${_users.where((u) => u['role'] == 'staff').length}',
                  Icons.badge_rounded, AdminTheme.successColor),
              buildSummaryCard('Users',
                  '${_users.where((u) => u['role'] == 'user').length}',
                  Icons.person_rounded,
                  AdminTheme.textSecondary),
            ],
          ),
          const SizedBox(height: 24),

          // ── Filter Bar ──
          buildFilterBar(
            searchController: _searchController,
            searchHint: 'Search by name or email...',
            searchQuery: _searchQuery,
            onSearchChanged: (v) =>
                setState(() {
                  _searchQuery = v;
                  _page = 0;
                }),
            onClearSearch: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _page = 0;
              });
            },
            filters: [
              FilterDropdown(
                value: _roleFilter,
                label: 'Role',
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Roles')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'user', child: Text('User')),
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                ],
                onChanged: (v) => setState(() {
                  _roleFilter = v ?? _roleFilter;
                  _page = 0;
                }),
              ),
            ],
            onResetFilters: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _roleFilter = 'all';
                _page = 0;
              });
            },
            showExport: true,
            onExport: () => _exportAccounts(_users),
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
                              color:
                                  AdminTheme.accentColor.withOpacity(0.8))),
                    ),
                ],
              ),
            ),

          // ── User Cards ──
          if (filtered.isEmpty)
            _buildEmptyState(
              _searchQuery.isNotEmpty || _roleFilter != 'all'
                  ? 'No accounts match your filters'
                  : 'No accounts yet',
              Icons.people_outline_rounded,
            )
          else ...[
            ...paginated
                .map((user) => _buildUserCard(user, subMap))
                .toList(),
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _page > 0
                            ? () => setState(() => _page--)
                            : null,
                        icon:
                            const Icon(Icons.chevron_left_rounded, size: 20),
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
                        icon: const Icon(Icons.chevron_right_rounded,
                            size: 20),
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
                  size: 40,
                  color: AdminTheme.textSecondary.withOpacity(0.4)),
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
    final createdAt =
        DateTime.tryParse(user['created_at']?.toString() ?? '');
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
                            fontSize: 12,
                            color: AdminTheme.textSecondary),
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
                if (widget.isSuperAdmin ||
                    (user['role']?.toString() ?? '') != 'super_admin') ...[
                  buildTableActionButton(
                      Icons.edit_rounded,
                      'Edit',
                      AdminTheme.accentColor,
                      () => _showEditAccountDialog(user)),
                  const SizedBox(height: 6),
                  buildTableActionButton(
                      Icons.delete_rounded,
                      'Delete',
                      AdminTheme.dangerColor,
                      () => _showDeleteAccountDialog(user)),
                ] else
                  Tooltip(
                    message: 'Super Admin — restricted',
                    child: Icon(Icons.lock_rounded,
                        size: 18, color: Colors.grey.shade400),
                  ),
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
    String role = 'staff';
    bool isLoading = false;
    bool showPassword = false;
    String? selectedPlanId;
    String passwordStrength = '';
    double passwordProgress = 0.0;

    void calculatePasswordStrength(String password) {
      double strength = 0;
      String label = '';

      if (password.length >= 6) strength += 0.3;
      if (password.length >= 8) strength += 0.2;
      if (password.length >= 12) strength += 0.2;
      if (password.contains(RegExp(r'[A-Z]'))) strength += 0.1;
      if (password.contains(RegExp(r'[0-9]'))) strength += 0.1;
      if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')))
        strength += 0.1;

      if (strength < 0.3) {
        label = 'Weak';
      } else if (strength < 0.6) {
        label = 'Fair';
      } else if (strength < 0.8) {
        label = 'Strong';
      } else {
        label = 'Very Strong';
      }

      passwordProgress = strength.clamp(0.0, 1.0);
      passwordStrength = label;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_add_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Add a new user to the platform',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white70,
                        iconSize: 22,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Step indicator
                          Row(
                            children: [
                              _buildStepChip('Account Details', true),
                              const SizedBox(width: 8),
                              Container(
                                width: 24,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStepChip('Plan & Role', false),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Name field
                          _buildInputLabel('Full Name'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: nameController,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _buildInputDecoration(
                              hintText: 'e.g., John Doe',
                              prefixIcon: Icons.person_outline_rounded,
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty
                                    ? 'Name is required'
                                    : null,
                          ),
                          const SizedBox(height: 20),

                          // Email field
                          _buildInputLabel('Email Address'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: emailController,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _buildInputDecoration(
                              hintText: 'e.g., john@example.com',
                              prefixIcon: Icons.email_outlined,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Email is required';
                              if (!v.contains('@'))
                                return 'Please enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password field
                          _buildInputLabel('Password'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: passwordController,
                            obscureText: !showPassword,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _buildInputDecoration(
                              hintText: 'Min. 6 characters',
                              prefixIcon: Icons.lock_outlined,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showPassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 20,
                                ),
                                onPressed: () => setDialogState(
                                    () => showPassword = !showPassword),
                              ),
                            ),
                            onChanged: (value) {
                              calculatePasswordStrength(value);
                              setDialogState(() {});
                            },
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Password is required';
                              if (v.length < 6)
                                return 'Minimum 6 characters';
                              return null;
                            },
                          ),

                          // Password strength indicator
                          if (passwordController.text.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: passwordProgress,
                                          minHeight: 6,
                                          backgroundColor:
                                              Colors.grey.shade200,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            passwordProgress < 0.3
                                                ? Colors.red
                                                : passwordProgress < 0.6
                                                    ? Colors.orange
                                                    : passwordProgress <
                                                            0.8
                                                        ? Colors.blue
                                                        : Colors.green,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: passwordProgress < 0.3
                                            ? Colors.red.withOpacity(0.1)
                                            : passwordProgress < 0.6
                                                ? Colors.orange
                                                    .withOpacity(0.1)
                                                : passwordProgress < 0.8
                                                    ? Colors.blue
                                                        .withOpacity(0.1)
                                                    : Colors.green
                                                        .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        passwordStrength,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: passwordProgress < 0.3
                                              ? Colors.red
                                              : passwordProgress < 0.6
                                                  ? Colors.orange
                                                  : passwordProgress < 0.8
                                                      ? Colors.blue
                                                      : Colors.green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _buildPasswordRequirement(
                                      '6+ chars',
                                      passwordController.text.length >= 6,
                                    ),
                                    _buildPasswordRequirement(
                                      'Uppercase',
                                      passwordController.text
                                          .contains(RegExp(r'[A-Z]')),
                                    ),
                                    _buildPasswordRequirement(
                                      'Number',
                                      passwordController.text
                                          .contains(RegExp(r'[0-9]')),
                                    ),
                                    _buildPasswordRequirement(
                                      'Special char',
                                      passwordController.text.contains(
                                          RegExp(
                                              r'[!@#$%^&*(),.?":{}|<>]')),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 24),

                          // Divider
                          Container(
                            height: 1,
                            color: Colors.grey.shade200,
                          ),
                          const SizedBox(height: 24),

                          // Role Selection
                          _buildInputLabel('Account Role'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildRoleCard(
                                  icon: Icons.people_rounded,
                                  title: 'Staff',
                                  subtitle: 'Staff access',
                                  isSelected: role == 'staff',
                                  onTap: () => setDialogState(() => role = 'staff'),
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildRoleCard(
                                  icon: Icons.admin_panel_settings_rounded,
                                  title: 'Admin',
                                  subtitle: 'Full access',
                                  isSelected: role == 'admin',
                                  onTap: () => setDialogState(() => role = 'admin'),
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Plan Selection
                          if (_plans.isNotEmpty) ...[
                            _buildInputLabel(
                                'Subscription Plan (Optional)'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selectedPlanId,
                              decoration: _buildInputDecoration(
                                prefixIcon: Icons.card_membership_rounded,
                                hintText: 'Select a plan',
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1F2937),
                              ),
                              items: [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text(
                                    'No plan (Free)',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                ..._plans.map(
                                  (p) => DropdownMenuItem<String>(
                                    value: p['id']?.toString(),
                                    child: Text(
                                      p['display_name'] ??
                                          p['name'] ??
                                          'Plan',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setDialogState(
                                  () => selectedPlanId = v),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Footer with actions
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                                onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate())
                                    return;
                                  setDialogState(() => isLoading = true);
                                  try {
                                    final email =
                                        emailController.text.trim();
                                    final exists = await _supabaseService
                                        .emailExists(email);
                                    if (exists) {
                                      if (context.mounted) {
                                        showAdminSnackBar(
                                          context,
                                          'Email already exists',
                                          isError: true,
                                        );
                                      }
                                      setDialogState(
                                          () => isLoading = false);
                                      return;
                                    }

                                    // Prevent creating plain 'user' accounts via admin UI
                                    if (role == 'user') {
                                      if (context.mounted) {
                                        showAdminSnackBar(
                                          context,
                                          'Cannot create role "user" from admin panel. Users must register through the app.',
                                          isError: true,
                                        );
                                      }
                                      setDialogState(() => isLoading = false);
                                      return;
                                    }

                                    await _supabaseService
                                        .client.auth.admin
                                        .createUser(
                                      AdminUserAttributes(
                                        email: email,
                                        password:
                                            passwordController.text,
                                        emailConfirm: true,
                                        userMetadata: {
                                          'full_name': nameController
                                              .text
                                              .trim(),
                                          'role': role,
                                        },
                                      ),
                                    );

                                    await _loadData();
                                    if (selectedPlanId != null) {
                                      Map<String, dynamic>? created;
                                      for (var u in _users) {
                                        final ue =
                                            (u['email']?.toString() ??
                                                    '')
                                                .toLowerCase();
                                        if (ue == email.toLowerCase()) {
                                          created =
                                              Map<String,
                                                  dynamic>.from(
                                                  u as Map);
                                          break;
                                        }
                                      }
                                      if (created != null) {
                                        await _supabaseService
                                            .createUserSubscription(
                                          accountId:
                                              created['id']?.toString() ??
                                                  '',
                                          planId: selectedPlanId!,
                                          status: 'active',
                                          currentPeriodEnd:
                                              DateTime.now().add(
                                            const Duration(days: 30),
                                          ),
                                        );
                                      }
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      _loadData();
                                      showAdminSnackBar(
                                        context,
                                        'Account created successfully',
                                        isError: false,
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showAdminSnackBar(
                                        context,
                                        'Error: $e',
                                        isError: true,
                                      );
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setDialogState(
                                          () => isLoading = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_add_rounded,
                                        size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Create Account',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods for the new UI
  Widget _buildStepChip(String label, bool isActive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF4F46E5)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? const Color(0xFF4F46E5)
                  : Colors.grey.shade400,
              width: 2,
            ),
          ),
          child: isActive
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive
                ? const Color(0xFF4F46E5)
                : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
        letterSpacing: -0.2,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required IconData prefixIcon,
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, size: 20, color: const Color(0xFF6B7280)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFF4F46E5), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? color : Colors.grey.shade500,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? color.withOpacity(0.7)
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordRequirement(String label, bool isMet) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 12,
          color: isMet ? Colors.green : Colors.grey.shade400,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isMet ? Colors.green.shade700 : Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _showEditAccountDialog(
      Map<String, dynamic> account) async {
    final formKey = GlobalKey<FormState>();
    final nameController =
        TextEditingController(text: account['full_name']?.toString() ?? '');
    String role = account['role']?.toString() ?? 'user';
    bool isLoading = false;

    final userId = account['id']?.toString() ?? '';
    List<Map<String, dynamic>> userSubs = [];
    try {
      userSubs = await _supabaseService.getUserSubscriptions(userId);
    } catch (_) {
      userSubs = [];
    }

    String? selectedPlanId = userSubs.isNotEmpty
        ? (userSubs.first['plan_id']?.toString() ??
            userSubs.first['subscription_plans']?['id']?.toString())
        : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Account',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Update account details',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white70,
                        iconSize: 22,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildInputLabel('Full Name'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: nameController,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _buildInputDecoration(
                              hintText: 'e.g., John Doe',
                              prefixIcon: Icons.person_outline_rounded,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Name is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _buildInputLabel('Email'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(account['email']?.toString() ?? ''),
                          ),
                          const SizedBox(height: 16),

                          // Role cards
                          _buildInputLabel('Account Role'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildRoleCard(
                                  icon: Icons.people_rounded,
                                  title: 'Staff',
                                  subtitle: 'Staff access',
                                  isSelected: role == 'staff',
                                  onTap: () => setDialogState(() => role = 'staff'),
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildRoleCard(
                                  icon: Icons.admin_panel_settings_rounded,
                                  title: 'Admin',
                                  subtitle: 'Full access',
                                  isSelected: role == 'admin',
                                  onTap: () => setDialogState(() => role = 'admin'),
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (_plans.isNotEmpty) ...[
                            _buildInputLabel('Subscription Plan'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selectedPlanId,
                              decoration: _buildInputDecoration(
                                  prefixIcon: Icons.card_membership_rounded,
                                  hintText: 'Select a plan'),
                              items: [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('No plan (Free)',
                                      style: TextStyle(
                                          color: Colors.grey.shade600)),
                                ),
                                ..._plans.map((p) => DropdownMenuItem<String>(
                                      value: p['id']?.toString(),
                                      child: Text(p['display_name'] ?? p['name'] ?? 'Plan'),
                                    )),
                              ],
                              onChanged: (v) => setDialogState(() => selectedPlanId = v),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() => isLoading = true);
                                  try {
                                    await _supabaseService.updateUserProfile(
                                        userId: userId,
                                        updates: {
                                          'full_name': nameController.text.trim(),
                                          'role': role,
                                        });

                                    // handle subscription updates same as before
                                    if (selectedPlanId != null) {
                                      if (userSubs.isNotEmpty) {
                                        final subId = userSubs.first['id']?.toString() ?? '';
                                        if (subId.isNotEmpty) {
                                          await _supabaseService.updateSubscription(
                                              subscriptionId: subId,
                                              updates: {
                                                'plan_id': selectedPlanId,
                                                'status': 'active',
                                                'current_period_end': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
                                              });
                                        }
                                      } else {
                                        await _supabaseService.createUserSubscription(
                                            accountId: userId,
                                            planId: selectedPlanId!,
                                            status: 'active',
                                            currentPeriodEnd: DateTime.now().add(const Duration(days: 30)));
                                      }
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      _loadData();
                                      showAdminSnackBar(context, 'Account updated successfully', isError: false);
                                    }
                                  } catch (e) {
                                    if (context.mounted) showAdminSnackBar(context, 'Error: $e', isError: true);
                                  } finally {
                                    if (context.mounted) setDialogState(() => isLoading = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.save_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(Map<String, dynamic> account) {
    final name = account['full_name']?.toString() ?? 'this user';
    showDialog(
      context: context,
      builder: (context) => adminAlertDialog(
        borderRadius: 16,
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
                  showAdminSnackBar(context, 'Account deleted successfully',
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
      // UTF-8 BOM so Excel opens without garbling
      buffer.write('\uFEFF');
      buffer.writeln('Name,Email,Role,Plan,Created');
      final subMap = _userSubMap;
      for (var i = 0; i < accounts.length; i++) {
        final a = accounts[i];
        final sub = subMap[a['id']?.toString()];
        final planName = sub?['subscription_plans']?['display_name']?.toString() ??
            sub?['subscription_plans']?['name']?.toString() ?? '';
        buffer.writeln([
          _csvField(a['full_name']?.toString() ?? ''),
          _csvField(a['email']?.toString() ?? ''),
          _csvField(a['role']?.toString() ?? ''),
          _csvField(planName),
          _csvField(a['created_at']?.toString() ?? ''),
        ].join(','));
        if (mounted) {
          setState(() => _exportProgress = (i + 1) / accounts.length);
        }
      }
      await Future.delayed(const Duration(milliseconds: 300));
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final savedPath =
          await saveCsvFile('accounts_all_$ts.csv', buffer.toString());
      if (mounted) {
        if (savedPath != null) {
          final filename = savedPath.split(RegExp(r'[\\/]')).last;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Exported ${accounts.length} accounts → $filename'),
            action: SnackBarAction(label: 'Open', onPressed: () async {
              try {
                await launchUrl(Uri.file(savedPath));
              } catch (_) {}
            }),
          ));
        } else {
          showAdminSnackBar(context, 'Export cancelled', isError: false);
        }
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

  String _csvField(String? value) {
    final v = (value ?? '').replaceAll('"', '""');
    return '"$v"';
  }
}