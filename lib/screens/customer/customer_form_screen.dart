import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/core/utils/form_validators.dart';
import 'package:smart_rice_warehouse/models/customer_model.dart';
import 'package:smart_rice_warehouse/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/widgets/custom_text_field.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({
    super.key,
    this.customerId,
    this.isEditing = false,
  });

  final String? customerId;
  final bool isEditing;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  CustomerModel? _originalCustomer;
  CustomerType? _customerType;
  bool _isActive = true;
  bool _initialized = false;

  bool get _hasValidCustomer => !widget.isEditing || _originalCustomer != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (widget.isEditing && widget.customerId != null) {
      _originalCustomer =
          context.read<CustomerProvider>().findById(widget.customerId!);
      final customer = _originalCustomer;
      if (customer != null) {
        _nameController.text = customer.name;
        _phoneController.text = customer.phone;
        _addressController.text = customer.address;
        _customerType = customer.customerType;
        _isActive = customer.isActive;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final customer = CustomerModel(
      id: _originalCustomer?.id ??
          const Uuid().v4(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      customerType: _customerType!,
      address: _addressController.text.trim(),
      isActive: _isActive,
    );
    final provider = context.read<CustomerProvider>();

    if (widget.isEditing) {
      if (!provider.updateCustomer(customer)) {
        AppToast.error(context, 'Không thể cập nhật khách hàng.');
        return;
      }
    } else {
      provider.addCustomer(customer);
    }

    Navigator.of(context).pop(
      widget.isEditing
          ? 'Cập nhật khách hàng thành công'
          : 'Thêm khách hàng thành công',
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Sửa khách hàng' : 'Thêm khách hàng';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: !_hasValidCustomer
          ? const EmptyState(
              icon: Icons.error_outline_rounded,
              message: 'Không tìm thấy khách hàng cần chỉnh sửa',
            )
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    CustomTextField(
                      controller: _nameController,
                      label: 'Tên khách hàng',
                      validator: (value) =>
                          FormValidators.required(value, 'tên khách hàng'),
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
                    DropdownButtonFormField<CustomerType>(
                      initialValue: _customerType,
                      decoration:
                          const InputDecoration(labelText: 'Loại khách'),
                      isExpanded: true,
                      items: CustomerType.values
                          .map(
                            (type) => DropdownMenuItem<CustomerType>(
                              value: type,
                              child: Text(type.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        setState(() {
                          _customerType = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Vui lòng chọn loại khách' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _addressController,
                      label: 'Địa chỉ',
                      validator: (value) =>
                          FormValidators.required(value, 'địa chỉ'),
                      maxLines: 2,
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
                        subtitle: const Text('Cho phép sử dụng khách hàng này'),
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
