import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';

class ReportFlowPoint {
  const ReportFlowPoint({
    required this.label,
    required this.importQuantity,
    required this.exportQuantity,
  });

  final String label;
  final double importQuantity;
  final double exportQuantity;
}

class ReportInventorySlice {
  const ReportInventorySlice({
    required this.label,
    required this.quantity,
    required this.color,
  });

  final String label;
  final double quantity;
  final Color color;
}

class ReportValuePoint {
  const ReportValuePoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

class ReportFlowBarChart extends StatelessWidget {
  const ReportFlowBarChart({
    super.key,
    required this.points,
    this.showImport = true,
    this.showExport = true,
    this.height = 160,
  });

  final List<ReportFlowPoint> points;
  final bool showImport;
  final bool showExport;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maximum = points.fold<double>(0, (current, point) {
      final importValue = showImport ? point.importQuantity : 0.0;
      final exportValue = showExport ? point.exportQuantity : 0.0;
      return math.max(current, math.max(importValue, exportValue));
    });

    if (maximum <= 0) {
      return SizedBox(
        height: height,
        child: const _ChartEmptyState(
          message: 'Chưa có giao dịch trong khoảng thời gian này',
        ),
      );
    }

    final chartMaximum = _roundedMaximum(maximum);
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: chartMaximum,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: chartMaximum / 4,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppTheme.borderColor,
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                interval: chartMaximum / 2,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _compactQuantity(value),
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 7,
                    child: Text(
                      points[index].label,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTheme.textPrimary,
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final point = points[group.x];
                final isImport = showImport && rodIndex == 0;
                return BarTooltipItem(
                  '${point.label}\n${isImport ? 'Nhập' : 'Xuất'}: ${NumberFormatter.quantity(rod.toY)} kg',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ),
          barGroups: List.generate(points.length, (index) {
            final point = points[index];
            return BarChartGroupData(
              x: index,
              barsSpace: 4,
              barRods: [
                if (showImport)
                  BarChartRodData(
                    toY: point.importQuantity,
                    width: 11,
                    color: AppTheme.accentGreen,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                if (showExport)
                  BarChartRodData(
                    toY: point.exportQuantity,
                    width: 11,
                    color: AppTheme.secondaryColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

class InventoryCompositionChart extends StatelessWidget {
  const InventoryCompositionChart({
    super.key,
    required this.slices,
    required this.totalQuantity,
  });

  final List<ReportInventorySlice> slices;
  final double totalQuantity;

  @override
  Widget build(BuildContext context) {
    return _ReportChartCard(
      title: 'Cơ cấu tồn kho',
      subtitle: 'Tỷ trọng khối lượng theo loại gạo',
      icon: Icons.donut_large_rounded,
      child: totalQuantity <= 0
          ? const SizedBox(
              height: 190,
              child: _ChartEmptyState(message: 'Kho hiện chưa có hàng'),
            )
          : Column(
              children: [
                SizedBox(
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          centerSpaceRadius: 48,
                          sectionsSpace: 3,
                          startDegreeOffset: -90,
                          sections: slices.map((slice) {
                            final percent =
                                slice.quantity / totalQuantity * 100;
                            return PieChartSectionData(
                              value: slice.quantity,
                              color: slice.color,
                              radius: 24,
                              showTitle: percent >= 8,
                              title: '${percent.round()}%',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            );
                          }).toList(),
                        ),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            NumberFormatter.quantity(totalQuantity),
                            style: AppTheme.tabularFigures(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const Text(
                            'kg tồn kho',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: slices
                      .map(
                        (slice) => _ChartLegend(
                          color: slice.color,
                          label:
                              '${slice.label} · ${NumberFormatter.quantity(slice.quantity)} kg',
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
    );
  }
}

class InventoryValueTrendChart extends StatelessWidget {
  const InventoryValueTrendChart({super.key, required this.points});

  final List<ReportValuePoint> points;

  @override
  Widget build(BuildContext context) {
    final values = points.map((point) => point.value).toList();
    final minimum = values.isEmpty ? 0.0 : values.reduce(math.min);
    final maximum = values.isEmpty ? 0.0 : values.reduce(math.max);
    final padding = maximum == minimum
        ? math.max(maximum * 0.1, 1000000.0)
        : (maximum - minimum) * 0.18;
    final minY = math.max(0.0, minimum - padding);
    final maxY = math.max(maximum + padding, minY + 1);

    return _ReportChartCard(
      title: 'Biến động giá trị tồn',
      subtitle: 'Ước tính 7 ngày theo giá vốn hiện hành',
      icon: Icons.show_chart_rounded,
      child: points.isEmpty
          ? const SizedBox(
              height: 214,
              child: _ChartEmptyState(message: 'Chưa đủ dữ liệu để phân tích'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CurrencyFormatter.formatVnd(points.last.value),
                  style: AppTheme.tabularFigures(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.infoColor,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (points.length - 1).toDouble(),
                      minY: minY,
                      maxY: maxY,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: (maxY - minY) / 3,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: AppTheme.borderColor,
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            interval: (maxY - minY) / 2,
                            getTitlesWidget: (value, meta) => SideTitleWidget(
                              meta: meta,
                              child: Text(
                                _compactCurrency(value),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= points.length) {
                                return const SizedBox.shrink();
                              }
                              final date = points[index].date;
                              return SideTitleWidget(
                                meta: meta,
                                space: 7,
                                child: Text(
                                  '${date.day}/${date.month}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppTheme.textPrimary,
                          getTooltipItems: (spots) => spots
                              .map(
                                (spot) => LineTooltipItem(
                                  CurrencyFormatter.formatVnd(spot.y),
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            points.length,
                            (index) => FlSpot(
                              index.toDouble(),
                              points[index].value,
                            ),
                          ),
                          isCurved: true,
                          curveSmoothness: 0.22,
                          color: AppTheme.infoColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.infoColor.withValues(alpha: 0.22),
                                AppTheme.infoColor.withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ReportChartCard extends StatelessWidget {
  const _ReportChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: AppTheme.primaryDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.query_stats_rounded,
            color: AppTheme.textMuted,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

double _roundedMaximum(double value) {
  if (value <= 10) return 10;
  final magnitude =
      math.pow(10, value.toInt().toString().length - 1).toDouble();
  return (value / magnitude).ceil() * magnitude;
}

String _compactQuantity(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}tr';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
  return value.toStringAsFixed(0);
}

String _compactCurrency(double value) {
  if (value >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(1)}tỷ';
  }
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(0)}tr';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
  return value.toStringAsFixed(0);
}
