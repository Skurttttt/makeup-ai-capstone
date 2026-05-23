// lib/screens/admin_subscriptions_section.dart
// Subscriptions section: subscription-plans table, user-subscriptions table
// with search/filter/pagination, and all management dialogs.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../utils/responsive.dart';
import 'admin_shared.dart';

class AdminSubscriptionsSection extends StatefulWidget {
  const AdminSubscriptionsSection({super.key});

  @override
  State<AdminSubscriptionsSection> createState() =>
      _AdminSubscriptionsSectionState();
}

class _AdminSubscriptionsSectionState
    extends State<AdminSubscriptionsSection> {
  final _supabaseService = SupabaseService();
  final _searchController = TextEditingController();

  List<dynamic> _subscriptions = [];
  List<dynamic> _plans = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'all';
  int _page = 0;
  static const int _pageSize = 10;

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
        _supabaseService.getAllSubscriptions(),
        _supabaseService.getAllPlans(),
      ]);
      if (!mounted) return;
      setState(() {
        _subscriptions = results[0] as List<dynamic>;
        _plans = results[1] as List<dynamic>;
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

  List<dynamic> get _filteredSubs {
    return _subscriptions.where((sub) {
      final matchesSearch = _searchQuery.isEmpty ||
          (sub['accounts']?['full_name']
                  ?.toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ??
              false) ||
          (sub['subscription_plans']?['name']
                  ?.toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ??
              false) ||
          (sub['accounts']?['email']
                  ?.toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ??
              false);
      final matchesStatus =
          _statusFilter == 'all' || sub['status']?.toString() == _statusFilter;
      return matchesSearch && matchesStatus;
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
        child: buildErrorState(
          'Failed to load subscriptions',
          details: _error,
          onRetry: _loadData,
        ),
      );
    }

    // Show all active plans (don't filter by name since plan names vary)
    final plans = _plans.where((plan) {
      return plan['is_active'] != false;
    }).toList();

    final filtered = _filteredSubs;
    final totalPages = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
    final paginated = filtered.skip(_page * _pageSize).take(_pageSize).toList();

    final activeCount = _subscriptions.where((s) => s['status'] == 'active').length;
    final trialCount = _subscriptions.where((s) => s['status'] == 'trial').length;
    final expiredCount = _subscriptions
        .where((s) => s['status'] == 'expired' || s['status'] == 'canceled')
        .length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(_sectionPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // In-page section header removed — top bar shows section title
          const SizedBox(height: 12),

          // ── KPI Cards ──
          buildAdaptiveCardGrid(
            minWidth: 160,
            children: [
              buildSummaryCard('Total', '${_subscriptions.length}',
                  Icons.subscriptions_rounded, AdminTheme.accentColor),
              buildSummaryCard('Active', '$activeCount',
                  Icons.check_circle_rounded, AdminTheme.successColor),
              buildSummaryCard('Trial', '$trialCount',
                  Icons.star_half_rounded, AdminTheme.warningColor),
              buildSummaryCard('Expired / Canceled', '$expiredCount',
                  Icons.cancel_rounded, AdminTheme.dangerColor),
            ],
          ),
          const SizedBox(height: 32),

          // ── Plans Table ──
          buildSectionHeader(
            context,
            'Subscription Plans',
            isSubsection: true,
            actions: [
              ElevatedButton.icon(
                onPressed: () => _showAssignSubscriptionDialog(_plans),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Assign'),
                style: primaryButtonStyle(AdminTheme.accentColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (plans.isEmpty)
            _buildEmptyState('No subscription plans configured',
                Icons.card_membership_rounded)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth < 560
                    ? 1
                    : constraints.maxWidth < 920
                        ? 2
                        : 3;
                const spacing = 16.0;
                final cardW =
                    (constraints.maxWidth - spacing * (count - 1)) / count;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: plans
                      .map((plan) => SizedBox(
                            width: cardW,
                            child: _buildPlanCard(plan),
                          ))
                      .toList(),
                );
              },
            ),
          const SizedBox(height: 32),

          // ── User Subscriptions ──
          buildSectionHeader(context, 'User Subscriptions', isSubsection: true),
          const SizedBox(height: 12),
          buildFilterBar(
            searchController: _searchController,
            searchHint: 'Search by name, email, or plan...',
            searchQuery: _searchQuery,
            onSearchChanged: (v) => setState(() {
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
                value: _statusFilter,
                label: 'Status',
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'trial', child: Text('Trial')),
                  DropdownMenuItem(value: 'past_due', child: Text('Past Due')),
                  DropdownMenuItem(value: 'canceled', child: Text('Canceled')),
                  DropdownMenuItem(value: 'expired', child: Text('Expired')),
                  DropdownMenuItem(value: 'paused', child: Text('Paused')),
                ],
                onChanged: (v) => setState(() {
                  _statusFilter = v ?? _statusFilter;
                  _page = 0;
                }),
              ),
            ],
            onResetFilters: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _statusFilter = 'all';
                _page = 0;
              });
            },
          ),
          const SizedBox(height: 12),

          // Results count badge
          if (_subscriptions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} subscription${filtered.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AdminTheme.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                  if (_searchQuery.isNotEmpty || _statusFilter != 'all')
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

          if (filtered.isEmpty)
            _buildEmptyState(
              _searchQuery.isNotEmpty || _statusFilter != 'all'
                  ? 'No subscriptions match your filters'
                  : 'No subscriptions yet',
              Icons.subscriptions_outlined,
            )
          else ...[
            ...paginated
                .map((sub) => _buildSubscriptionCard(sub))
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
                        icon: const Icon(Icons.chevron_left_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(
                        'Page ${_page + 1} of $totalPages',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AdminTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                shape: BoxShape.circle,
              ),
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
            Text('Try adjusting your filters or refreshing the page.',
                style: TextStyle(
                    fontSize: 13,
                    color: AdminTheme.textSecondary.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> sub) {
    final rawName = sub['accounts']?['full_name']?.toString();
    final userId = sub['user_id']?.toString() ?? '';
    final userName =
        rawName?.isNotEmpty == true ? rawName! : 'User …${userId.length > 8 ? userId.substring(userId.length - 8) : userId}';
    final userEmail = sub['accounts']?['email']?.toString() ?? '';
    final planName =
        sub['subscription_plans']?['name']?.toString() ?? 'Unknown Plan';
    final planDisplay =
        sub['subscription_plans']?['display_name']?.toString() ?? planName;
    final status = sub['status']?.toString() ?? 'unknown';
    final amount = (sub['amount_paid'] ?? sub['subscription_plans']?['price'] ?? 0) as num;
    final startDate = sub['current_period_start']?.toString();
    final endDate = sub['current_period_end']?.toString();
    final statusColor = getStatusColor(status);
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    DateTime? endDt = endDate != null ? DateTime.tryParse(endDate) : null;
    final isExpiringSoon = endDt != null &&
        endDt.isAfter(DateTime.now()) &&
        endDt.isBefore(DateTime.now().add(const Duration(days: 7)));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AdminTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isExpiringSoon
                ? AdminTheme.warningColor.withOpacity(0.5)
                : AdminTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AdminTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
              ),
            ),
            const SizedBox(width: 14),

            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: name + status chip
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AdminTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),

                  if (userEmail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(userEmail,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AdminTheme.textSecondary)),
                  ],

                  const SizedBox(height: 10),

                  // Row 2: info chips
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _infoChip(Icons.card_membership_rounded, planDisplay,
                          AdminTheme.accentColor),
                      _infoChip(Icons.payments_outlined,
                          formatPHP(amount.toDouble()), AdminTheme.successColor),
                      if (startDate != null)
                        _infoChip(
                            Icons.play_arrow_rounded,
                            DateFormat('MMM dd, yyyy')
                                .format(DateTime.parse(startDate)),
                            AdminTheme.textSecondary),
                      if (endDate != null)
                        _infoChip(
                            isExpiringSoon
                                ? Icons.warning_rounded
                                : Icons.event_rounded,
                            'Until ${DateFormat('MMM dd, yyyy').format(DateTime.parse(endDate))}',
                            isExpiringSoon
                                ? AdminTheme.warningColor
                                : AdminTheme.textSecondary),
                    ],
                  ),

                  if (isExpiringSoon)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: AdminTheme.warningColor),
                          const SizedBox(width: 4),
                          Text(
                            'Expires soon — consider renewing',
                            style: TextStyle(
                                fontSize: 11,
                                color: AdminTheme.warningColor,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Action buttons
            Column(
              children: [
                buildTableActionButton(
                    Icons.edit_rounded,
                    'Edit',
                    AdminTheme.accentColor,
                    () => _showEditSubscriptionDialog(sub, _plans)),
                const SizedBox(height: 6),
                buildTableActionButton(
                    Icons.delete_rounded,
                    'Delete',
                    AdminTheme.dangerColor,
                    () => _showDeleteSubscriptionDialog(
                        sub['id']?.toString() ?? '', userName)),
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
        Icon(icon, size: 13, color: color.withOpacity(0.85)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ==================== PLAN DIALOGS ====================

  // ignore: unused_element
  void _showAddPlanDialog_removed() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final displayNameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    String billingPeriod = 'month';
    bool isLoading = false;

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
                      colors: [Color(0xFF059669), Color(0xFF10B981)],
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
                          Icons.card_membership_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Plan',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Add a new subscription plan',
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
                          _buildInputLabel('Plan Name'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: nameController,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _buildInputDecoration(
                              hintText: 'e.g., premium_monthly',
                              prefixIcon: Icons.label_outline_rounded,
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 20),

                          _buildInputLabel('Display Name (Optional)'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: displayNameController,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _buildInputDecoration(
                              hintText: 'e.g., Premium Monthly',
                              prefixIcon: Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(height: 20),

                          _buildInputLabel('Description (Optional)'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: descriptionController,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _buildInputDecoration(
                              hintText: 'Describe the plan features',
                              prefixIcon: Icons.description_outlined,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),

                          // Price and Period row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInputLabel('Price (₱)'),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: priceController,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: _buildInputDecoration(
                                        hintText: '0.00',
                                        prefixIcon: Icons.payments_outlined,
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return 'Required';
                                        if (double.tryParse(v) == null) return 'Invalid number';
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInputLabel('Billing Period'),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: billingPeriod,
                                      decoration: _buildInputDecoration(
                                        prefixIcon: Icons.schedule_rounded,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1F2937),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'month', child: Text('Monthly')),
                                        DropdownMenuItem(value: 'year', child: Text('Yearly')),
                                        DropdownMenuItem(value: 'week', child: Text('Weekly')),
                                      ],
                                      onChanged: (v) => setDialogState(() => billingPeriod = v ?? 'month'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
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
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() => isLoading = true);
                                  try {
                                    final displayName = displayNameController.text.trim();
                                    await _supabaseService.createPlan(
                                      name: nameController.text.trim(),
                                      price: double.tryParse(priceController.text) ?? 0,
                                      displayName: displayName.isNotEmpty ? displayName : nameController.text.trim(),
                                      description: descriptionController.text.trim(),
                                      billingPeriod: billingPeriod,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      _loadData();
                                      showAdminSnackBar(context, 'Plan added successfully', isError: false);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showAdminSnackBar(context, 'Error: $e', isError: true);
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setDialogState(() => isLoading = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF059669),
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Create Plan',
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

  void _showEditPlanDialog(Map<String, dynamic> plan) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: plan['name']?.toString() ?? '');
    final descController = TextEditingController(text: plan['description']?.toString() ?? '');
    final priceController = TextEditingController(text: (plan['price'] as num?)?.toString() ?? '0');
    String billingPeriod = plan['billing_period']?.toString() ?? 'month';
    bool isLoading = false;

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
                // Header
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
                            'Edit Plan',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Update subscription plan details',
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
                          _buildInputLabel('Plan Name'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: nameController,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _buildInputDecoration(
                              prefixIcon: Icons.label_outline_rounded,
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 20),

                          _buildInputLabel('Description (Optional)'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: descController,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _buildInputDecoration(
                              prefixIcon: Icons.description_outlined,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInputLabel('Price (₱)'),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: priceController,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: _buildInputDecoration(
                                        prefixIcon: Icons.payments_outlined,
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return 'Required';
                                        if (double.tryParse(v) == null) return 'Invalid number';
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInputLabel('Billing Period'),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: billingPeriod,
                                      decoration: _buildInputDecoration(
                                        prefixIcon: Icons.schedule_rounded,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1F2937),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'month', child: Text('Monthly')),
                                        DropdownMenuItem(value: 'year', child: Text('Yearly')),
                                        DropdownMenuItem(value: 'week', child: Text('Weekly')),
                                      ],
                                      onChanged: (v) => setDialogState(() => billingPeriod = v ?? 'month'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() => isLoading = true);
                                  try {
                                    await _supabaseService.updatePlan(
                                      planId: plan['id']?.toString() ?? '',
                                      updates: {
                                        'name': nameController.text.trim(),
                                        'description': descController.text.trim(),
                                        'price': double.tryParse(priceController.text) ?? 0,
                                        'billing_period': billingPeriod,
                                      },
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      _loadData();
                                      showAdminSnackBar(context, 'Plan updated successfully', isError: false);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showAdminSnackBar(context, 'Error: $e', isError: true);
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setDialogState(() => isLoading = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Save Changes',
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

  void _showDeletePlanDialog(String planId, String planName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(24),
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
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Color(0xFFEF4444),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delete Plan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "$planName"?\nThis action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
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
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await _supabaseService.deletePlan(planId);
                          if (context.mounted) {
                            Navigator.pop(context);
                            _loadData();
                            showAdminSnackBar(context, 'Plan deleted', isError: false);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            showAdminSnackBar(context, 'Error: $e', isError: true);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
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
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SUBSCRIPTION DIALOGS ====================

  void _showAssignSubscriptionDialog(List<dynamic> plans) {
    final formKey = GlobalKey<FormState>();
    final usersController = TextEditingController();
    String? selectedPlanId;
    String status = 'active';
    bool isLoading = false;

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
                          Icons.link_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign Subscription',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Link a user to a subscription plan',
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
                          // User ID field with info card
                          _buildInputLabel('User ID'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: usersController,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _buildInputDecoration(
                              hintText: 'Paste user UUID here',
                              prefixIcon: Icons.person_outline_rounded,
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'User ID is required' : null,
                          ),
                          const SizedBox(height: 12),
                          
                          // Info card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBAE6FD)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: Color(0xFF0284C7),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You can find the User ID in the Accounts section or database',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Plan Selection
                          _buildInputLabel('Select Plan'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedPlanId,
                            decoration: _buildInputDecoration(
                              prefixIcon: Icons.card_membership_rounded,
                              hintText: 'Choose a plan',
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1F2937),
                            ),
                            items: plans
                                .map((p) => DropdownMenuItem<String>(
                                      value: p['id']?.toString(),
                                      child: Text(
                                        '${p['name']} — ${formatPHP((p['price'] as num?)?.toDouble() ?? 0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) => setDialogState(() => selectedPlanId = v),
                            validator: (v) =>
                                v == null ? 'Please select a plan' : null,
                          ),
                          const SizedBox(height: 24),

                          // Status Selection
                          _buildInputLabel('Subscription Status'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatusCard(
                                  icon: Icons.check_circle_rounded,
                                  title: 'Active',
                                  subtitle: 'Immediately active',
                                  isSelected: status == 'active',
                                  onTap: () => setDialogState(() => status = 'active'),
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatusCard(
                                  icon: Icons.star_half_rounded,
                                  title: 'Trial',
                                  subtitle: 'Trial period',
                                  isSelected: status == 'trial',
                                  onTap: () => setDialogState(() => status = 'trial'),
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatusCard(
                                  icon: Icons.pause_circle_rounded,
                                  title: 'Paused',
                                  subtitle: 'Temporarily paused',
                                  isSelected: status == 'paused',
                                  onTap: () => setDialogState(() => status = 'paused'),
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
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
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
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
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() => isLoading = true);
                                  try {
                                    await _supabaseService.createUserSubscription(
                                      accountId: usersController.text.trim(),
                                      planId: selectedPlanId!,
                                      status: status,
                                      currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      _loadData();
                                      showAdminSnackBar(context, 'Subscription assigned', isError: false);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showAdminSnackBar(context, 'Error: $e', isError: true);
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setDialogState(() => isLoading = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.link_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Assign Subscription',
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

  void _showEditSubscriptionDialog(
      Map<String, dynamic> subscription, List<dynamic> plans) {
    String selectedPlanId = subscription['plan_id']?.toString() ??
        (plans.isNotEmpty ? (plans.first['id']?.toString() ?? '') : '');
    String selectedStatus = subscription['status']?.toString() ?? 'active';
    bool isLoading = false;

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
                // Header
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Subscription',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'User: ${subscription['accounts']?['full_name'] ?? 'Unknown'}',
                            style: const TextStyle(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildInputLabel('Plan'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedPlanId.isNotEmpty ? selectedPlanId : null,
                          decoration: _buildInputDecoration(
                            prefixIcon: Icons.card_membership_rounded,
                            hintText: 'Select a plan',
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1F2937),
                          ),
                          items: plans
                              .map((p) => DropdownMenuItem<String>(
                                    value: p['id']?.toString(),
                                    child: Text(
                                      '${p['name']} — ${formatPHP((p['price'] as num?)?.toDouble() ?? 0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) => setDialogState(() => selectedPlanId = v ?? selectedPlanId),
                        ),
                        const SizedBox(height: 20),

                        _buildInputLabel('Status'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: _buildInputDecoration(
                            prefixIcon: Icons.flag_rounded,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1F2937),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text('Active')),
                            DropdownMenuItem(value: 'trial', child: Text('Trial')),
                            DropdownMenuItem(value: 'pending', child: Text('Pending')),
                            DropdownMenuItem(value: 'past_due', child: Text('Past Due')),
                            DropdownMenuItem(value: 'canceled', child: Text('Canceled')),
                            DropdownMenuItem(value: 'expired', child: Text('Expired')),
                          ],
                          onChanged: (v) => setDialogState(() => selectedStatus = v ?? selectedStatus),
                        ),
                      ],
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
                                  if (selectedPlanId.trim().isEmpty) {
                                    showAdminSnackBar(context, 'Please select a plan', isError: true);
                                    return;
                                  }
                                  setDialogState(() => isLoading = true);
                                  try {
                                    await _supabaseService.updateSubscription(
                                      subscriptionId: subscription['id']?.toString() ?? '',
                                      updates: {
                                        'plan_id': selectedPlanId,
                                        'status': selectedStatus,
                                      },
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      _loadData();
                                      showAdminSnackBar(context, 'Subscription updated', isError: false);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showAdminSnackBar(context, 'Error: $e', isError: true);
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setDialogState(() => isLoading = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Save Changes',
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

  void _showDeleteSubscriptionDialog(
      String subscriptionId, String userName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(24),
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
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Color(0xFFEF4444),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delete Subscription',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Are you sure you want to delete $userName's subscription?\nThis action cannot be undone.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
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
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await _supabaseService.deleteSubscription(subscriptionId);
                          if (context.mounted) {
                            Navigator.pop(context);
                            _loadData();
                            showAdminSnackBar(context, 'Subscription deleted', isError: false);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            showAdminSnackBar(context, 'Error: $e', isError: true);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
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
            ],
          ),
        ),
      ),
    );
  }

  // ==================== PLAN CARD ====================

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final price = (plan['price'] as num?)?.toDouble() ?? 0;
    final isFree = price == 0;
    final period = plan['billing_period']?.toString() ?? '';
    final displayName =
        plan['display_name']?.toString() ?? plan['name']?.toString() ?? '';
    final planName = plan['name']?.toString() ?? '';
    final description = plan['description']?.toString() ?? '';

    // Only 2 plan types: Free and Premium (weekly / monthly / yearly)
    final Color accent =
        isFree ? AdminTheme.textSecondary : AdminTheme.accentColor;

    final Gradient headerGradient = isFree
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF94A3B8), Color(0xFF64748B)])
        : AdminTheme.accentGradient;

    final IconData planIcon =
        isFree ? Icons.lock_open_rounded : Icons.workspace_premium_rounded;

    final String badge = isFree ? 'FREE' : 'PREMIUM';

    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gradient header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: headerGradient,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(planIcon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (planName.isNotEmpty && planName != displayName)
                        Text(
                          planName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isFree ? 'Free' : formatPHP(price),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                    if (!isFree && period.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '/ $period',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AdminTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Billing period chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: accent.withOpacity(0.2)),
                  ),
                  child: Text(
                    _formatBillingPeriod(period),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accent,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AdminTheme.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditPlanDialog(plan),
                        icon: const Icon(Icons.edit_rounded, size: 15),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminTheme.accentColor,
                          side: const BorderSide(
                              color: AdminTheme.accentColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDeletePlanDialog(
                          plan['id']?.toString() ?? '',
                          plan['name']?.toString() ?? '',
                        ),
                        icon: const Icon(Icons.delete_rounded, size: 15),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminTheme.dangerColor,
                          side: const BorderSide(
                              color: AdminTheme.dangerColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBillingPeriod(String period) {
    switch (period.toLowerCase()) {
      case 'week':
        return 'Billed Weekly';
      case 'month':
        return 'Billed Monthly';
      case 'year':
        return 'Billed Yearly';
      default:
        return period.isEmpty ? 'Free Forever' : period;
    }
  }

  // ==================== UI HELPERS ====================

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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
    );
  }

  Widget _buildStatusCard({
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? color : Colors.grey.shade500,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? color.withOpacity(0.7) : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}