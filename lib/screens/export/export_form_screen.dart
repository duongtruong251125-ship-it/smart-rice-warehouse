import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/customer_model.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
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
        return 'Số lượng xuất vượt quá tồn kho hiện tại';
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

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final customer = _selectedCustomer!;
    final rice = _selectedRice!;
    final quantity = _parseNumber(_quantityController.text)!;
    final sellingPrice = _parseNumber(_sellingPriceController.text)!;
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
    );

    if (!provider.createExportReceipt(receipt)) {
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số lượng xuất vượt quá tồn kho hiện tại'),
        ),
      );
      return;
    }

    Navigator.of(context).pop('Xuất kho thành công');
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
      appBar: AppBar(title: const Text('Tạo phiếu xuất')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              DropdownButtonFormField<CustomerModel>(
                value: _selectedCustomer,
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
                    leading: const Icon(Icons.inventory_outlined),
                    title: const Text('Tồn hiện tại'),
                    trailing: Text(
                      '${NumberFormatter.quantity(currentStock)} '
                      '${selectedRice.unit}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              CustomTextField(
                controller: _quantityController,
                label: 'Số lượng',
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
                label: 'Giá bán',
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
                    'Tổng tiền',
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
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Xác nhận xuất kho'),
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
