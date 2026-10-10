import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/inventory_check_provider.dart';
import 'package:smart_rice_warehouse/screens/scanner/qr_scanner_screen.dart';

class InventoryCheckScreen extends StatefulWidget {
  const InventoryCheckScreen({super.key});

  @override
  State<InventoryCheckScreen> createState() => _InventoryCheckScreenState();
}

class _InventoryCheckScreenState extends State<InventoryCheckScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<InventoryCheckProvider>();
      if (!provider.hasActiveSession) {
        provider.startNewSession(createdBy: 'Admin');
      }
    });
  }

  void _openCountDialog(BatchModel batch, [InventoryCheckItem? existingItem]) {
    final formKey = GlobalKey<FormState>();
    final actualCtrl = TextEditingController(
      text: existingItem != null
          ? NumberFormatter.quantity(existingItem.actualQuantity)
          : NumberFormatter.quantity(batch.quantity),
    );
    final noteCtrl = TextEditingController(text: existingItem?.note ?? '');
    InventoryCheckReason selectedReason =
        existingItem?.reason ?? InventoryCheckReason.none;

    double currentDiff = existingItem?.difference ?? 0.0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInsets = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInsets),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kiểm kê lô: ${batch.code}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Loại gạo: ${batch.riceName}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tồn hệ thống:',
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                            Text(
                              '${NumberFormatter.quantity(batch.quantity)} kg',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: actualCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Số lượng thực tế đếm được (kg)',
                          suffixText: 'kg',
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val.replaceAll(',', '.'));
                          setSheetState(() {
                            if (parsed != null) {
                              currentDiff = parsed - batch.quantity;
                              if (currentDiff.abs() < 0.001) {
                                selectedReason = InventoryCheckReason.none;
                              } else if (selectedReason == InventoryCheckReason.none) {
                                selectedReason = InventoryCheckReason.haoHut;
                              }
                            }
                          });
                        },
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập số lượng thực tế';
                          }
                          final parsed = double.tryParse(val.replaceAll(',', '.'));
                          if (parsed == null || parsed < 0) {
                            return 'Số lượng không được âm';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      // Hiển thị chênh lệch
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: currentDiff.abs() < 0.001
                              ? AppTheme.successColor.withOpacity(0.1)
                              : AppTheme.warningColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Chênh lệch:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text(
                              '${currentDiff >= 0 ? '+' : ''}${NumberFormatter.quantity(currentDiff)} kg',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: currentDiff.abs() < 0.001
                                    ? AppTheme.successColor
                                    : (currentDiff < 0 ? AppTheme.dangerColor : AppTheme.primaryColor),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bắt buộc chọn lý do nếu có chênh lệch (Task 2.4)
                      if (currentDiff.abs() >= 0.001) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Lý do chênh lệch (Bắt buộc):',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<InventoryCheckReason>(
                          value: selectedReason == InventoryCheckReason.none
                              ? InventoryCheckReason.haoHut
                              : selectedReason,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: InventoryCheckReason.values
                              .where((r) => r != InventoryCheckReason.none)
                              .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setSheetState(() => selectedReason = val);
                          },
                        ),
                      ],

                      const SizedBox(height: 12),
                      TextFormField(
                        controller: noteCtrl,
                        decoration: const InputDecoration(labelText: 'Ghi chú thêm (tùy chọn)'),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            final actual = double.parse(actualCtrl.text.trim().replaceAll(',', '.'));
                            context.read<InventoryCheckProvider>().addOrUpdateItem(
                                  batch: batch,
                                  actualQuantity: actual,
                                  reason: currentDiff.abs() < 0.001
                                      ? InventoryCheckReason.none
                                      : selectedReason,
                                  note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                                );
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        child: const Text(
                          'Lưu kết quả kiểm kê',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openQrScannerForBatch() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          title: 'Quét mã QR Lô kiểm kê',
          onBatchScanned: (batch) {
            _openCountDialog(batch);
          },
        ),
      ),
    );
  }

  void _showConfirmAdjustmentDialog() {
    final checkProvider = context.read<InventoryCheckProvider>();
    final session = checkProvider.activeSession;
    if (session == null || session.items.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Xác nhận hoàn thành kiểm kê?'),
          content: Text(
            'Hệ thống sẽ cập nhật lại số lượng tồn kho của ${session.items.length} lô theo số liệu thực tế.\n\n'
            'Tổng chênh lệch: ${session.totalDifference >= 0 ? '+' : ''}${NumberFormatter.quantity(session.totalDifference)} kg.\n'
            'Thao tác này sẽ lưu vào lịch sử điều chỉnh tồn kho.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Xem lại'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () {
                final batchProvider = context.read<BatchProvider>();
                final ok = checkProvider.completeSession(batchProvider: batchProvider);
                Navigator.of(dialogCtx).pop();

                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã hoàn tất kiểm kê và cập nhật tồn kho thành công!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                  Navigator.of(context).pushNamed(AppRoutes.inventoryCheckHistory);
                }
              },
              child: const Text('Xác nhận cập nhật', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkProvider = context.watch<InventoryCheckProvider>();
    final batchProvider = context.watch<BatchProvider>();
    final session = checkProvider.activeSession;
    final items = session?.items ?? const <InventoryCheckItem>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(session != null ? 'Kiểm kê: ${session.code}' : 'Kiểm kê kho hàng'),
        actions: [
          IconButton(
            tooltip: 'Lịch sử kiểm kê',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.inventoryCheckHistory),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner trạng thái & nút Quét QR
          Container(
            padding: const EdgeInsets.all(14),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phiên kiểm kê đang hoạt động',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      Text(
                        'Đã kiểm: ${items.length} lô • Lệch: ${session != null ? NumberFormatter.quantity(session.totalDifference) : '0'} kg',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: const Text('Quét QR Lô'),
                  onPressed: _openQrScannerForBatch,
                ),
              ],
            ),
          ),

          // Danh sách các lô đã kiểm trong phiên
          Expanded(
            child: items.isEmpty
                ? SingleChildScrollView(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_scanner, size: 56, color: AppTheme.textSecondary),
                            const SizedBox(height: 12),
                            const Text(
                              'Chưa có lô nào được kiểm kê trong phiên',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Bấm nút "Quét QR Lô" ở trên hoặc chọn nhanh lô bên dưới để bắt đầu đếm số lượng.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: batchProvider.batches.take(4).map((b) {
                                return ActionChip(
                                  label: Text('${b.code} (${b.riceName})'),
                                  onPressed: () => _openCountDialog(b),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final batch = batchProvider.findById(item.batchId) ??
                          BatchModel(
                            id: item.batchId,
                            code: item.batchCode,
                            riceId: '',
                            riceName: item.riceName,
                            quantity: item.expectedQuantity,
                            importDate: DateTime.now(),
                            manufactureDate: DateTime.now(),
                            expiryDate: DateTime.now(),
                            status: BatchStatus.available,
                          );

                      final isDiff = item.hasDifference;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.batchCode,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          item.riceName,
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Đếm lại',
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    onPressed: () => _openCountDialog(batch, item),
                                  ),
                                  IconButton(
                                    tooltip: 'Xóa khỏi phiên',
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.dangerColor),
                                    onPressed: () => checkProvider.removeItem(item.batchId),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Hệ thống: ${NumberFormatter.quantity(item.expectedQuantity)} kg',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                  Text(
                                    'Thực tế: ${NumberFormatter.quantity(item.actualQuantity)} kg',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDiff
                                          ? AppTheme.warningColor.withOpacity(0.15)
                                          : AppTheme.successColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isDiff
                                          ? '${item.difference >= 0 ? '+' : ''}${NumberFormatter.quantity(item.difference)} kg'
                                          : 'Khớp 100%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDiff ? AppTheme.warningColor : AppTheme.successColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (isDiff) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Lý do: ${item.reason.label}${item.note != null ? ' (${item.note})' : ''}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.dangerColor),
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
      bottomNavigationBar: items.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.borderColor)),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showConfirmAdjustmentDialog,
                child: Text(
                  'Xác nhận điều chỉnh tồn kho (${items.length} lô)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
    );
  }
}
