import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/widgets/custom_text_field.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';

class RiceFormScreen extends StatefulWidget {
  const RiceFormScreen({
    super.key,
    this.riceId,
    this.isEditing = false,
  });

  final String? riceId;
  final bool isEditing;

  @override
  State<RiceFormScreen> createState() => _RiceFormScreenState();
}

class _RiceFormScreenState extends State<RiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _unitController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _minimumStockController = TextEditingController();
  final _descriptionController = TextEditingController();

  RiceModel? _originalRice;
  bool _isActive = true;
  bool _initialized = false;

  bool get _hasValidRice => !widget.isEditing || _originalRice != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (widget.isEditing && widget.riceId != null) {
      _originalRice = context.read<RiceProvider>().findById(widget.riceId!);
      final rice = _originalRice;
      if (rice != null) {
        _codeController.text = rice.code;
        _nameController.text = rice.name;
        _categoryController.text = rice.category;
        _unitController.text = rice.unit;
        _purchasePriceController.text = _numberText(rice.purchasePrice);
        _sellingPriceController.text = _numberText(rice.sellingPrice);
        _minimumStockController.text = _numberText(rice.minimumStock);
        _descriptionController.text = rice.description;
        _isActive = rice.isActive;
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _minimumStockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    return null;
  }

  String? _validateCode(String? value) {
    final requiredError = _requiredValidator(value, 'mã gạo');
    if (requiredError != null) {
      return requiredError;
    }

    final isDuplicated = context.read<RiceProvider>().isCodeExists(
          value!,
          excludeId: _originalRice?.id,
        );
    return isDuplicated ? 'Mã gạo đã tồn tại' : null;
  }

  String? _validateNumber(String? value, String fieldName) {
    final requiredError = _requiredValidator(value, fieldName);
    if (requiredError != null) {
      return requiredError;
    }

    final number = _parseNumber(value!);
    if (number == null || !number.isFinite) {
      return '$fieldName phải là số hợp lệ';
    }
    if (number < 0) {
      return '$fieldName không được nhỏ hơn 0';
    }
    return null;
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final riceProvider = context.read<RiceProvider>();
    final rice = RiceModel(
      id: _originalRice?.id ??
          'rice-${DateTime.now().microsecondsSinceEpoch.toString()}',
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      category: _categoryController.text.trim(),
      unit: _unitController.text.trim(),
      purchasePrice: _parseNumber(_purchasePriceController.text)!,
      sellingPrice: _parseNumber(_sellingPriceController.text)!,
      minimumStock: _parseNumber(_minimumStockController.text)!,
      description: _descriptionController.text.trim(),
      isActive: _isActive,
    );

    final saved = widget.isEditing
        ? riceProvider.updateRice(rice)
        : riceProvider.addRice(rice);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Không thể lưu. Vui lòng kiểm tra mã gạo.')),
      );
      return;
    }

    Navigator.of(context).pop(
      widget.isEditing ? 'Cập nhật gạo thành công' : 'Thêm gạo thành công',
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Sửa gạo' : 'Thêm gạo';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: !_hasValidRice
          ? const EmptyState(
              icon: Icons.error_outline_rounded,
              message: 'Không tìm thấy loại gạo cần chỉnh sửa',
            )
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    CustomTextField(
                      controller: _codeController,
                      label: 'Mã gạo',
                      validator: _validateCode,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _nameController,
                      label: 'Tên gạo',
                      validator: (value) =>
                          _requiredValidator(value, 'tên gạo'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _categoryController,
                      label: 'Loại gạo',
                      validator: (value) =>
                          _requiredValidator(value, 'loại gạo'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _unitController,
                      label: 'Đơn vị',
                      validator: (value) => _requiredValidator(value, 'đơn vị'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _purchasePriceController,
                      label: 'Giá nhập',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) => _validateNumber(value, 'Giá nhập'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _sellingPriceController,
                      label: 'Giá bán',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) => _validateNumber(value, 'Giá bán'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _minimumStockController,
                      label: 'Tồn tối thiểu',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) =>
                          _validateNumber(value, 'Tồn tối thiểu'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _descriptionController,
                      label: 'Mô tả (không bắt buộc)',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: SwitchListTile(
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                        title: const Text('Đang hoạt động'),
                        subtitle: const Text('Cho phép sử dụng loại gạo này'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _save,
                            child: const Text('Lưu'),
                          ),
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
