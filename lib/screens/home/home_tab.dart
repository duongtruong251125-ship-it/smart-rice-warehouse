import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/widgets/dashboard_card.dart';
import 'package:smart_rice_warehouse/widgets/section_title.dart';
import 'package:smart_rice_warehouse/widgets/status_chip.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final riceProvider = context.watch<RiceProvider>();
    final batchProvider = context.watch<BatchProvider>();
    final importProvider = context.watch<ImportProvider>();
    final exportProvider = context.watch<ExportProvider>();
    final today = DateTime.now();
    final recentActivities = _getRecentActivities(
      rices: riceProvider.rices,
      importProvider: importProvider,
      exportProvider: exportProvider,
    );
    final isNarrow = MediaQuery.sizeOf(context).width < 340;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DashboardHeader(),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: isNarrow ? 1 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: isNarrow ? 2.5 : 1.72,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              DashboardCard(
                icon: Icons.rice_bowl_outlined,
                title: 'Tổng loại gạo',
                value: '${riceProvider.rices.length} loại gạo',
                accentColor: AppTheme.primaryColor,
              ),
              DashboardCard(
                icon: Icons.inventory_2_outlined,
                title: 'Tổng tồn kho',
                value: '${_formatQuantity(batchProvider.totalStock)} kg',
                accentColor: AppTheme.accentBlue,
              ),
              DashboardCard(
                icon: Icons.download_rounded,
                title: 'Phiếu nhập hôm nay',
                value: '${importProvider.receiptCountOn(today)} phiếu',
                accentColor: AppTheme.accentGreen,
              ),
              DashboardCard(
                icon: Icons.upload_rounded,
                title: 'Phiếu xuất hôm nay',
                value: '${exportProvider.receiptCountOn(today)} phiếu',
                accentColor: AppTheme.secondaryColor,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SectionTitle('Thao tác nhanh POS'),
          const SizedBox(height: 10),
          const _QuickActionsGrid(),
          const SizedBox(height: 20),
          const SectionTitle('Trạng thái kho'),
          const SizedBox(height: 10),
          _WarehouseStatus(
            rices: riceProvider.rices.take(5).toList(growable: false),
            batchProvider: batchProvider,
          ),
          const SizedBox(height: 20),
          const SectionTitle('Hoạt động gần đây'),
          const SizedBox(height: 10),
          _RecentActivityList(activities: recentActivities),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              color: AppTheme.primaryColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreenLight,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.accentGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'POS • KHO TRUNG TÂM',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: const Color(0xFF15803D),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Xin chào, Admin',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tổng quan hoạt động kho hôm nay',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warehouse_rounded,
                        color: AppTheme.primaryColor,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  static const _actions = <_QuickAction>[
    _QuickAction(
      label: 'Tạo nhập',
      icon: Icons.download_rounded,
      color: AppTheme.accentGreen,
      route: AppRoutes.addImport,
    ),
    _QuickAction(
      label: 'Tạo xuất',
      icon: Icons.upload_rounded,
      color: AppTheme.secondaryColor,
      route: AppRoutes.addExport,
    ),
    _QuickAction(
      label: 'Loại gạo',
      icon: Icons.rice_bowl_outlined,
      color: AppTheme.primaryColor,
      route: AppRoutes.rice,
    ),
    _QuickAction(
      label: 'Kiểm kho',
      icon: Icons.inventory_outlined,
      color: AppTheme.accentBlue,
      route: AppRoutes.inventory,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Row(
            children: [
              for (final action in _actions)
                Expanded(
                  child: _QuickActionButton(action: action),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String route;
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).pushNamed(action.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: action.color.withOpacity(0.22),
                ),
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                action.label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseStatus extends StatelessWidget {
  const _WarehouseStatus({
    required this.rices,
    required this.batchProvider,
  });

  final List<RiceModel> rices;
  final BatchProvider batchProvider;

  @override
  Widget build(BuildContext context) {
    if (rices.isEmpty) {
      return const _EmptySection(message: 'Chưa có dữ liệu tồn kho');
    }

    return Card(
      child: Column(
        children: [
          for (var index = 0; index < rices.length; index++) ...[
            _WarehouseStatusItem(
              rice: rices[index],
              stock: batchProvider.totalStockForRice(rices[index].id),
            ),
            if (index < rices.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _WarehouseStatusItem extends StatelessWidget {
  const _WarehouseStatusItem({required this.rice, required this.stock});

  final RiceModel rice;
  final double stock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.rice_bowl_outlined,
          size: 20,
          color: colorScheme.primary,
        ),
      ),
      title: Text(
        rice.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${_formatQuantity(stock)} ${rice.unit}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: StatusChip(isLowStock: stock <= rice.minimumStock),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList({required this.activities});

  final List<_DashboardActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const _EmptySection(message: 'Chưa có hoạt động gần đây');
    }

    return Card(
      child: Column(
        children: [
          for (var index = 0; index < activities.length; index++) ...[
            _ActivityItem(activity: activities[index]),
            if (index < activities.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.activity});

  final _DashboardActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = activity.isImport
        ? AppTheme.accentGreen
        : AppTheme.secondaryColor;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          activity.isImport ? Icons.download_rounded : Icons.upload_rounded,
          color: accentColor,
          size: 20,
        ),
      ),
      title: Text(
        '${activity.isImport ? 'Nhập' : 'Xuất'} '
        '${_formatQuantity(activity.quantity)} ${activity.unit} '
        '${activity.riceName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${activity.code} • ${_formatDate(activity.date)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardActivity {
  const _DashboardActivity({
    required this.isImport,
    required this.code,
    required this.riceName,
    required this.quantity,
    required this.unit,
    required this.date,
  });

  final bool isImport;
  final String code;
  final String riceName;
  final double quantity;
  final String unit;
  final DateTime date;
}

List<_DashboardActivity> _getRecentActivities({
  required List<RiceModel> rices,
  required ImportProvider importProvider,
  required ExportProvider exportProvider,
}) {
  final unitsByRiceId = <String, String>{
    for (final rice in rices) rice.id: rice.unit,
  };
  final activities = <_DashboardActivity>[
    for (final receipt in importProvider.receipts)
      _DashboardActivity(
        isImport: true,
        code: receipt.code,
        riceName: receipt.riceName,
        quantity: receipt.quantity,
        unit: unitsByRiceId[receipt.riceId] ?? 'kg',
        date: receipt.date,
      ),
    for (final receipt in exportProvider.receipts)
      _DashboardActivity(
        isImport: false,
        code: receipt.code,
        riceName: receipt.riceName,
        quantity: receipt.quantity,
        unit: unitsByRiceId[receipt.riceId] ?? 'kg',
        date: receipt.date,
      ),
  ]..sort((first, second) => second.date.compareTo(first.date));

  return activities.take(6).toList(growable: false);
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return _withThousandsSeparator(value.toInt());
  }

  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String _withThousandsSeparator(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[index]);
  }

  return buffer.toString();
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

