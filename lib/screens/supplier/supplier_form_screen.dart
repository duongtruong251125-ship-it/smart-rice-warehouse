import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/core/utils/form_validators.dart';
import 'package:smart_rice_warehouse/models/supplier_model.dart';
import 'package:smart_rice_warehouse/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/widgets/custom_text_field.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';

class SupplierFormScreen extends StatefulWidget {
  const SupplierFormScreen({
    super.key,
    this.supplierId,
    this.isEditing = false,
  });

  final String? supplierId;
  final bool isEditing;

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxCodeController = TextEditingController();

  SupplierModel? _originalSupplier;
  bool _isActive = true;
  bool _initialized = false;

  bool get _hasValidSupplier => !widget.isEditing || _originalSupplier != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (widget.isEditing && widget.supplierId != null) {
      _originalSupplier =
          context.read<SupplierProvider>().findById(widget.supplierId!);
      final supplier = _originalSupplier;
      if (supplier != null) {
        _nameController.text = supplier.name;
        _phoneController.text = supplier.phone;
        _emailController.text = supplier.email;
        _addressController.text = supplier.address;
        _taxCodeController.text = supplier.taxCode;
        _isActive = supplier.isActive;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _taxCodeController.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final supplier = SupplierModel(
      id: _originalSupplier?.id ??
          const Uuid().v4(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      taxCode: _taxCodeController.text.trim(),
      isActive: _isActive,
    );
    final provider = context.read<SupplierProvider>();

    if (widget.isEditing) {
      if (!provider.updateSupplier(supplier)) {
        AppToast.error(context, 'Không thể cập nhật nhà cung cấp.');
        return;
      }
    } else {
      provider.addSupplier(supplier);
    }

    Navigator.of(context).pop(
      widget.isEditing
          ? 'Cập nhật nhà cung cấp thành công'
          : 'Thêm nhà cung cấp thành công',
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Sửa nhà cung cấp' : 'Thêm nhà cung cấp';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: !_hasValidSupplier
          ? const EmptyState(
              icon: Icons.error_outline_rounded,
              message: 'Không tìm thấy nhà cung cấp cần chỉnh sửa',
            )
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    CustomTextField(
                      controller: _nameController,
                      label: 'Tên nhà cung cấp',
                      validator: (value) =>
                          FormValidators.required(value, 'tên nhà cung cấp'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _phoneController,
                      label: 'Số điện thoại',
                      validator: FormValidators.phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email (không bắt buộc)',
                      validator: FormValidators.optionalEmail,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _addressController,
                      label: 'Địa chỉ',
                      validator: (value) =>
                          FormValidators.required(value, 'địa chỉ'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _taxCodeController,
                      label: 'Mã số thuế (không bắt buộc)',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
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
                        subtitle:
                            const Text('Cho phép sử dụng nhà cung cấp này'),
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
