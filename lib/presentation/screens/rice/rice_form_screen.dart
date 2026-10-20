import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/logic/services/catalog_form_service.dart';
import 'package:smart_rice_warehouse/logic/validators/form_validators.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/presentation/utils/app_toast.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_characteristic_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/presentation/screens/rice/rice_characteristics_screen.dart';
import 'package:smart_rice_warehouse/presentation/widgets/custom_text_field.dart';
import 'package:smart_rice_warehouse/presentation/widgets/empty_state.dart';

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
  String? _imagePath;
  List<String> _selectedCharacteristicIds = [];
  bool _isSaving = false;
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
        _imagePath = rice.imagePath;
        _selectedCharacteristicIds = List<String>.from(rice.characteristicIds);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _imagePath = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Không thể chọn ảnh: $e');
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Chọn ảnh minh họa giống gạo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppTheme.primaryColor),
                title: const Text('Chụp ảnh hạt gạo mới'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppTheme.primaryColor),
                title: const Text('Chọn ảnh từ thư viện'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_imagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.dangerColor),
                  title: const Text('Xóa ảnh hiện tại',
                      style: TextStyle(color: AppTheme.dangerColor)),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    setState(() => _imagePath = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
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
    return FormValidators.required(value, fieldName);
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
    return FormValidators.number(value, fieldName);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);
    final riceProvider = context.read<RiceProvider>();
    final saved = await CatalogFormService().saveRice(
      provider: riceProvider,
      original: _originalRice,
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      category: _categoryController.text.trim(),
      unit: _unitController.text.trim(),
      purchasePrice: _parseNumber(_purchasePriceController.text)!,
      sellingPrice: _parseNumber(_sellingPriceController.text)!,
      minimumStock: _parseNumber(_minimumStockController.text)!,
      description: _descriptionController.text.trim(),
      isActive: _isActive,
      imagePath: _imagePath,
      characteristicIds: _selectedCharacteristicIds,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!saved) {
      AppToast.error(context, 'Không thể lưu. Vui lòng kiểm tra mã gạo.');
      return;
    }

    Navigator.of(context).pop(
      widget.isEditing ? 'Cập nhật gạo thành công' : 'Thêm gạo thành công',
    );
  }

  Widget _buildImagePickerSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasImage = _imagePath != null && _imagePath!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.image_outlined,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Ảnh minh họa giống gạo',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasImage)
                  TextButton.icon(
                    onPressed: () => setState(() => _imagePath = null),
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppTheme.dangerColor),
                    label: const Text('Xóa ảnh',
                        style: TextStyle(
                            color: AppTheme.dangerColor, fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (hasImage) ...[
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      image: DecorationImage(
                        image: _imagePath!.startsWith('assets/')
                            ? AssetImage(_imagePath!)
                            : FileImage(File(_imagePath!)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: ElevatedButton.icon(
                      onPressed: _showImageSourcePicker,
                      icon: const Icon(Icons.photo_camera_rounded, size: 16),
                      label:
                          const Text('Đổi ảnh', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              InkWell(
                onTap: _showImageSourcePicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.35),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          size: 24,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chụp ảnh hoặc tải ảnh hạt gạo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Giúp nhận diện trực quan trong kho & đơn hàng',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCharacteristicsSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final charProvider = context.watch<RiceCharacteristicProvider>();
    final characteristics = charProvider.characteristics;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Đặc tính gạo',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      RiceCharacteristicsScreen.showAddOrEditDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Thêm mới', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Chọn một hoặc nhiều đặc tính (Dẻo, Xốp, Thơm, Mềm, Khô...):',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            if (characteristics.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Chưa có đặc tính nào. Nhấn "+ Thêm mới" để tạo.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: characteristics.map((char) {
                  final isSelected =
                      _selectedCharacteristicIds.contains(char.id);
                  final color = Color(char.colorValue);

                  return FilterChip(
                    label: Text(
                      char.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? color : colorScheme.onSurface,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCharacteristicIds.add(char.id);
                        } else {
                          _selectedCharacteristicIds.remove(char.id);
                        }
                      });
                    },
                    selectedColor: color.withValues(alpha: 0.16),
                    checkmarkColor: color,
                    backgroundColor: colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected
                            ? color
                            : colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
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
                    _buildImagePickerSection(context),
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
                    _buildCharacteristicsSection(context),
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
                            onPressed: _isSaving ? null : _save,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Lưu'),
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
  return FormValidators.parseNumber(value);
}

String _numberText(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
