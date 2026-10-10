import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/customer_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/services/fefo_service.dart';
import 'package:smart_rice_warehouse/widgets/custom_text_field.dart';
import 'package:smart_rice_warehouse/widgets/sticky_action_bar.dart';

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

  // Đơn vị xuất: 0: Kg, 1: Bao (50kg), 2: Tạ (100kg), 3: Tấn (1000kg)
  int _selectedUnitIndex = 0;
  static const _unitMultipliers = [1.0, 50.0, 100.0, 1000.0];
  static const _unitLabels = ['Kg', 'Bao (50kg)', 'Tạ (100kg)', 'Tấn'];

  CustomerModel? _selectedCustomer;
  RiceModel? _selectedRice;

  double get _calculatedQuantityKg {
    final input = _parseNumber(_quantityController.text) ?? 0.0;
    return input * _unitMultipliers[_selectedUnitIndex];
  }

  double get _totalAmount {
    final qtyKg = _calculatedQuantityKg;
    final pricePerKg = _parseNumber(_sellingPriceController.text) ?? 0;
    return qtyKg > 0 && pricePerKg >= 0 ? qtyKg * pricePerKg : 0;
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
      final reqKg = _calculatedQuantityKg;
      if (reqKg > currentStock) {
        return 'Vượt quá tồn kho khả dụng (${NumberFormatter.quantity(currentStock)} ${rice.unit})';
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
    final quantityKg = _calculatedQuantityKg;
    final sellingPrice = _parseNumber(_sellingPriceController.text)!;

    final exportProvider = context.read<ExportProvider>();
    final fefoResult = exportProvider.previewFefoAllocation(
      riceId: rice.id,
      quantity: quantityKg,
    );

    if (!fefoResult.isSuccess) {
      AppToast.warning(
        context,
        fefoResult.errorMessage ?? 'Không đủ tồn kho khả dụng để xuất.',
      );
      return;
    }

    _showFefoPreviewBottomSheet(
      fefoResult: fefoResult,
      customer: customer,
      rice: rice,
      quantityKg: quantityKg,
      sellingPrice: sellingPrice,
    );
  }

  void _showFefoPreviewBottomSheet({
    required FefoAllocationResult fefoResult,
    required CustomerModel customer,
    required RiceModel rice,
    required double quantityKg,
    required double sellingPrice,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(bottomSheetContext);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.76,
          minChildSize: 0.5,
          maxChildSize: 0.94,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: ListView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.alt_route_rounded,
                          color: AppTheme.secondaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phân bổ lô hàng xuất (FEFO)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              'Ưu tiên xuất lô cận hạn nhất trước để giảm thiểu hao hụt',
                              style: TextStyle(
                                fontSize: 12,
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
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      children: [
                        _summaryRow('Khách hàng:', customer.name),
                        const SizedBox(height: 6),
                        _summaryRow(
                            'Mặt hàng:', '${rice.name} (${rice.category})'),
                        const SizedBox(height: 6),
                        _summaryRow(
                          'Tổng lượng xuất:',
                          '${NumberFormatter.quantity(quantityKg)} kg (~ ${(quantityKg / 1000).toStringAsFixed(2)} Tấn)',
                          isBold: true,
                        ),
                        const SizedBox(height: 6),
                        _summaryRow(
                          'Tổng thành tiền:',
                          CurrencyFormatter.formatVnd(
                              quantityKg * sellingPrice),
                          color: AppTheme.secondaryColor,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Chi tiết phân bổ (${fefoResult.allocations.length} lô gạo):',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ...fefoResult.allocations.map((alloc) {
                    final daysLeft = alloc.daysUntilExpiry;
                    final isWarning = daysLeft <= 30;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isWarning
                              ? AppTheme.warningBorder
                              : AppTheme.borderColor,
                        ),
                        boxShadow: AppTheme.softShadow,
                      ),
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
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    alloc.batchCode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isWarning
                                      ? AppTheme.warningBg
                                      : AppTheme.safeBg,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: isWarning
                                        ? AppTheme.warningBorder
                                        : AppTheme.safeBorder,
                                  ),
                                ),
                                child: Text(
                                  'HSD: ${DateFormatter.ddMMyyyy(alloc.expiryDate)} (${daysLeft}d)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isWarning
                                        ? AppTheme.warningText
                                        : AppTheme.safeText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Lấy từ lô này:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                '${NumberFormatter.quantity(alloc.allocatedQuantity)} kg (~ ${(alloc.allocatedQuantity / 50).round()} bao)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.secondaryColor,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Còn lại sau xuất:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                '${NumberFormatter.quantity(alloc.batchRemainingQuantity)} kg',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 18),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.of(bottomSheetContext).pop();
                      _confirmExport(
                        fefoResult: fefoResult,
                        customer: customer,
                        rice: rice,
                        quantityKg: quantityKg,
                        sellingPrice: sellingPrice,
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text(
                      'Xác nhận xuất kho theo FEFO',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
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
    required double quantityKg,
    required double sellingPrice,
  }) {
    final now = DateTime.now();
    final provider = context.read<ExportProvider>();
    final receipt = ExportReceiptModel(
      id: const Uuid().v4(),
      code: provider.generateReceiptCode(),
      customerId: customer.id,
      customerName: customer.name,
      date: now,
      riceId: rice.id,
      riceName: rice.name,
      quantity: quantityKg,
      sellingPrice: sellingPrice,
      totalAmount: quantityKg * sellingPrice,
      note: _noteController.text.trim(),
      allocations: fefoResult.allocations,
    );

    if (!provider.createExportReceipt(receipt)) {
      _formKey.currentState?.validate();
      AppToast.error(context, 'Xuất kho thất bại: không đủ tồn kho khả dụng.');
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
        Text(label,
            style:
                const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
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
      appBar: AppBar(title: const Text('Tạo phiếu xuất kho gạo')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // NHÓM 1: ĐỐI TÁC & MẶT HÀNG
                    _ExportSectionCard(
                      title: '1. Khách hàng & Mặt hàng xuất',
                      icon: Icons.storefront_rounded,
                      children: [
                        DropdownButtonFormField<CustomerModel>(
                          initialValue: _selectedCustomer,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Đại lý / Khách hàng',
                            prefixIcon:
                                Icon(Icons.person_outline_rounded, size: 20),
                          ),
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
                        const SizedBox(height: 12),
                        DropdownButtonFormField<RiceModel>(
                          initialValue: _selectedRice,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Mặt hàng gạo xuất',
                            prefixIcon:
                                Icon(Icons.rice_bowl_outlined, size: 20),
                          ),
                          items: rices
                              .map(
                                (rice) => DropdownMenuItem(
                                  value: rice,
                                  child: Text(
                                    '${rice.name} (${rice.code}) - ${rice.category}',
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
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.safeBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined,
                                    size: 16, color: AppTheme.primaryDark),
                                const SizedBox(width: 8),
                                Text(
                                  'Tồn kho khả dụng: ${NumberFormatter.quantity(currentStock)} ${selectedRice.unit} '
                                  '(~ ${(currentStock / 50).round()} bao 50kg)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),

                    // NHÓM 2: KHỐI LƯỢNG XUẤT & QUY ĐỔI ĐƠN VỊ
                    _ExportSectionCard(
                      title: '2. Khối lượng xuất & Quy đổi đơn vị',
                      icon: Icons.scale_rounded,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Đơn vị quy đổi nhanh:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children:
                                    List.generate(_unitLabels.length, (idx) {
                                  final isSelected = _selectedUnitIndex == idx;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(_unitLabels[idx]),
                                      selected: isSelected,
                                      selectedColor: AppTheme.secondaryLight,
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? AppTheme.secondaryColor
                                            : AppTheme.textSecondary,
                                      ),
                                      side: BorderSide(
                                        color: isSelected
                                            ? AppTheme.secondaryColor
                                            : AppTheme.borderColor,
                                      ),
                                      onSelected: (val) {
                                        if (val) {
                                          setState(() {
                                            _selectedUnitIndex = idx;
                                          });
                                        }
                                      },
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _quantityController,
                          label:
                              'Số lượng xuất (${_unitLabels[_selectedUnitIndex]})',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textInputAction: TextInputAction.next,
                          validator: _validateQuantity,
                          onChanged: (_) => setState(() {}),
                          suffixIcon: _calculatedQuantityKg > 0
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 12),
                                  child: Text(
                                    '= ${_formatNumber(_calculatedQuantityKg)} kg',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.secondaryColor,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // NHÓM 3: GIÁ BÁN & GHI CHÚ
                    _ExportSectionCard(
                      title: '3. Giá bán & Ghi chú xuất kho',
                      icon: Icons.receipt_long_rounded,
                      children: [
                        CustomTextField(
                          controller: _sellingPriceController,
                          label: 'Giá bán (VNĐ/kg)',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textInputAction: TextInputAction.next,
                          validator: _validateSellingPrice,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _noteController,
                          label: 'Ghi chú xuất kho / Số xe vận chuyển',
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // THANH CÔNG CỤ GHIM CỐ ĐỊNH Ở ĐÁY (STICKY ACTION BAR)
              StickyActionBar(
                primaryLabel: 'Kiểm tra & Phân bổ FEFO',
                primaryIcon: Icons.alt_route_rounded,
                primaryColor: AppTheme.secondaryColor,
                onPrimaryPressed: _reviewFefoAndSubmit,
                secondaryLabel: 'Hủy bỏ',
                onSecondaryPressed: () => Navigator.of(context).maybePop(),
                summaryWidget: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.warningBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.warningBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tổng sản lượng xuất:',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_formatNumber(_calculatedQuantityKg)} kg (~ ${(_calculatedQuantityKg / 1000).toStringAsFixed(2)} Tấn)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Tổng tiền dự tính:',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatVnd(_totalAmount),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.secondaryColor,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportSectionCard extends StatelessWidget {
  const _ExportSectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor, width: 1),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.secondaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
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

String _formatNumber(double val) {
  if (val == val.roundToDouble()) {
    return val.toInt().toString();
  }
  return val.toStringAsFixed(1).replaceAll('.', ',');
}
