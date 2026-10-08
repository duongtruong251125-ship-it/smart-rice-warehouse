import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/customer_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/services/fefo_service.dart';
import 'package:smart_rice_warehouse/widgets/custom_text_field.dart';

class ExportFormScreen extends StatefulWidget {
  const ExportFormScreen({super.key});

  @override
  State<ExportFormScreen> createState() => _ExportFormScreenState();
}

class _ExportFormScreenState extends State<ExportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _noteController = TextEditingController();

  CustomerModel? _selectedCustomer;
  RiceModel? _selectedRice;

  double get _totalAmount {
    final quantity = _parseNumber(_quantityController.text) ?? 0;
    final price = _parseNumber(_sellingPriceController.text) ?? 0;
    return quantity > 0 && price >= 0 ? quantity * price : 0;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _sellingPriceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _validateQuantity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập số lượng';
    }
    final quantity = _parseNumber(value);
    if (quantity == null || !quantity.isFinite) {
      return 'Số lượng phải là số hợp lệ';
    }
    if (quantity <= 0) {
      return 'Số lượng phải lớn hơn 0';
    }

    final rice = _selectedRice;
    if (rice != null) {
      final currentStock =
          context.read<BatchProvider>().totalStockForRice(rice.id);
      if (quantity > currentStock) {
        return 'Số lượng xuất vượt quá tồn kho khả dụng hiện tại ($currentStock ${rice.unit})';
      }
    }
    return null;
  }

  String? _validateSellingPrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập giá bán';
    }
    final price = _parseNumber(value);
    if (price == null || !price.isFinite) {
      return 'Giá bán phải là số hợp lệ';
    }
    if (price < 0) {
      return 'Giá bán không được nhỏ hơn 0';
    }
    return null;
  }

  void _reviewFefoAndSubmit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final customer = _selectedCustomer!;
    final rice = _selectedRice!;
    final quantity = _parseNumber(_quantityController.text)!;
    final sellingPrice = _parseNumber(_sellingPriceController.text)!;

    final exportProvider = context.read<ExportProvider>();
    final fefoResult = exportProvider.previewFefoAllocation(
      riceId: rice.id,
      quantity: quantity,
    );

    if (!fefoResult.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fefoResult.errorMessage ?? 'Không đủ tồn kho khả dụng để xuất',
          ),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
      return;
    }

    _showFefoPreviewBottomSheet(
      fefoResult: fefoResult,
      customer: customer,
      rice: rice,
      quantity: quantity,
      sellingPrice: sellingPrice,
    );
  }

  void _showFefoPreviewBottomSheet({
    required FefoAllocationResult fefoResult,
    required CustomerModel customer,
    required RiceModel rice,
    required double quantity,
    required double sellingPrice,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        final theme = Theme.of(bottomSheetContext);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.alt_route_rounded,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phân bổ lô hàng (FEFO)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Ưu tiên xuất lô cận hạn nhất trước',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Order summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      children: [
                        _summaryRow('Khách hàng:', customer.name),
                        const SizedBox(height: 6),
                        _summaryRow('Mặt hàng:', '${rice.name} (${rice.unit})'),
                        const SizedBox(height: 6),
                        _summaryRow(
                          'Tổng lượng xuất:',
                          '${NumberFormatter.quantity(quantity)} ${rice.unit}',
                          isBold: true,
                        ),
                        const SizedBox(height: 6),
                        _summaryRow(
                          'Tổng thành tiền:',
                          CurrencyFormatter.formatVnd(quantity * sellingPrice),
                          color: AppTheme.secondaryColor,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Chi tiết các lô được xuất (${fefoResult.allocations.length} lô):',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  ...fefoResult.allocations.map((alloc) {
                    final daysLeft = alloc.daysUntilExpiry;
                    final isWarning = daysLeft <= 30;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.qr_code_2,
                                      size: 16,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      alloc.batchCode,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isWarning
                                        ? AppTheme.secondaryColor
                                            .withValues(alpha: 0.15)
                                        : AppTheme.accentGreen
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'HSD: ${DateFormatter.ddMMyyyy(alloc.expiryDate)} (${daysLeft}d)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isWarning
                                          ? AppTheme.secondaryColor
                                          : AppTheme.accentGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Lấy từ lô này:',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                Text(
                                  '${NumberFormatter.quantity(alloc.allocatedQuantity)} ${rice.unit}',
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
                                  'Còn lại sau xuất:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  '${NumberFormatter.quantity(alloc.batchRemainingQuantity)} ${rice.unit}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(bottomSheetContext).pop();
                      _confirmExport(
                        fefoResult: fefoResult,
                        customer: customer,
                        rice: rice,
                        quantity: quantity,
                        sellingPrice: sellingPrice,
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Xác nhận xuất kho'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(bottomSheetContext).pop(),
                    child: const Text('Chỉnh sửa lại'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmExport({
    required FefoAllocationResult fefoResult,
    required CustomerModel customer,
    required RiceModel rice,
    required double quantity,
    required double sellingPrice,
  }) {
    final now = DateTime.now();
    final provider = context.read<ExportProvider>();
    final receipt = ExportReceiptModel(
      id: 'export-${now.microsecondsSinceEpoch}',
      code: provider.generateReceiptCode(),
      customerId: customer.id,
      customerName: customer.name,
      date: now,
      riceId: rice.id,
      riceName: rice.name,
      quantity: quantity,
      sellingPrice: sellingPrice,
      totalAmount: quantity * sellingPrice,
      note: _noteController.text.trim(),
      allocations: fefoResult.allocations,
    );

    if (!provider.createExportReceipt(receipt)) {
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xuất kho thất bại: Không đủ tồn kho khả dụng'),
        ),
      );
      return;
    }

    Navigator.of(context).pop('Xuất kho thành công theo quy tắc FEFO');
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final customers = context
        .watch<CustomerProvider>()
        .customers
        .where((customer) => customer.isActive)
        .toList(growable: false);
    final rices = context
        .watch<RiceProvider>()
        .rices
        .where((rice) => rice.isActive)
        .toList(growable: false);
    final selectedRice = _selectedRice;
    final currentStock = selectedRice == null
        ? 0.0
        : context.watch<BatchProvider>().totalStockForRice(selectedRice.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo phiếu xuất kho')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              DropdownButtonFormField<CustomerModel>(
                initialValue: _selectedCustomer,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Khách hàng'),
                items: customers
                    .map(
                      (customer) => DropdownMenuItem(
                        value: customer,
                        child: Text(
                          customer.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  setState(() {
                    _selectedCustomer = value;
                  });
                },
                validator: (value) =>
                    value == null ? 'Vui lòng chọn khách hàng' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RiceModel>(
                initialValue: _selectedRice,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Gạo xuất kho'),
                items: rices
                    .map(
                      (rice) => DropdownMenuItem(
                        value: rice,
                        child: Text(
                          '${rice.name} (${rice.code})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  setState(() {
                    _selectedRice = value;
                    if (value != null) {
                      _sellingPriceController.text =
                          _numberText(value.sellingPrice);
                    }
                  });
                },
                validator: (value) =>
                    value == null ? 'Vui lòng chọn loại gạo' : null,
              ),
              if (selectedRice != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.inventory_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    title: const Text('Tồn kho khả dụng'),
                    subtitle: const Text('Chỉ tính các lô còn hạn sử dụng'),
                    trailing: Text(
                      '${NumberFormatter.quantity(currentStock)} '
                      '${selectedRice.unit}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: currentStock > 0
                                ? AppTheme.accentGreen
                                : AppTheme.secondaryColor,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Mã lô hàng có sẵn trong kho (Nhấp để chọn nhanh):',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final batches = context
                        .watch<BatchProvider>()
                        .findByRiceId(selectedRice.id)
                        .where((b) {
                          if (b.quantity <= 0 || b.status == BatchStatus.expired) {
                            return false;
                          }
                          final exp = DateTime(
                              b.expiryDate.year, b.expiryDate.month, b.expiryDate.day);
                          return !exp.isBefore(today);
                        })
                        .toList();

                    if (batches.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Không có lô hàng nào còn hạn và khả dụng trong kho',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    }

                    batches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

                    return Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: batches.map((batch) {
                        final daysLeft =
                            batch.expiryDate.difference(today).inDays;
                        final isCritical = daysLeft <= 7;
                        final isWarning = daysLeft <= 30;

                        final Color chipBg = isCritical
                            ? const Color(0xFFFEF2F2)
                            : isWarning
                                ? const Color(0xFFFFFBEB)
                                : const Color(0xFFF0FDF4);
                        final Color chipBorder = isCritical
                            ? const Color(0xFFFECACA)
                            : isWarning
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFBBF7D0);
                        final Color chipText = isCritical
                            ? const Color(0xFFDC2626)
                            : isWarning
                                ? const Color(0xFFD97706)
                                : const Color(0xFF15803D);

                        return ActionChip(
                          backgroundColor: chipBg,
                          side: BorderSide(color: chipBorder),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          avatar: Icon(
                            isCritical
                                ? Icons.error_outline_rounded
                                : isWarning
                                    ? Icons.warning_amber_rounded
                                    : Icons.inventory_2_outlined,
                            size: 16,
                            color: chipText,
                          ),
                          label: Text(
                            '${batch.code} (${NumberFormatter.quantity(batch.quantity)}kg • còn $daysLeft ngày)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: chipText,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _quantityController.text =
                                  batch.quantity == batch.quantity.roundToDouble()
                                      ? batch.quantity.toInt().toString()
                                      : batch.quantity.toString();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Đã chọn mã lô ${batch.code} (${NumberFormatter.quantity(batch.quantity)} kg)'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              CustomTextField(
                controller: _quantityController,
                label: 'Số lượng xuất (kg)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: _validateQuantity,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _sellingPriceController,
                label: 'Giá bán (VNĐ/kg)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: _validateSellingPrice,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _noteController,
                label: 'Ghi chú (không bắt buộc)',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFFFEF3C7),
                child: ListTile(
                  leading: const Icon(
                    Icons.payments_outlined,
                    color: Color(0xFFD97706),
                  ),
                  title: const Text(
                    'Tổng tiền dự tính',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: Text(
                    CurrencyFormatter.formatVnd(_totalAmount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFB45309),
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _reviewFefoAndSubmit,
                    icon: const Icon(Icons.alt_route_rounded),
                    label: const Text('Kiểm tra & Phân bổ FEFO'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Hủy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double? _parseNumber(String value) {
  return double.tryParse(value.trim().replaceAll(',', '.'));
}

String _numberText(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
