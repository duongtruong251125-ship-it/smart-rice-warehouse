import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
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
    final isNarrow = MediaQuery.sizeOf(context).width < 340;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Tổng quan tháng'),
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
          const SizedBox(height: 12),
          _SevenDayChart(activities: activities),
        ],
      ),
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
        color: color.withOpacity(0.1),
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

