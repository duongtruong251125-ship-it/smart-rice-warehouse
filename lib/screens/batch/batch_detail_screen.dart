import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/warehouse_provider.dart';
import 'package:smart_rice_warehouse/widgets/status_chip.dart';

class BatchDetailScreen extends StatefulWidget {
  const BatchDetailScreen({super.key, required this.batchId});

  final String batchId;

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  void _openLocationChangeDialog(BuildContext context, BatchModel batch) {
    final warehouseProvider = context.read<WarehouseProvider>();
    final locations = warehouseProvider.locations;
    String? selectedLocationId = batch.warehouseLocationId;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          child: const Icon(
                            Icons.warehouse_outlined,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Chuyển vị trí kho lưu trữ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Lô hàng: ${batch.code} (${batch.riceName} - ${NumberFormatter.quantity(batch.quantity)} kg)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Chọn vị trí kho mới:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: locations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final loc = locations[index];
                          final isSelected = selectedLocationId == loc.id;
                          return InkWell(
                            onTap: () {
                              setSheetState(() {
                                selectedLocationId = loc.id;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryLight
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.borderColor,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          loc.fullDisplayName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                              ? AppTheme.primaryColor
                                              : AppTheme.textPrimary,
                                          ),
                                        ),
                                        if (loc.description != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            loc.description!,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${loc.currentBatchCount} lô',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: selectedLocationId == null
                          ? null
                          : () {
                              final newLoc = warehouseProvider
                                  .findById(selectedLocationId!);
                              if (newLoc != null) {
                                context.read<BatchProvider>().assignLocation(
                                      batchId: batch.id,
                                      locationId: newLoc.id,
                                      locationName: newLoc.fullDisplayName,
                                    );
                                Navigator.of(sheetContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Đã chuyển lô ${batch.code} đến ${newLoc.fullDisplayName}',
                                    ),
                                    backgroundColor: AppTheme.successColor,
                                  ),
                                );
                              }
                            },
                      child: const Text(
                        'Xác nhận chuyển vị trí',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEnlargedQrDialog(BuildContext context, BatchModel batch) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Center(
            child: Text(
              'Tem QR Lô hàng: ${batch.code}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: QrImageView(
                  data: batch.code,
                  version: QrVersions.auto,
                  size: 200,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppTheme.textPrimary,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${batch.riceName} • ${NumberFormatter.quantity(batch.quantity)} kg',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'HSD: ${DateFormatter.ddMMyyyy(batch.expiryDate)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Đóng'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('In tem QR'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lệnh in tem QR đã được gửi đến máy in!'),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final batchProvider = context.watch<BatchProvider>();
    final batch = batchProvider.findById(widget.batchId);

    if (batch == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết lô hàng')),
        body: const Center(
          child: Text('Không tìm thấy thông tin lô hàng'),
        ),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysUntilExpiry = batch.expiryDate.difference(today).inDays;
    final isExpired = daysUntilExpiry < 0 || batch.status == BatchStatus.expired;
    final isCritical = daysUntilExpiry <= 7 && !isExpired;

    return Scaffold(
      appBar: AppBar(
        title: Text('Lô: ${batch.code}'),
        actions: [
          IconButton(
            tooltip: 'Xem QR Code',
            icon: const Icon(Icons.qr_code_2_rounded),
            onPressed: () => _showEnlargedQrDialog(context, batch),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Thẻ thông tin tổng quan Lô hàng
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              batch.code,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              batch.riceName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusChip.custom(
                        label: batch.status.label,
                        isPositive: batch.status == BatchStatus.available,
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Số lượng tồn kho:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${NumberFormatter.quantity(batch.quantity)} kg',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Khung QR Code chuẩn của Lô hàng (Task 1.2)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.qr_code_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Mã QR Lô hàng',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.fullscreen_rounded, size: 18),
                        label: const Text('Phóng to'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed: () => _showEnlargedQrDialog(context, batch),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _showEnlargedQrDialog(context, batch),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: QrImageView(
                        data: batch.code,
                        version: QrVersions.auto,
                        size: 140,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppTheme.textPrimary,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dữ liệu mã QR: ${batch.code}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Vị trí kho lưu trữ (Task 1.5)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: AppTheme.accentBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Vị trí lưu kho',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: const Text('Đổi vị trí'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed: () =>
                            _openLocationChangeDialog(context, batch),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batch.locationName ?? 'Chưa gán vị trí lưu kho',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Thao tác chuyển vị trí không làm thay đổi số lượng tồn.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Bảng chi tiết ngày tháng & Nhà cung cấp
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông số nguồn gốc & Hạn dùng',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Nhà cung cấp',
                    value: batch.supplierName ?? 'Công ty Lúa Việt',
                  ),
                  const Divider(height: 18),
                  _DetailRow(
                    label: 'Ngày nhập kho',
                    value: DateFormatter.ddMMyyyy(batch.importDate),
                  ),
                  const Divider(height: 18),
                  _DetailRow(
                    label: 'Ngày sản xuất',
                    value: DateFormatter.ddMMyyyy(batch.manufactureDate),
                  ),
                  const Divider(height: 18),
                  _DetailRow(
                    label: 'Hạn sử dụng',
                    value: DateFormatter.ddMMyyyy(batch.expiryDate),
                    valueColor: isExpired
                        ? AppTheme.dangerColor
                        : (isCritical ? AppTheme.warningColor : null),
                  ),
                  const Divider(height: 18),
                  _DetailRow(
                    label: 'Tình trạng hạn',
                    value: isExpired
                        ? 'Đã hết hạn (${daysUntilExpiry.abs()} ngày trước)'
                        : 'Còn $daysUntilExpiry ngày',
                    valueColor: isExpired
                        ? AppTheme.dangerColor
                        : (isCritical ? AppTheme.warningColor : AppTheme.successColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Nút hành động báo hỏng (Task 3.2)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.dangerColor,
              side: const BorderSide(color: AppTheme.dangerColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.report_problem_outlined, size: 20),
            label: const Text(
              'Báo hỏng gạo cho lô này',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.damageReportForm,
                arguments: batch,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
