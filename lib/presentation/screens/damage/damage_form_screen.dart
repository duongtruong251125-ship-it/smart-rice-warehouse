import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/presentation/utils/app_toast.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/models/damage_report_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/damage_provider.dart';
import 'package:smart_rice_warehouse/logic/view_models/damage_form_view_model.dart';

class DamageFormScreen extends StatefulWidget {
  const DamageFormScreen({super.key, this.initialBatch});

  final BatchModel? initialBatch;

  @override
  State<DamageFormScreen> createState() => _DamageFormScreenState();
}

class _DamageFormScreenState extends State<DamageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  late final DamageFormViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = DamageFormViewModel(initialBatch: widget.initialBatch);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

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
      _viewModel.setSelectedImagePath(image.path);
    }
  }

  Future<void> _submit() async {
    if (_viewModel.isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final batchProvider = context.read<BatchProvider>();
    final damageProvider = context.read<DamageProvider>();
    final result = await _viewModel.submit(
      batchProvider: batchProvider,
      damageProvider: damageProvider,
      quantityText: _quantityController.text,
      note: _noteController.text,
      createdBy: 'Admin',
    );

    if (result.success) {
      if (!mounted) return;
      AppToast.success(
        context,
        'Đã ghi nhận ${result.quantity} kg hư hỏng cho lô ${_viewModel.selectedBatch?.code ?? ''}.',
      );
      Navigator.of(context).pushReplacementNamed(AppRoutes.damageReportList);
    } else {
      if (!mounted) return;
      AppToast.error(context, result.message ?? 'Không thể tạo báo hỏng.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchProvider = context.watch<BatchProvider>();

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final availableBatches = _viewModel.getAvailableBatches(batchProvider);

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
                            initialValue: _viewModel.selectedBatch?.id,
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
                                _viewModel.setSelectedBatch(
                                    batchProvider.findById(id));
                              }
                            },
                            validator: (v) =>
                                v == null ? 'Vui lòng chọn lô hàng' : null,
                          ),
                          if (_viewModel.selectedBatch != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBg(context),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: AppTheme.border(context)),
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'Tồn kho khả dụng:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondaryColor(
                                            context)),
                                  ),
                                  Text(
                                    '${NumberFormatter.quantity(_viewModel.selectedBatch!.quantity)} kg',
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
                              if (_viewModel.selectedBatch != null &&
                                  parsed > _viewModel.selectedBatch!.quantity) {
                                return 'Vượt quá tồn kho (${_viewModel.selectedBatch!.quantity} kg)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<DamageReason>(
                            isExpanded: true,
                            initialValue: _viewModel.selectedReason,
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
                                _viewModel.setSelectedReason(val);
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
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              const Text(
                                'Ảnh chụp minh chứng',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              if (_viewModel.selectedImagePath != null)
                                TextButton(
                                  onPressed: () =>
                                      _viewModel.setSelectedImagePath(null),
                                  child: const Text('Xóa ảnh',
                                      style: TextStyle(
                                          color: AppTheme.dangerColor)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_viewModel.selectedImagePath == null)
                            InkWell(
                              onTap: _pickEvidenceImage,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                constraints:
                                    const BoxConstraints(minHeight: 100),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBg(context),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.border(context),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add_a_photo_outlined,
                                          size: 28,
                                          color: AppTheme.primaryColor),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Chụp ảnh hoặc chọn ảnh minh chứng',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondaryColor(
                                                context)),
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
                                    File(_viewModel.selectedImagePath!),
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
                  if (_viewModel.lastError != null &&
                      _viewModel.lastError!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerBgColor(context),
                        borderRadius: BorderRadius.circular(10),
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
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  AppTheme.dangerTextColor(context),
                              minimumSize: const Size(84, 44),
                            ),
                            onPressed: _viewModel.isSubmitting ? null : _submit,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text(
                              'Thử lại',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Nút xác nhận
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.dangerColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _viewModel.isSubmitting ? null : _submit,
                    icon: _viewModel.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.report_problem_outlined, size: 18),
                    label: Text(
                      _viewModel.isSubmitting
                          ? 'Đang xử lý...'
                          : 'Xác nhận báo hỏng & Giảm tồn kho',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
