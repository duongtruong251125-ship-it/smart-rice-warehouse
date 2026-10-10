import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/providers/damage_provider.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';

class DamageListScreen extends StatefulWidget {
  const DamageListScreen({super.key});

  @override
  State<DamageListScreen> createState() => _DamageListScreenState();
}

class _DamageListScreenState extends State<DamageListScreen> {
  DamageReason? _selectedReason;

  @override
  Widget build(BuildContext context) {
    final damageProvider = context.watch<DamageProvider>();
    final reports = damageProvider.filter(reason: _selectedReason);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ báo hỏng gạo'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.dangerColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Báo hỏng'),
        onPressed: () {
          Navigator.of(context).pushNamed(AppRoutes.damageReportForm);
        },
      ),
      body: Column(
        children: [
          // Banner tổng kết
          Container(
            padding: const EdgeInsets.all(14),
            color: AppTheme.dangerColor.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.report_problem_rounded,
                    color: AppTheme.dangerColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tổng gạo hư hỏng đã ghi nhận',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      Text(
                        '${NumberFormatter.quantity(damageProvider.totalDamagedWeight)} kg (${damageProvider.reports.length} phiếu)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.dangerColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lọc theo Lý do
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Tất cả lý do'),
                    selected: _selectedReason == null,
                    onSelected: (_) => setState(() => _selectedReason = null),
                  ),
                ),
                ...DamageReason.values.map((reason) {
                  final isSelected = _selectedReason == reason;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(reason.label),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedReason = reason),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Danh sách phiếu báo hỏng
          Expanded(
            child: reports.isEmpty
                ? const EmptyState(
                    message:
                        'Chưa có phiếu báo hỏng nào. Bấm nút "Báo hỏng" bên dưới để lập phiếu mới.',
                    icon: Icons.assignment_turned_in_outlined,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: reports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = reports[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppTheme.dangerColor
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: AppTheme.dangerColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.code,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Lô: ${item.batchCode} • ${item.riceName}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.dangerColor
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.reason.label,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.dangerColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 18),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Hỏng: ${NumberFormatter.quantity(item.quantity)} kg',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.dangerColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    DateFormatter.ddMMyyyy(item.createdAt),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                              if (item.note != null &&
                                  item.note!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Ghi chú: ${item.note!}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic),
                                ),
                              ],
                              if (item.imagePath != null) ...[
                                const SizedBox(height: 8),
                                const Row(
                                  children: [
                                    Icon(Icons.attachment_rounded,
                                        size: 14, color: AppTheme.accentBlue),
                                    SizedBox(width: 4),
                                    Text(
                                      'Có ảnh minh chứng đính kèm',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.accentBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
