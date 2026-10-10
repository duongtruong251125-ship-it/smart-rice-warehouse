import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/providers/inventory_check_provider.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';

class InventoryCheckHistoryScreen extends StatelessWidget {
  const InventoryCheckHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final checkProvider = context.watch<InventoryCheckProvider>();
    final history = checkProvider.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử kiểm kê kho'),
      ),
      body: history.isEmpty
          ? const EmptyState(
              message: 'Chưa có phiên kiểm kê nào. Các phiên kiểm kê đã hoàn thành sẽ xuất hiện tại đây.',
              icon: Icons.history_toggle_off_rounded,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final session = history[index];
                return _SessionHistoryCard(session: session);
              },
            ),
    );
  }
}

class _SessionHistoryCard extends StatefulWidget {
  const _SessionHistoryCard({required this.session});

  final InventoryCheckSession session;

  @override
  State<_SessionHistoryCard> createState() => _SessionHistoryCardState();
}

class _SessionHistoryCardState extends State<_SessionHistoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final hasDiff = session.totalDifference.abs() > 0.001;

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
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.code,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormatter.ddMMyyyy(session.createdAt)} • Người lập: ${session.createdBy}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    session.status.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng số lô: ${session.totalItems}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Chênh lệch: ${session.totalDifference >= 0 ? '+' : ''}${NumberFormatter.quantity(session.totalDifference)} kg',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: hasDiff
                        ? (session.totalDifference < 0 ? AppTheme.dangerColor : AppTheme.primaryColor)
                        : AppTheme.successColor,
                  ),
                ),
              ],
            ),
            if (session.note != null && session.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Ghi chú: ${session.note!}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
              ),
            ],
            if (session.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isExpanded ? 'Thu gọn chi tiết' : 'Xem chi tiết ${session.items.length} lô',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentBlue),
                      ),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppTheme.accentBlue,
                      ),
                    ],
                  ),
                ),
              ),
              if (_isExpanded) ...[
                const Divider(height: 12),
                Column(
                  children: session.items.map((item) {
                    final itemDiff = item.hasDifference;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.batchCode} (${item.riceName})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Sổ sách: ${NumberFormatter.quantity(item.expectedQuantity)} kg → Thực tế: ${NumberFormatter.quantity(item.actualQuantity)} kg',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                                if (itemDiff)
                                  Text(
                                    'Lý do: ${item.reason.label}${item.note != null ? ' - ${item.note}' : ''}',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.dangerColor),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            itemDiff
                                ? '${item.difference >= 0 ? '+' : ''}${NumberFormatter.quantity(item.difference)} kg'
                                : 'Khớp',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: itemDiff ? AppTheme.warningColor : AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
