import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/forecast_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/forecast_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';

/// =======================================================================
/// MÀN HÌNH DỰ BÁO TIÊU THỤ & NHU CẦU TỒN KHO (FORECAST SCREEN)
/// Đồng bộ 100% với layout của App:
/// - Hero Banner Emerald Gradient với KPI phân tích.
/// - Sửa triệt để các lỗi RenderFlex overflow.
/// - Thẻ dự báo từng loại gạo với đề xuất thông minh.
/// =======================================================================
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
    final forecastProvider = context.watch<ForecastProvider>();
    final forecasts = forecastProvider.forecasts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dự báo Nhu cầu & Tồn kho'),
        actions: [
          IconButton(
            tooltip: 'Làm mới phân tích',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: forecasts.isEmpty
          ? EmptyState(
              icon: Icons.trending_up_rounded,
              message: 'Chưa có dữ liệu dự báo tiêu thụ',
              actionLabel: 'Tính toán dự báo ngay',
              onAction: _refresh,
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // --- TẦNG 1: HERO BANNER DỰ BÁO EMERALD GRADIENT ---
                _ForecastHeroBanner(
                  reorderSoonCount: forecastProvider.reorderSoonCount,
                  attentionCount: forecastProvider.attentionCount,
                  totalRiceCount: forecasts.length,
                ).animate().fadeIn(duration: 250.ms),

                const SizedBox(height: 18),

                // --- TẦNG 2: THẺ CHỈ SỐ CẢNH BÁO ĐỐI XỨNG ---
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Cần nhập gấp',
                        count: '${forecastProvider.reorderSoonCount}',
                        color: const Color(0xFFDC2626),
                        bgColor: const Color(0xFFFEF2F2),
                        borderColor: const Color(0xFFFECACA),
                        icon: Icons.priority_high_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        title: 'Cần theo dõi',
                        count: '${forecastProvider.attentionCount}',
                        color: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFFFBEB),
                        borderColor: const Color(0xFFFDE68A),
                        icon: Icons.visibility_outlined,
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 20),

                // --- TIÊU ĐỀ BẢNG XẾP HẠNG (RESPONSIVE KHÔNG TRÀN VIỀN) ---
                Row(
                  children: [
                    const Icon(
                      Icons.sort_rounded,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Xếp hạng ưu tiên nhập hàng (Reorder Ranking)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // --- TẦNG 3: DANH SÁCH THẺ DỰ BÁO CHI TIẾT ---
                for (final forecast in forecasts) ...[
                  _ForecastCard(forecast: forecast),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 1: HERO BANNER DỰ BÁO EMERALD GRADIENT
/// -----------------------------------------------------------------------
class _ForecastHeroBanner extends StatelessWidget {
  const _ForecastHeroBanner({
    required this.reorderSoonCount,
    required this.attentionCount,
    required this.totalRiceCount,
  });

  final int reorderSoonCount;
  final int attentionCount;
  final int totalRiceCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppTheme.heroEmeraldGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.modernElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'DỰ BÁO TIÊU THỤ & TỒN KHO AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'AI Forecast',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Phân Tích Tốc Độ Xuất Kho & Cảnh Báo Hết Hàng',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildMiniChip('$totalRiceCount Giống gạo theo dõi'),
              _buildMiniChip('$reorderSoonCount Cần nhập gấp'),
              _buildMiniChip('$attentionCount Cần theo dõi'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 2: THẺ CHỈ SỐ CẢNH BÁO
/// -----------------------------------------------------------------------
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.count,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.icon,
  });

  final String title;
  final String count;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$count mặt hàng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 3: THẺ DỰ BÁO CHI TIẾT TỪNG LOẠI GẠO
/// -----------------------------------------------------------------------
class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast});

  final ForecastModel forecast;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final Color statusColor;
    final Color statusBgColor;
    final IconData statusIcon;

    switch (forecast.status) {
      case ForecastStatus.reorderSoon:
        statusColor = const Color(0xFFDC2626);
        statusBgColor = isDark ? const Color(0x33DC2626) : const Color(0xFFFEE2E2);
        statusIcon = Icons.warning_rounded;
        break;
      case ForecastStatus.attention:
        statusColor = const Color(0xFFD97706);
        statusBgColor = isDark ? const Color(0x33D97706) : const Color(0xFFFEF3C7);
        statusIcon = Icons.access_time_rounded;
        break;
      case ForecastStatus.safe:
        statusColor = isDark ? AppTheme.darkSafeText : AppTheme.primaryColor;
        statusBgColor = isDark ? AppTheme.darkSafeBg : AppTheme.primaryLight;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case ForecastStatus.noData:
        statusColor = AppTheme.textSecondaryColor(context);
        statusBgColor = isDark ? AppTheme.darkCardElevated : const Color(0xFFF1F5F9);
        statusIcon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: forecast.isCritical
              ? (isDark ? AppTheme.darkDangerBorder : statusColor.withValues(alpha: 0.4))
              : AppTheme.border(context),
          width: forecast.isCritical ? 1.5 : 1.0,
        ),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSafeBg : AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.rice_bowl_outlined,
                  size: 18,
                  color: isDark ? AppTheme.darkSafeText : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${forecast.riceName} (${forecast.riceCode})',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      forecast.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statItem(
                  context: context,
                  label: 'Tồn khả dụng',
                  value:
                      '${NumberFormatter.quantity(forecast.currentStock)} ${forecast.unit}',
                  highlight: forecast.currentStock <= forecast.minimumStock,
                ),
              ),
              Expanded(
                child: _statItem(
                  context: context,
                  label: 'Xuất TB/ngày',
                  value: forecast.averageDailyExport > 0
                      ? '${forecast.averageDailyExport.toStringAsFixed(1)} ${forecast.unit}'
                      : '0 ${forecast.unit}',
                ),
              ),
              Expanded(
                child: _statItem(
                  context: context,
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
              color: isDark ? AppTheme.darkCardElevated : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border(context)),
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
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required BuildContext context,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondaryColor(context),
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: highlight ? const Color(0xFFDC2626) : AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
      ],
    );
  }
}
