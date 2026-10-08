import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/import_receipt_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/models/supplier_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/widgets/custom_text_field.dart';

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

  SupplierModel? _selectedSupplier;
  RiceModel? _selectedRice;
  DateTime? _manufactureDate;
  DateTime? _expiryDate;

  double get _totalAmount {
    final quantity = _parseNumber(_quantityController.text) ?? 0;
    final price = _parseNumber(_purchasePriceController.text) ?? 0;
    return quantity > 0 && price >= 0 ? quantity * price : 0;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _batchCodeController.dispose();
    _manufactureDateController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  String? _validatePositiveNumber(String? value, String fieldName) {
    final number = _parseNumber(value ?? '');
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    if (number == null || !number.isFinite) {
      return '$fieldName phải là số hợp lệ';
    }
    if (number <= 0) {
      return '$fieldName phải lớn hơn 0';
    }
    return null;
  }

  String? _validateNonNegativeNumber(String? value, String fieldName) {
    final number = _parseNumber(value ?? '');
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    if (number == null || !number.isFinite) {
      return '$fieldName phải là số hợp lệ';
    }
    if (number < 0) {
      return '$fieldName không được nhỏ hơn 0';
    }
    return null;
  }

  String? _validateBatchCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập mã lô';
    }
    if (context.read<BatchProvider>().isBatchCodeExists(value)) {
      return 'Mã lô đã tồn tại';
    }
    return null;
  }

  Future<void> _selectManufactureDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _manufactureDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );
    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _manufactureDate = selected;
      _manufactureDateController.text = DateFormatter.ddMMyyyy(selected);
    });
  }

  Future<void> _selectExpiryDate() async {
    final now = DateTime.now();
    final initialDate = _expiryDate ??
        (_manufactureDate?.add(const Duration(days: 365)) ??
            now.add(const Duration(days: 365)));
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 20),
    );
    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _expiryDate = selected;
      _expiryDateController.text = DateFormatter.ddMMyyyy(selected);
    });
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final supplier = _selectedSupplier!;
    final rice = _selectedRice!;
    final quantity = _parseNumber(_quantityController.text)!;
    final purchasePrice = _parseNumber(_purchasePriceController.text)!;
    final now = DateTime.now();
    final identifier = now.microsecondsSinceEpoch.toString();
    final provider = context.read<ImportProvider>();
    final receipt = ImportReceiptModel(
      id: 'import-$identifier',
      code: provider.generateReceiptCode(),
      supplierId: supplier.id,
      supplierName: supplier.name,
      date: now,
      riceId: rice.id,
      riceName: rice.name,
      quantity: quantity,
      purchasePrice: purchasePrice,
      totalAmount: quantity * purchasePrice,
      batchCode: _batchCodeController.text.trim(),
      manufactureDate: _manufactureDate!,
      expiryDate: _expiryDate!,
    );
    final today = DateTime(now.year, now.month, now.day);
    final batch = BatchModel(
      id: 'batch-$identifier',
      code: _batchCodeController.text.trim(),
      riceId: rice.id,
      riceName: rice.name,
      quantity: quantity,
      importDate: now,
      manufactureDate: _manufactureDate!,
      expiryDate: _expiryDate!,
      status: _expiryDate!.isBefore(today)
          ? BatchStatus.expired
          : BatchStatus.available,
    );

    final created = provider.createImportReceipt(
      receipt: receipt,
      batch: batch,
    );
    if (!created) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã lô đã tồn tại')),
      );
      return;
    }

    Navigator.of(context).pop('Nhập kho thành công');
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

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo phiếu nhập')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              DropdownButtonFormField<SupplierModel>(
                value: _selectedSupplier,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Nhà cung cấp'),
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
                onChanged: (value) {
                  setState(() {
                    _selectedSupplier = value;
                  });
                },
                validator: (value) =>
                    value == null ? 'Vui lòng chọn nhà cung cấp' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RiceModel>(
                value: _selectedRice,
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
                  setState(() {
                    _selectedRice = value;
                    if (value != null) {
                      _purchasePriceController.text =
                          _numberText(value.purchasePrice);
                    }
                  });
                },
                validator: (value) =>
                    value == null ? 'Vui lòng chọn loại gạo' : null,
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
                    _validatePositiveNumber(value, 'số lượng'),
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
                    _validateNonNegativeNumber(value, 'giá nhập'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _batchCodeController,
                label: 'Mã lô',
                textInputAction: TextInputAction.next,
                validator: _validateBatchCode,
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final rice = _selectedRice;
                  final prefix = rice?.code ?? 'LO';
                  final existingBatches = rice == null
                      ? context.watch<BatchProvider>().batches
                      : context.watch<BatchProvider>().findByRiceId(rice.id);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Gợi ý mã lô (Nhấp để điền nhanh):',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              final nextNum = existingBatches.length + 1;
                              final code =
                                  'LO-$prefix-${nextNum.toString().padLeft(3, '0')}';
                              setState(() {
                                _batchCodeController.text = code;
                              });
                            },
                            icon: const Icon(Icons.auto_awesome_rounded,
                                size: 14),
                            label: const Text('Tạo mã mới',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      if (existingBatches.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            ActionChip(
                              backgroundColor: AppTheme.primaryLight,
                              label: Text(
                                'Tạo mới: LO-$prefix-${(existingBatches.length + 1).toString().padLeft(3, '0')}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _batchCodeController.text =
                                      'LO-$prefix-${(existingBatches.length + 1).toString().padLeft(3, '0')}';
                                });
                              },
                            ),
                            ...existingBatches.take(4).map((b) => ActionChip(
                                  label: Text(
                                    '${b.code} (${b.quantity.toInt()}kg)',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _batchCodeController.text = '${b.code}-N2';
                                    });
                                  },
                                )),
                          ],
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
                validator: (_) => _manufactureDate == null
                    ? 'Vui lòng chọn ngày sản xuất'
                    : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _expiryDateController,
                label: 'Hạn sử dụng',
                readOnly: true,
                onTap: _selectExpiryDate,
                suffixIcon: const Icon(Icons.event_available_outlined),
                validator: (_) {
                  if (_expiryDate == null) {
                    return 'Vui lòng chọn hạn sử dụng';
                  }
                  if (_manufactureDate != null &&
                      !_expiryDate!.isAfter(_manufactureDate!)) {
                    return 'Hạn sử dụng phải sau ngày sản xuất';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFFE3FCEF),
                child: ListTile(
                  leading: Icon(
                    Icons.payments_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text(
                    'Tổng tiền',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: Text(
                    CurrencyFormatter.formatVnd(_totalAmount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Xác nhận nhập kho'),
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
