import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_rice_warehouse/widgets/modern_date_picker.dart';
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

  static const String _newBatchOption = '__NEW_BATCH__';

  SupplierModel? _selectedSupplier;
  RiceModel? _selectedRice;
  DateTime? _manufactureDate;
  DateTime? _expiryDate;
  String _selectedBatchCode = _newBatchOption;

  void _selectBatch(BatchModel batch) {
    _selectedBatchCode = batch.code;
    _batchCodeController.text = batch.code;
    _manufactureDate = batch.manufactureDate;
    _manufactureDateController.text =
        DateFormatter.ddMMyyyy(batch.manufactureDate);
    _expiryDate = batch.expiryDate;
    _expiryDateController.text = DateFormatter.ddMMyyyy(batch.expiryDate);
  }

  void _selectNewBatchMode([RiceModel? rice]) {
    final targetRice = rice ?? _selectedRice;
    _selectedBatchCode = _newBatchOption;
    final prefix = targetRice?.code ?? 'LO';
    final batches = targetRice == null
        ? context.read<BatchProvider>().batches
        : context.read<BatchProvider>().findByRiceId(targetRice.id);
    final nextCode =
        'LO-$prefix-${(batches.length + 1).toString().padLeft(3, '0')}';
    _batchCodeController.text = nextCode;
    final now = DateTime.now();
    _manufactureDate ??= now;
    _manufactureDateController.text = DateFormatter.ddMMyyyy(_manufactureDate!);
    _expiryDate ??= now.add(const Duration(days: 365));
    _expiryDateController.text = DateFormatter.ddMMyyyy(_expiryDate!);
  }

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
    if (_selectedBatchCode != _newBatchOption) {
      return null;
    }
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập mã lô mới';
    }
    if (context.read<BatchProvider>().isBatchCodeExists(value.trim())) {
      return 'Mã lô "${value.trim()}" đã tồn tại. Vui lòng chọn lô từ danh sách hoặc nhập mã khác.';
    }
    return null;
  }

  Future<void> _selectManufactureDate() async {
    final now = DateTime.now();
    final selected = await ModernDatePicker.show(
      context: context,
      title: 'Chọn Ngày Sản Xuất',
      initialDate: _manufactureDate ?? now,
      minDate: DateTime(2000),
      maxDate: DateTime(now.year + 10),
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
    final selected = await ModernDatePicker.show(
      context: context,
      title: 'Chọn Hạn Sử Dụng',
      initialDate: initialDate,
      minDate: _manufactureDate ?? DateTime(2000),
      maxDate: DateTime(now.year + 20),
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
    final identifier = const Uuid().v4();
    final provider = context.read<ImportProvider>();
    final isNew = _selectedBatchCode == _newBatchOption;
    final batchCode =
        isNew ? _batchCodeController.text.trim() : _selectedBatchCode;

    final receipt = ImportReceiptModel(
      id: identifier,
      code: provider.generateReceiptCode(),
      supplierId: supplier.id,
      supplierName: supplier.name,
      date: now,
      riceId: rice.id,
      riceName: rice.name,
      quantity: quantity,
      purchasePrice: purchasePrice,
      totalAmount: quantity * purchasePrice,
      batchCode: batchCode,
      manufactureDate: _manufactureDate!,
      expiryDate: _expiryDate!,
    );
    final today = DateTime(now.year, now.month, now.day);
    final batch = BatchModel(
      id: identifier,
      code: batchCode,
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
        const SnackBar(content: Text('Không thể tạo phiếu nhập cho mã lô này')),
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
                initialValue: _selectedSupplier,
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
                initialValue: _selectedRice,
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
                      final batches =
                          context.read<BatchProvider>().findByRiceId(value.id);
                      if (batches.isNotEmpty) {
                        _selectBatch(batches.first);
                      } else {
                        _selectNewBatchMode(value);
                      }
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
              Builder(
                builder: (context) {
                  final rice = _selectedRice;
                  final prefix = rice?.code ?? 'LO';
                  final existingBatches = rice == null
                      ? context.watch<BatchProvider>().batches
                      : context.watch<BatchProvider>().findByRiceId(rice.id);

                  final validCodes = {
                    ...existingBatches.map((b) => b.code),
                    _newBatchOption,
                  };
                  final currentValue = validCodes.contains(_selectedBatchCode)
                      ? _selectedBatchCode
                      : (existingBatches.isNotEmpty
                          ? existingBatches.first.code
                          : _newBatchOption);

                  final isCreatingNew = currentValue == _newBatchOption;
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
                          helperText: !isCreatingNew && selectedExisting != null
                              ? 'Lô tồn: ${selectedExisting.quantity.toInt()}kg • HSD: ${DateFormatter.ddMMyyyy(selectedExisting.expiryDate)} (Cộng dồn)'
                              : null,
                          helperStyle: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.accentGreen,
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
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const DropdownMenuItem<String>(
                            value: _newBatchOption,
                            child: Text(
                              '✨ + Tạo mã lô mới',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            if (value == _newBatchOption) {
                              _selectNewBatchMode();
                            } else {
                              final found = existingBatches
                                  .firstWhere((b) => b.code == value);
                              _selectBatch(found);
                            }
                          });
                        },
                      ),
                      if (isCreatingNew) ...[
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: _batchCodeController,
                          label:
                              'Mã lô mới (Gợi ý: LO-$prefix-${(existingBatches.length + 1).toString().padLeft(3, '0')})',
                          textInputAction: TextInputAction.next,
                          validator: _validateBatchCode,
                          suffixIcon: IconButton(
                            tooltip: 'Điền mã gợi ý',
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            onPressed: () {
                              setState(() {
                                _batchCodeController.text =
                                    'LO-$prefix-${(existingBatches.length + 1).toString().padLeft(3, '0')}';
                              });
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
