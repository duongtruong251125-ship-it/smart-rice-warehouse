import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/models/alert_model.dart';
import 'package:smart_rice_warehouse/providers/alert_provider.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';

class AlertListScreen extends StatefulWidget {
  const AlertListScreen({super.key});

  @override
  State<AlertListScreen> createState() => _AlertListScreenState();
}

class _AlertListScreenState extends State<AlertListScreen> {
  AlertType? _selectedFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scan();
    });
  }

  void _scan() {
    final rices = context.read<RiceProvider>().rices;
    final batches = context.read<BatchProvider>().batches;
    context.read<AlertProvider>().scanAlerts(
          rices: rices,
          batches: batches,
        );
  }

  @override
  Widget build(BuildContext context) {
    final alertProvider = context.watch<AlertProvider>();
    final allAlerts = alertProvider.alerts;
    final filteredAlerts = _selectedFilter == null
        ? allAlerts
        : allAlerts.where((a) => a.type == _selectedFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cảnh báo & Nhắc nhở'),
        actions: [
          if (alertProvider.unreadCount > 0)
            IconButton(
              tooltip: 'Đánh dấu tất cả đã đọc',
              onPressed: () => alertProvider.markAllAsRead(),
              icon: const Icon(Icons.mark_email_read_outlined),
            ),
          IconButton(
            tooltip: 'Làm mới cảnh báo',
            onPressed: _scan,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Tất cả (${allAlerts.length})',
                  isSelected: _selectedFilter == null,
                  onSelected: () => setState(() => _selectedFilter = null),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Tồn thấp (${alertProvider.lowStockCount})',
                  isSelected: _selectedFilter == AlertType.lowStock,
                  onSelected: () =>
                      setState(() => _selectedFilter = AlertType.lowStock),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Sắp hết hạn (${alertProvider.expiringCount})',
                  isSelected: _selectedFilter == AlertType.expiringSoon,
                  onSelected: () =>
                      setState(() => _selectedFilter = AlertType.expiringSoon),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Đã hết hạn (${alertProvider.expiredCount})',
                  isSelected: _selectedFilter == AlertType.expired,
                  onSelected: () =>
                      setState(() => _selectedFilter = AlertType.expired),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Alerts List
          Expanded(
            child: filteredAlerts.isEmpty
                ? const EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    message: 'Hiện không có cảnh báo nào trong mục này',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filteredAlerts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final alert = filteredAlerts[index];
                      return _AlertItemCard(
                        alert: alert,
                        onTap: () => alertProvider.markAsRead(alert.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primaryLight,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }
}

class _AlertItemCard extends StatelessWidget {
  const _AlertItemCard({
    required this.alert,
    required this.onTap,
  });

  final AlertModel alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCritical = alert.severity == AlertSeverity.critical;
    final isWarning = alert.severity == AlertSeverity.warning;

    final Color indicatorColor = isCritical
        ? const Color(0xFFDC2626)
        : (isWarning ? AppTheme.secondaryColor : AppTheme.primaryColor);

    final IconData icon = isCritical
        ? Icons.error_outline_rounded
        : (isWarning
            ? Icons.warning_amber_rounded
            : Icons.info_outline_rounded);

    return Card(
      color: alert.isRead ? AppTheme.cardColor : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: alert.isRead
              ? AppTheme.borderColor
              : indicatorColor.withValues(alpha: 0.35),
          width: alert.isRead ? 1 : 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: indicatorColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: indicatorColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: alert.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: isCritical
                                  ? const Color(0xFFDC2626)
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (!alert.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alert.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: indicatorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            alert.severity.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: indicatorColor,
                            ),
                          ),
                        ),
                        Text(
                          DateFormatter.ddMMyyyy(alert.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
