import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/models/supplier_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/logic/view_models/import_form_view_model.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/presentation/utils/app_toast.dart';
import 'package:smart_rice_warehouse/presentation/widgets/custom_text_field.dart';
import 'package:smart_rice_warehouse/presentation/widgets/modern_date_picker.dart';

class ImportFormScreen extends StatefulWidget {
  const ImportFormScreen({super.key});

  @override
  State<ImportFormScreen> createState() => _ImportFormScreenState();
}

class _ImportFormScreenState extends State<ImportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _batchCodeController = TextEditingController();
  final _manufactureDateController = TextEditingController();
  final _expiryDateController = TextEditingController();

  late final ImportFormViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ImportFormViewModel();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _batchCodeController.dispose();
    _manufactureDateController.dispose();
    _expiryDateController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _syncControllersFromViewModel() {
    if (_viewModel.isCreatingNewBatch) {
      _batchCodeController.text = _viewModel.suggestedBatchCode;
    } else {
      _batchCodeController.text = _viewModel.selectedBatchCode;
    }
    if (_viewModel.manufactureDate != null) {
      _manufactureDateController.text =
          DateFormatter.ddMMyyyy(_viewModel.manufactureDate!);
    }
    if (_viewModel.expiryDate != null) {
      _expiryDateController.text =
          DateFormatter.ddMMyyyy(_viewModel.expiryDate!);
    }
  }

  Future<void> _selectManufactureDate() async {
    final now = DateTime.now();
    final selected = await ModernDatePicker.show(
      context: context,
      title: 'Chọn Ngày Sản Xuất',
      initialDate: _viewModel.manufactureDate ?? now,
      minDate: DateTime(2000),
      maxDate: DateTime(now.year + 10),
    );
    if (!mounted || selected == null) {
      return;
    }

    _viewModel.setManufactureDate(selected);
    _manufactureDateController.text = DateFormatter.ddMMyyyy(selected);
  }

  Future<void> _selectExpiryDate() async {
    final now = DateTime.now();
    final initialDate = _viewModel.expiryDate ??
        (_viewModel.manufactureDate?.add(const Duration(days: 365)) ??
            now.add(const Duration(days: 365)));
    final selected = await ModernDatePicker.show(
      context: context,
      title: 'Chọn Hạn Sử Dụng',
      initialDate: initialDate,
      minDate: _viewModel.manufactureDate ?? DateTime(2000),
      maxDate: DateTime(now.year + 20),
    );
    if (!mounted || selected == null) {
      return;
    }

    _viewModel.setExpiryDate(selected);
    _expiryDateController.text = DateFormatter.ddMMyyyy(selected);
  }

  Future<void> _submit() async {
    if (_viewModel.isSubmitting) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final result = await _viewModel.submitImport(
      importProvider: context.read<ImportProvider>(),
      quantityText: _quantityController.text,
      purchasePriceText: _purchasePriceController.text,
      batchCodeInput: _batchCodeController.text,
    );

    if (!mounted) return;

    if (!result.success) {
      AppToast.error(
        context,
        result.message ?? 'Không thể tạo phiếu nhập cho mã lô này',
      );
      return;
    }

    Navigator.of(context).pop(result.message ?? 'Nhập kho thành công');
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = context
        .watch<SupplierProvider>()
        .suppliers
        .where((supplier) => supplier.isActive)
        .toList(growable: false);
    final rices = context
        .watch<RiceProvider>()
        .rices
        .where((rice) => rice.isActive)
        .toList(growable: false);

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Tạo phiếu nhập')),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_viewModel.lastError != null &&
                      _viewModel.lastError!.trim().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerBgColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.dangerBorderColor(context)),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: AppTheme.dangerTextColor(context),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _viewModel.lastError!,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.dangerTextColor(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!_viewModel.isSubmitting)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    AppTheme.dangerTextColor(context),
                                side: BorderSide(
                                    color: AppTheme.dangerBorderColor(context)),
                                minimumSize: const Size(84, 44),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              onPressed: _submit,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Thử lại'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<SupplierModel>(
                    initialValue: _viewModel.selectedSupplier,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Nhà cung cấp'),
                    items: suppliers
                        .map(
                          (supplier) => DropdownMenuItem(
                            value: supplier,
                            child: Text(
                              supplier.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => _viewModel.setSupplier(value),
                    validator: _viewModel.validateSupplier,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<RiceModel>(
                    initialValue: _viewModel.selectedRice,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Gạo'),
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
                      if (value != null) {
                        _purchasePriceController.text =
                            _numberText(value.purchasePrice);
                      }
                      final allBatches = context.read<BatchProvider>().batches;
                      _viewModel.setRice(value, allBatches);
                      _syncControllersFromViewModel();
                    },
                    validator: _viewModel.validateRice,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _quantityController,
                    label: 'Số lượng',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        _viewModel.validatePositiveNumber(value, 'số lượng'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _purchasePriceController,
                    label: 'Giá nhập',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        _viewModel.validateNonNegativeNumber(value, 'giá nhập'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final rice = _viewModel.selectedRice;
                      final prefix = rice?.code ?? 'LO';
                      final existingBatches = rice == null
                          ? context.watch<BatchProvider>().batches
                          : context
                              .watch<BatchProvider>()
                              .findByRiceId(rice.id);

                      final validCodes = {
                        ...existingBatches.map((b) => b.code),
                        ImportFormViewModel.newBatchOption,
                      };
                      final currentValue =
                          validCodes.contains(_viewModel.selectedBatchCode)
                              ? _viewModel.selectedBatchCode
                              : (existingBatches.isNotEmpty
                                  ? existingBatches.first.code
                                  : ImportFormViewModel.newBatchOption);

                      final isCreatingNew =
                          currentValue == ImportFormViewModel.newBatchOption;
                      final selectedExisting = isCreatingNew
                          ? null
                          : existingBatches.firstWhere(
                              (b) => b.code == currentValue,
                              orElse: () => existingBatches.first,
                            );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            key: ValueKey('batch_dd_${rice?.id}_$currentValue'),
                            initialValue: currentValue,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Mã lô hàng',
                              prefixIcon:
                                  const Icon(Icons.qr_code_2_rounded, size: 20),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              helperText: !isCreatingNew &&
                                      selectedExisting != null
                                  ? 'Lô tồn: ${selectedExisting.quantity.toInt()}kg • HSD: ${DateFormatter.ddMMyyyy(selectedExisting.expiryDate)} (Cộng dồn)'
                                  : null,
                              helperStyle: TextStyle(
                                fontSize: 12,
                                color: AppTheme.safeTextColor(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            items: [
                              ...existingBatches.map(
                                (b) => DropdownMenuItem<String>(
                                  value: b.code,
                                  child: Text(
                                    '${b.code} (Tồn: ${b.quantity.toInt()}kg • HSD: ${DateFormatter.ddMMyyyy(b.expiryDate)})',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: ImportFormViewModel.newBatchOption,
                                child: Text(
                                  '✨ + Tạo mã lô mới',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.safeTextColor(context),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              if (value == ImportFormViewModel.newBatchOption) {
                                _viewModel.selectNewBatchMode(
                                  rice: _viewModel.selectedRice,
                                  allBatches:
                                      context.read<BatchProvider>().batches,
                                );
                              } else {
                                final found = existingBatches
                                    .firstWhere((b) => b.code == value);
                                _viewModel.selectBatch(found);
                              }
                              _syncControllersFromViewModel();
                            },
                          ),
                          if (isCreatingNew) ...[
                            const SizedBox(height: 8),
                            CustomTextField(
                              controller: _batchCodeController,
                              label:
                                  'Mã lô mới (Gợi ý: LO-$prefix-${(existingBatches.length + 1).toString().padLeft(3, '0')})',
                              textInputAction: TextInputAction.next,
                              validator: (value) =>
                                  _viewModel.validateBatchCode(
                                value,
                                context.read<BatchProvider>(),
                              ),
                              suffixIcon: IconButton(
                                tooltip: 'Điền mã gợi ý',
                                constraints: const BoxConstraints(
                                    minWidth: 44, minHeight: 44),
                                icon: const Icon(Icons.auto_awesome, size: 16),
                                onPressed: () {
                                  final suggestion = ImportFormViewModel
                                      .generateBatchCodeSuggestion(
                                    _viewModel.selectedRice,
                                    context.read<BatchProvider>().batches,
                                  );
                                  _batchCodeController.text = suggestion;
                                },
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _manufactureDateController,
                    label: 'Ngày sản xuất',
                    readOnly: true,
                    onTap: _selectManufactureDate,
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                    validator: (_) => _viewModel.validateManufactureDate(),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _expiryDateController,
                    label: 'Hạn sử dụng',
                    readOnly: true,
                    onTap: _selectExpiryDate,
                    suffixIcon: const Icon(Icons.event_available_outlined),
                    validator: (_) => _viewModel.validateExpiryDate(),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.safeBgColor(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.safeBorderColor(context),
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              color: AppTheme.safeTextColor(context),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Tổng tiền',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryColor(context),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          CurrencyFormatter.formatVnd(
                            _viewModel.calculateTotalAmount(
                              _quantityController.text,
                              _purchasePriceController.text,
                            ),
                          ),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.safeTextColor(context),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: _viewModel.isSubmitting ? null : _submit,
                        child: _viewModel.isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Xác nhận nhập kho'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _viewModel.isSubmitting
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        child: const Text('Hủy'),
                      ),
                    ],
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

String _numberText(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
