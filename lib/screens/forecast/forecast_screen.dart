import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/forecast_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/forecast_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  void _refresh() {
    final rices = context.read<RiceProvider>().rices;
    final exports = context.read<ExportProvider>().receipts;
    final batchProvider = context.read<BatchProvider>();
    context.read<ForecastProvider>().refreshForecasts(
          rices: rices,
          exportReceipts: exports,
          batchProvider: batchProvider,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forecastProvider = context.watch<ForecastProvider>();
    final forecasts = forecastProvider.forecasts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dự báo nhu cầu & Tồn kho'),
        actions: [
          IconButton(
            tooltip: 'Cập nhật phân tích',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: forecasts.isEmpty
          ? EmptyState(
              icon: Icons.trending_up_rounded,
              message: 'Chưa có dữ liệu dự báo tồn kho',
              actionLabel: 'Tính toán dự báo',
              onAction: _refresh,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insights_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Dự báo dựa trên tốc độ xuất kho trung bình trong 7 ngày gần nhất và tồn kho khả dụng hiện tại.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryDark,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Summary chips
                Row(
                  children: [
                    Expanded(
                      child: _metricCard(
                        title: 'Cần nhập gấp',
                        count: '${forecastProvider.reorderSoonCount}',
                        color: const Color(0xFFDC2626),
                        icon: Icons.priority_high_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metricCard(
                        title: 'Cần theo dõi',
                        count: '${forecastProvider.attentionCount}',
                        color: AppTheme.secondaryColor,
                        icon: Icons.visibility_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    const Icon(
                      Icons.sort_rounded,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Xếp hạng ưu tiên nhập hàng (Reorder Ranking)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                ...forecasts.map((forecast) {
                  return _ForecastCard(forecast: forecast);
                }),
              ],
            ),
    );
  }

  Widget _metricCard({
    required String title,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$count mặt hàng',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast});

  final ForecastModel forecast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color statusColor;
    final IconData statusIcon;

    switch (forecast.status) {
      case ForecastStatus.reorderSoon:
        statusColor = const Color(0xFFDC2626);
        statusIcon = Icons.warning_rounded;
        break;
      case ForecastStatus.attention:
        statusColor = AppTheme.secondaryColor;
        statusIcon = Icons.access_time_rounded;
        break;
      case ForecastStatus.safe:
        statusColor = AppTheme.accentGreen;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case ForecastStatus.noData:
        statusColor = AppTheme.textSecondary;
        statusIcon = Icons.info_outline_rounded;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: forecast.isCritical
              ? statusColor.withValues(alpha: 0.4)
              : AppTheme.borderColor,
          width: forecast.isCritical ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.rice_bowl_outlined,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${forecast.riceName} (${forecast.riceCode})',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        forecast.status.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: _statItem(
                    label: 'Tồn khả dụng',
                    value:
                        '${NumberFormatter.quantity(forecast.currentStock)} ${forecast.unit}',
                    highlight: forecast.currentStock <= forecast.minimumStock,
                  ),
                ),
                Expanded(
                  child: _statItem(
                    label: 'Xuất TB/ngày',
                    value: forecast.averageDailyExport > 0
                        ? '${forecast.averageDailyExport.toStringAsFixed(1)} ${forecast.unit}'
                        : '0 ${forecast.unit}',
                  ),
                ),
                Expanded(
                  child: _statItem(
                    label: 'Dự kiến còn',
                    value: forecast.estimatedDaysRemaining != null
                        ? '${forecast.estimatedDaysRemaining!.toStringAsFixed(1)} ngày'
                        : 'N/A',
                    highlight: (forecast.estimatedDaysRemaining ?? 999) <= 7,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      forecast.reorderSuggestion,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        height: 1.3,
                      ),
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

  Widget _statItem({
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: highlight ? const Color(0xFFDC2626) : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
