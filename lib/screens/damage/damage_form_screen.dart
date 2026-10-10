import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/damage_provider.dart';

class DamageFormScreen extends StatefulWidget {
  const DamageFormScreen({super.key, this.initialBatch});

  final BatchModel? initialBatch;

  @override
  State<DamageFormScreen> createState() => _DamageFormScreenState();
}

class _DamageFormScreenState extends State<DamageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  BatchModel? _selectedBatch;
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  DamageReason _selectedReason = DamageReason.baoRach;
  String? _selectedImagePath;

  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickEvidenceImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh hiện trường'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1920,
    );
    if (image != null && mounted) {
      setState(() => _selectedImagePath = image.path);
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedBatch = widget.initialBatch;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedBatch == null) {
      AppToast.warning(context, 'Vui lòng chọn lô gạo cần báo hỏng.');
      return;
    }

    final qty =
        double.tryParse(_quantityController.text.trim().replaceAll(',', '.'));
    if (qty == null || qty <= 0) {
      AppToast.error(context, 'Số lượng báo hỏng phải lớn hơn 0.');
      return;
    }

    if (qty > _selectedBatch!.quantity) {
      AppToast.error(
        context,
        'Số lượng $qty kg vượt tồn khả dụng ${_selectedBatch!.quantity} kg.',
      );
      return;
    }

    final batchProvider = context.read<BatchProvider>();
    final damageProvider = context.read<DamageProvider>();

    final success = damageProvider.createDamageReport(
      batchId: _selectedBatch!.id,
      batchCode: _selectedBatch!.code,
      riceId: _selectedBatch!.riceId,
      riceName: _selectedBatch!.riceName,
      quantity: qty,
      reason: _selectedReason,
      batchProvider: batchProvider,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      imagePath: _selectedImagePath,
      createdBy: 'Admin',
    );

    if (success) {
      AppToast.success(
        context,
        'Đã ghi nhận $qty kg hư hỏng cho lô ${_selectedBatch!.code}.',
      );
      Navigator.of(context).pushReplacementNamed(AppRoutes.damageReportList);
    } else {
      AppToast.error(context, 'Không thể tạo báo hỏng. Kiểm tra lại tồn kho.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchProvider = context.watch<BatchProvider>();
    final availableBatches = batchProvider.batches
        .where((b) => b.quantity > 0 && b.status != BatchStatus.expired)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lập phiếu báo hỏng gạo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Chọn Lô hàng
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thông tin Lô gạo bị hỏng',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedBatch?.id,
                        decoration: const InputDecoration(
                          labelText: 'Chọn lô hàng',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        items: availableBatches.map((b) {
                          return DropdownMenuItem(
                            value: b.id,
                            child: Text(
                              '${b.code} - ${b.riceName} (Tồn: ${b.quantity} kg)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null) {
                            setState(() {
                              _selectedBatch = batchProvider.findById(id);
                            });
                          }
                        },
                        validator: (v) =>
                            v == null ? 'Vui lòng chọn lô hàng' : null,
                      ),
                      if (_selectedBatch != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Tồn kho khả dụng:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${NumberFormatter.quantity(_selectedBatch!.quantity)} kg',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Thông tin thiệt hại & Lý do
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chi tiết thiệt hại',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Số lượng gạo bị hỏng (kg)',
                          suffixText: 'kg',
                          prefixIcon: Icon(Icons.scale_outlined),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập số lượng hỏng';
                          }
                          final parsed =
                              double.tryParse(val.replaceAll(',', '.'));
                          if (parsed == null || parsed <= 0) {
                            return 'Số lượng phải lớn hơn 0';
                          }
                          if (_selectedBatch != null &&
                              parsed > _selectedBatch!.quantity) {
                            return 'Vượt quá tồn kho (${_selectedBatch!.quantity} kg)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<DamageReason>(
                        isExpanded: true,
                        initialValue: _selectedReason,
                        decoration: const InputDecoration(
                          labelText: 'Nguyên nhân hư hỏng',
                          prefixIcon: Icon(Icons.warning_amber_rounded),
                        ),
                        items: DamageReason.values.map((r) {
                          return DropdownMenuItem(
                            value: r,
                            child: Text(
                              r.label,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedReason = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú mô tả hiện trường hư hỏng',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Ảnh chụp minh chứng (Task 3.3)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Ảnh chụp minh chứng',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedImagePath != null)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _selectedImagePath = null),
                              child: const Text('Xóa ảnh',
                                  style:
                                      TextStyle(color: AppTheme.dangerColor)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_selectedImagePath == null)
                        InkWell(
                          onTap: _pickEvidenceImage,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.borderColor,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined,
                                      size: 28, color: AppTheme.primaryColor),
                                  SizedBox(height: 6),
                                  Text(
                                    'Chụp ảnh hoặc chọn ảnh minh chứng',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              Image.file(
                                File(_selectedImagePath!),
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: FilledButton.tonalIcon(
                                  onPressed: _pickEvidenceImage,
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Đổi ảnh'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Nút xác nhận
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dangerColor,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _submit,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Xác nhận báo hỏng & Giảm tồn kho',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
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
