import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/inventory_check_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/inventory_check_provider.dart';
import 'package:smart_rice_warehouse/screens/scanner/qr_scanner_screen.dart';
import 'package:smart_rice_warehouse/widgets/sticky_action_bar.dart';

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
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInsets = MediaQuery.of(ctx).viewInsets.bottom;
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInsets),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
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
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Loại gạo: ${batch.riceName} • Vị trí: ${batch.locationName ?? 'Khu A'}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tồn kho hệ thống:',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${NumberFormatter.quantity(batch.quantity)} kg (~ ${(batch.quantity / 50).round()} bao 50kg)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: actualCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Số lượng thực tế đếm được (kg)',
                          suffixText: 'kg',
                          prefixIcon: Icon(Icons.scale_rounded, size: 20),
                        ),
                        onChanged: (val) {
                          final parsed =
                              double.tryParse(val.replaceAll(',', '.'));
                          setSheetState(() {
                            if (parsed != null) {
                              currentDiff = parsed - batch.quantity;
                              if (currentDiff.abs() < 0.001) {
                                selectedReason = InventoryCheckReason.none;
                              } else if (selectedReason ==
                                  InventoryCheckReason.none) {
                                selectedReason = InventoryCheckReason.haoHut;
                              }
                            }
                          });
                        },
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập số lượng thực tế';
                          }
                          final parsed =
                              double.tryParse(val.replaceAll(',', '.'));
                          if (parsed == null || parsed < 0) {
                            return 'Số lượng không được âm';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Hiển thị chênh lệch
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: currentDiff.abs() < 0.001
                              ? AppTheme.safeBg
                              : (currentDiff < 0
                                  ? AppTheme.dangerBg
                                  : AppTheme.warningBg),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: currentDiff.abs() < 0.001
                                ? AppTheme.safeBorder
                                : (currentDiff < 0
                                    ? AppTheme.dangerBorder
                                    : AppTheme.warningBorder),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Chênh lệch đếm thực tế:',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              currentDiff.abs() < 0.001
                                  ? 'Khớp 100% (Chuẩn)'
                                  : '${currentDiff >= 0 ? '+' : ''}${NumberFormatter.quantity(currentDiff)} kg (~ ${(currentDiff / 50).abs().toStringAsFixed(1)} bao)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: currentDiff.abs() < 0.001
                                    ? AppTheme.safeText
                                    : (currentDiff < 0
                                        ? AppTheme.dangerText
                                        : AppTheme.warningText),
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bắt buộc chọn lý do nếu có chênh lệch
                      if (currentDiff.abs() >= 0.001) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Lý do chênh lệch (Bắt buộc):',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<InventoryCheckReason>(
                          initialValue:
                              selectedReason == InventoryCheckReason.none
                                  ? InventoryCheckReason.haoHut
                                  : selectedReason,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                          items: InventoryCheckReason.values
                              .where((r) => r != InventoryCheckReason.none)
                              .map((r) => DropdownMenuItem(
                                  value: r, child: Text(r.label)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => selectedReason = val);
                            }
                          },
                        ),
                      ],

                      const SizedBox(height: 12),
                      TextFormField(
                        controller: noteCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Ghi chú thêm (tùy chọn)'),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            final actual = double.parse(
                                actualCtrl.text.trim().replaceAll(',', '.'));
                            context
                                .read<InventoryCheckProvider>()
                                .addOrUpdateItem(
                                  batch: batch,
                                  actualQuantity: actual,
                                  reason: currentDiff.abs() < 0.001
                                      ? InventoryCheckReason.none
                                      : selectedReason,
                                  note: noteCtrl.text.trim().isEmpty
                                      ? null
                                      : noteCtrl.text.trim(),
                                );
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        child: const Text(
                          'Lưu kết quả kiểm kê lô',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Xác nhận hoàn thành kiểm kê?'),
          content: Text(
            'Hệ thống sẽ cập nhật lại số lượng tồn kho của ${session.items.length} lô theo số liệu thực tế.\n\n'
            'Tổng chênh lệch: ${session.totalDifference >= 0 ? '+' : ''}${NumberFormatter.quantity(session.totalDifference)} kg.\n'
            'Thao tác này sẽ lưu vào lịch sử điều chỉnh kho gạo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Xem lại'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor),
              onPressed: () {
                final batchProvider = context.read<BatchProvider>();
                final ok =
                    checkProvider.completeSession(batchProvider: batchProvider);
                Navigator.of(dialogCtx).pop();

                if (ok) {
                  AppToast.success(
                    context,
                    'Đã hoàn tất kiểm kê và cập nhật tồn kho.',
                  );
                  Navigator.of(context)
                      .pushNamed(AppRoutes.inventoryCheckHistory);
                } else {
                  AppToast.error(
                    context,
                    'Không thể hoàn tất kiểm kê. Kiểm tra lại các lô đã chọn.',
                  );
                }
              },
              child: const Text('Xác nhận cập nhật'),
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
        title: Text(
            session != null ? 'Kiểm kê: ${session.code}' : 'Kiểm kê kho hàng'),
        actions: [
          IconButton(
            tooltip: 'Lịch sử kiểm kê',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context)
                .pushNamed(AppRoutes.inventoryCheckHistory),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner phiên kiểm kê
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.cardColor,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phiên kiểm kê đang hoạt động',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Đã kiểm: ${items.length} lô • Chênh lệch: ${session != null ? '${session.totalDifference >= 0 ? '+' : ''}${NumberFormatter.quantity(session.totalDifference)} kg' : '0 kg'}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    minimumSize: const Size(0, 40),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('Quét QR Lô',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: _openQrScannerForBatch,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Danh sách các lô đã kiểm trong phiên
          Expanded(
            child: items.isEmpty
                ? SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: const BoxDecoration(
                                color: AppTheme.accentTealLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.fact_check_outlined,
                                  size: 36, color: AppTheme.accentTeal),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Chưa có lô nào được kiểm kê trong phiên',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Bấm nút "Quét QR Lô" ở trên hoặc chọn nhanh lô gợi ý dưới đây để nhập khối lượng thực tế.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: batchProvider.batches.take(4).map((b) {
                                return ActionChip(
                                  backgroundColor: AppTheme.cardColor,
                                  side: const BorderSide(
                                      color: AppTheme.borderColor),
                                  label: Text('${b.code} (${b.riceName})',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
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
                    physics: const BouncingScrollPhysics(),
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

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDiff
                                ? AppTheme.warningBorder
                                : AppTheme.borderColor,
                          ),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.batchCode,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        item.riceName,
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Đếm lại',
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () =>
                                      _openCountDialog(batch, item),
                                ),
                                IconButton(
                                  tooltip: 'Xóa khỏi phiên',
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: AppTheme.dangerColor),
                                  onPressed: () =>
                                      checkProvider.removeItem(item.batchId),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Hệ thống: ${NumberFormatter.quantity(item.expectedQuantity)} kg',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary),
                                ),
                                Text(
                                  'Thực tế: ${NumberFormatter.quantity(item.actualQuantity)} kg',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDiff
                                        ? AppTheme.warningBg
                                        : AppTheme.safeBg,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: isDiff
                                          ? AppTheme.warningBorder
                                          : AppTheme.safeBorder,
                                    ),
                                  ),
                                  child: Text(
                                    isDiff
                                        ? '${item.difference >= 0 ? '+' : ''}${NumberFormatter.quantity(item.difference)} kg'
                                        : 'Khớp 100%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDiff
                                          ? AppTheme.warningText
                                          : AppTheme.safeText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (isDiff) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.dangerBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Lý do: ${item.reason.label}${item.note != null ? ' (${item.note})' : ''}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.dangerText,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: items.isEmpty
          ? null
          : StickyActionBar(
              primaryLabel: 'Xác nhận điều chỉnh tồn kho (${items.length} lô)',
              primaryIcon: Icons.check_circle_outline_rounded,
              onPrimaryPressed: _showConfirmAdjustmentDialog,
              summaryWidget: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng chênh lệch phiên kiểm:',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  Text(
                    '${session != null ? (session.totalDifference >= 0 ? '+' : '') : ''}${session != null ? NumberFormatter.quantity(session.totalDifference) : '0'} kg',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: session != null && session.totalDifference < 0
                          ? AppTheme.dangerText
                          : AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
