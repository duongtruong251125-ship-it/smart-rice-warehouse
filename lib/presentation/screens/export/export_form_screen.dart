import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/logic/models/customer_model.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/services/fefo_service.dart';
import 'package:smart_rice_warehouse/logic/view_models/export_form_view_model.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/presentation/utils/app_toast.dart';
import 'package:smart_rice_warehouse/presentation/widgets/custom_text_field.dart';
import 'package:smart_rice_warehouse/presentation/widgets/sticky_action_bar.dart';

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

  late final ExportFormViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ExportFormViewModel();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _sellingPriceController.dispose();
    _noteController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _reviewFefoAndSubmit() {
    if (_viewModel.isSubmitting) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final previewResult = _viewModel.previewFefo(
      exportProvider: context.read<ExportProvider>(),
      batchProvider: context.read<BatchProvider>(),
      quantityText: _quantityController.text,
      sellingPriceText: _sellingPriceController.text,
    );

    if (!previewResult.success || previewResult.result == null) {
      AppToast.warning(
        context,
        previewResult.error ?? 'Không đủ tồn kho khả dụng để xuất.',
      );
      return;
    }

    _showFefoPreviewBottomSheet(fefoResult: previewResult.result!);
  }

  void _showFefoPreviewBottomSheet({
    required FefoAllocationResult fefoResult,
  }) {
    final customer = _viewModel.selectedCustomer!;
    final rice = _viewModel.selectedRice!;
    final quantityKg = _viewModel.lastCalculatedQuantityKg;
    final sellingPrice = _viewModel.lastCalculatedSellingPrice;

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
                            Text(
                              'Ưu tiên xuất lô cận hạn nhất trước để giảm thiểu hao hụt',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor(context),
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
                      color: AppTheme.isDark(context)
                          ? AppTheme.darkCardElevated
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border(context)),
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
                        color: AppTheme.cardBg(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isWarning
                              ? AppTheme.warningBorderColor(context)
                              : AppTheme.border(context),
                        ),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      alloc.batchCode,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
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
                                      ? AppTheme.warningBgColor(context)
                                      : AppTheme.safeBgColor(context),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: isWarning
                                        ? AppTheme.warningBorderColor(context)
                                        : AppTheme.safeBorderColor(context),
                                  ),
                                ),
                                child: Text(
                                  'HSD: ${DateFormatter.ddMMyyyy(alloc.expiryDate)} (${daysLeft}d)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isWarning
                                        ? AppTheme.warningTextColor(context)
                                        : AppTheme.safeTextColor(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Lấy từ lô này:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                              ),
                              Text(
                                '${NumberFormatter.quantity(alloc.allocatedQuantity)} kg (~ ${(alloc.allocatedQuantity / 50).round()} bao)',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.warningTextColor(context),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Còn lại sau xuất:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                              ),
                              Text(
                                '${NumberFormatter.quantity(alloc.batchRemainingQuantity)} kg',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 12,
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
                      backgroundColor: AppTheme.warningText,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _viewModel.isSubmitting
                        ? null
                        : () {
                            Navigator.of(bottomSheetContext).pop();
                            _confirmExport();
                          },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text(
                      'Xác nhận xuất kho theo FEFO',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
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

  Future<void> _confirmExport() async {
    if (_viewModel.isSubmitting) return;
    final result = await _viewModel.confirmExport(
      exportProvider: context.read<ExportProvider>(),
      note: _noteController.text.trim(),
    );

    if (!mounted) return;

    if (!result.success) {
      _formKey.currentState?.validate();
      AppToast.error(
        context,
        result.message ?? 'Xuất kho thất bại: không đủ tồn kho khả dụng.',
      );
      return;
    }

    Navigator.of(context).pop(
      result.message ?? 'Xuất kho thành công theo quy tắc FEFO',
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12.5, color: AppTheme.textSecondaryColor(context))),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? AppTheme.textPrimaryColor(context),
            ),
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

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final selectedRice = _viewModel.selectedRice;
        final currentStock = selectedRice == null
            ? 0.0
            : context.watch<BatchProvider>().totalStockForRice(selectedRice.id);
        final calculatedQtyKg =
            _viewModel.calculateQuantityKg(_quantityController.text);
        final totalAmount = _viewModel.calculateTotalAmount(
          _quantityController.text,
          _sellingPriceController.text,
        );

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
                              initialValue: _viewModel.selectedCustomer,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Đại lý / Khách hàng',
                                prefixIcon: Icon(Icons.person_outline_rounded,
                                    size: 20),
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
                              onChanged: (value) =>
                                  _viewModel.setCustomer(value),
                              validator: _viewModel.validateCustomer,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<RiceModel>(
                              initialValue: _viewModel.selectedRice,
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
                                _viewModel.setRice(value);
                                if (value != null) {
                                  _sellingPriceController.text =
                                      _numberText(value.sellingPrice);
                                }
                              },
                              validator: _viewModel.validateRice,
                            ),
                            if (selectedRice != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.safeBgColor(context),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppTheme.safeBorderColor(context)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.inventory_2_outlined,
                                        size: 16,
                                        color: AppTheme.safeTextColor(context)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Tồn kho khả dụng: ${NumberFormatter.quantity(currentStock)} ${selectedRice.unit} '
                                        '(~ ${(currentStock / 50).round()} bao 50kg)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              AppTheme.safeTextColor(context),
                                        ),
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
                                Text(
                                  'Đơn vị quy đổi nhanh:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondaryColor(context),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: List.generate(
                                      ExportFormViewModel.unitLabels.length,
                                      (idx) {
                                        final isSelected =
                                            _viewModel.selectedUnitIndex == idx;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(right: 6),
                                          child: ChoiceChip(
                                            label: Text(
                                              ExportFormViewModel
                                                  .unitLabels[idx],
                                            ),
                                            selected: isSelected,
                                            selectedColor:
                                                AppTheme.warningBgColor(
                                                    context),
                                            labelStyle: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              color: isSelected
                                                  ? AppTheme.warningTextColor(
                                                      context)
                                                  : AppTheme.textSecondaryColor(
                                                      context),
                                            ),
                                            side: BorderSide(
                                              color: isSelected
                                                  ? AppTheme.warningBorderColor(
                                                      context)
                                                  : AppTheme.border(context),
                                            ),
                                            onSelected: (val) {
                                              if (val) {
                                                _viewModel.setUnitIndex(idx);
                                              }
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              controller: _quantityController,
                              label:
                                  'Số lượng xuất (${ExportFormViewModel.unitLabels[_viewModel.selectedUnitIndex]})',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) => _viewModel.validateQuantity(
                                value,
                                context.read<BatchProvider>(),
                              ),
                              onChanged: (_) => setState(() {}),
                              suffixIcon: calculatedQtyKg > 0
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 12),
                                      child: Text(
                                        '= ${_formatNumber(calculatedQtyKg)} kg',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.warningTextColor(
                                              context),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textInputAction: TextInputAction.next,
                              validator: _viewModel.validateSellingPrice,
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
                    primaryColor: AppTheme.warningText,
                    isLoading: _viewModel.isSubmitting,
                    errorMessage: _viewModel.lastError,
                    onRetry: _reviewFefoAndSubmit,
                    onPrimaryPressed: _reviewFefoAndSubmit,
                    secondaryLabel: 'Hủy bỏ',
                    onSecondaryPressed: () => Navigator.of(context).maybePop(),
                    summaryWidget: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.warningBgColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.warningBorderColor(context)),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tổng sản lượng xuất:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_formatNumber(calculatedQtyKg)} kg (~ ${(calculatedQtyKg / 1000).toStringAsFixed(2)} Tấn)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimaryColor(context),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Tổng tiền dự tính:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatVnd(totalAmount),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.warningTextColor(context),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
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
      },
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
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context), width: 1),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.secondaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryColor(context),
                  ),
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
