import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';

class ExportDetailScreen extends StatelessWidget {
  const ExportDetailScreen({super.key, required this.receipt});

  final ExportReceiptModel receipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết phiếu ${receipt.code}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.secondaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          receipt.code,
                          style: const TextStyle(
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        DateFormatter.ddMMyyyy(receipt.date),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _infoRow('Khách hàng:', receipt.customerName),
                  const SizedBox(height: 8),
                  _infoRow('Loại gạo xuất:', receipt.riceName),
                  const SizedBox(height: 8),
                  _infoRow(
                    'Số lượng xuất:',
                    '${NumberFormatter.quantity(receipt.quantity)} kg',
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    'Đơn giá bán:',
                    CurrencyFormatter.formatVnd(receipt.sellingPrice),
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    'Tổng tiền:',
                    CurrencyFormatter.formatVnd(receipt.totalAmount),
                    isHighlighted: true,
                  ),
                  if (receipt.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _infoRow('Ghi chú:', receipt.note),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // FEFO Allocations section
          Row(
            children: [
              const Icon(
                Icons.alt_route_rounded,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Lô hàng phân bổ xuất kho (FEFO)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Hệ thống tự động ưu tiên xuất các lô có hạn dùng gần nhất trước.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          if (receipt.allocations.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Phiếu xuất ban đầu chưa lưu chi tiết phân bổ từng lô hoặc xuất kho trực tiếp.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...receipt.allocations.map((allocation) {
              final daysLeft = allocation.daysUntilExpiry;
              final isNearExpiry = daysLeft <= 30;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.qr_code_2_rounded,
                                size: 18,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                allocation.batchCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isNearExpiry
                                  ? AppTheme.secondaryColor
                                      .withValues(alpha: 0.15)
                                  : AppTheme.accentGreen
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'HSD: ${DateFormatter.ddMMyyyy(allocation.expiryDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isNearExpiry
                                    ? AppTheme.secondaryColor
                                    : AppTheme.accentGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Số lượng trích xuất:',
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            '${NumberFormatter.quantity(allocation.allocatedQuantity)} kg',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tồn lô sau khi xuất:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            '${NumberFormatter.quantity(allocation.batchRemainingQuantity)} kg',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isHighlighted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color:
                isHighlighted ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
            color:
                isHighlighted ? AppTheme.secondaryColor : AppTheme.textPrimary,
            fontSize: isHighlighted ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
