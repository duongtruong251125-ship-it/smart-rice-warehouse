import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/widgets/dashboard_card.dart';
import 'package:smart_rice_warehouse/widgets/section_title.dart';

class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final importProvider = context.watch<ImportProvider>();
    final exportProvider = context.watch<ExportProvider>();
    final batchProvider = context.watch<BatchProvider>();
    final riceProvider = context.watch<RiceProvider>();
    final now = DateTime.now();
    final activities = _buildDailyActivities(
      today: now,
      importProvider: importProvider,
      exportProvider: exportProvider,
    );
    final topExportedRices = _calculateTopExportedRices(
      exportReceipts: exportProvider.receipts,
      rices: riceProvider.rices,
    );
    final isNarrow = MediaQuery.sizeOf(context).width < 340;

    final total7DaysImport = activities.fold(0.0, (s, a) => s + a.importQuantity);
    final total7DaysExport = activities.fold(0.0, (s, a) => s + a.exportQuantity);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Tổng quan tháng này'),
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
                icon: Icons.download_rounded,
                title: 'Tổng nhập tháng',
                value: CurrencyFormatter.formatVnd(
                  importProvider.totalAmountForMonth(now),
                ),
                accentColor: AppTheme.accentGreen,
              ),
              DashboardCard(
                icon: Icons.upload_rounded,
                title: 'Tổng xuất tháng',
                value: CurrencyFormatter.formatVnd(
                  exportProvider.totalAmountForMonth(now),
                ),
                accentColor: AppTheme.secondaryColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: DashboardCard(
              icon: Icons.inventory_2_outlined,
              title: 'Giá trị tồn kho',
              value: CurrencyFormatter.formatVnd(
                batchProvider.inventoryValue(riceProvider.rices),
              ),
              accentColor: AppTheme.primaryColor,
            ),
          ),

          const SizedBox(height: 24),
          const SectionTitle('Hoạt động 7 ngày gần đây'),
          const SizedBox(height: 4),
          Text(
            'Nhập: ${NumberFormatter.quantity(total7DaysImport)} kg • Xuất: ${NumberFormatter.quantity(total7DaysExport)} kg',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _SevenDayChart(activities: activities),

          const SizedBox(height: 24),
          if (isNarrow) ...[
            const SectionTitle('Top gạo xuất nhiều nhất'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.forecast),
                icon: const Icon(Icons.insights_rounded, size: 16),
                label: const Text('Xem dự báo'),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: SectionTitle('Top gạo xuất nhiều nhất'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.forecast),
                  icon: const Icon(Icons.insights_rounded, size: 16),
                  label: const Text('Xem dự báo'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _TopExportedList(items: topExportedRices),
        ],
      ),
    );
  }
}

class _TopExportedItem {
  const _TopExportedItem({
    required this.riceId,
    required this.riceName,
    required this.unit,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  final String riceId;
  final String riceName;
  final String unit;
  final double totalQuantity;
  final double totalRevenue;
}

List<_TopExportedItem> _calculateTopExportedRices({
  required List<ExportReceiptModel> exportReceipts,
  required List<RiceModel> rices,
}) {
  final quantities = <String, double>{};
  final revenues = <String, double>{};

  for (final receipt in exportReceipts) {
    quantities[receipt.riceId] =
        (quantities[receipt.riceId] ?? 0.0) + receipt.quantity;
    revenues[receipt.riceId] =
        (revenues[receipt.riceId] ?? 0.0) + receipt.totalAmount;
  }

  final items = <_TopExportedItem>[];
  for (final entry in quantities.entries) {
    final rice = rices.cast<RiceModel?>().firstWhere(
          (r) => r?.id == entry.key,
          orElse: () => null,
        );
    items.add(
      _TopExportedItem(
        riceId: entry.key,
        riceName: rice?.name ?? entry.key,
        unit: rice?.unit ?? 'kg',
        totalQuantity: entry.value,
        totalRevenue: revenues[entry.key] ?? 0.0,
      ),
    );
  }

  items.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
  return items.take(5).toList(growable: false);
}

class _TopExportedList extends StatelessWidget {
  const _TopExportedList({required this.items});

  final List<_TopExportedItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Chưa có dữ liệu xuất hàng',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    final maxQty = items.first.totalQuantity;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) const Divider(height: 16),
              _buildRow(items[index], index + 1, maxQty, theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    _TopExportedItem item,
    int rank,
    double maxQty,
    ThemeData theme,
  ) {
    final ratio = maxQty > 0 ? (item.totalQuantity / maxQty).clamp(0.05, 1.0) : 0.0;
    final isTop1 = rank == 1;

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isTop1
                ? AppTheme.secondaryColor
                : AppTheme.backgroundColor,
            shape: BoxShape.circle,
            border: isTop1 ? null : Border.all(color: AppTheme.borderColor),
          ),
          alignment: Alignment.center,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isTop1 ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.riceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: AppTheme.backgroundColor,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${NumberFormatter.quantity(item.totalQuantity)} ${item.unit}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              CurrencyFormatter.formatVnd(item.totalRevenue),
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SevenDayChart extends StatelessWidget {
  const _SevenDayChart({required this.activities});

  final List<_DailyActivity> activities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    var maximum = 0.0;
    for (final activity in activities) {
      if (activity.importQuantity > maximum) {
        maximum = activity.importQuantity;
      }
      if (activity.exportQuantity > maximum) {
        maximum = activity.exportQuantity;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _LegendItem(color: AppTheme.accentGreen, label: 'Nhập kho'),
                _LegendItem(color: AppTheme.secondaryColor, label: 'Xuất kho'),
              ],
            ),
            const SizedBox(height: 20),
            if (maximum == 0)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    'Chưa có dữ liệu trong khoảng thời gian này',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 155,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final activity in activities)
                      Expanded(
                        child: _DailyBars(
                          activity: activity,
                          maximum: maximum,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.activity, required this.maximum});

  final _DailyActivity activity;
  final double maximum;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _ActivityBar(
                      height: constraints.maxHeight *
                          activity.importQuantity /
                          maximum,
                      color: AppTheme.accentGreen,
                    ),
                    const SizedBox(width: 3),
                    _ActivityBar(
                      height: constraints.maxHeight *
                          activity.exportQuantity /
                          maximum,
                      color: AppTheme.secondaryColor,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${activity.date.day}/${activity.date.month}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _ActivityBar extends StatelessWidget {
  const _ActivityBar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyActivity {
  const _DailyActivity({
    required this.date,
    required this.importQuantity,
    required this.exportQuantity,
  });

  final DateTime date;
  final double importQuantity;
  final double exportQuantity;
}

List<_DailyActivity> _buildDailyActivities({
  required DateTime today,
  required ImportProvider importProvider,
  required ExportProvider exportProvider,
}) {
  final currentDay = DateTime(today.year, today.month, today.day);
  return List<_DailyActivity>.generate(7, (index) {
    final date = currentDay.subtract(Duration(days: 6 - index));
    return _DailyActivity(
      date: date,
      importQuantity: importProvider.quantityOn(date),
      exportQuantity: exportProvider.quantityOn(date),
    );
  });
}
