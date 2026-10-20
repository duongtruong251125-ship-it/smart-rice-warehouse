import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/logic/models/rice_model.dart';
import 'package:smart_rice_warehouse/logic/models/supplier_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/logic/view_models/ocr_invoice_view_model.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/presentation/utils/app_toast.dart';
import 'package:smart_rice_warehouse/presentation/widgets/custom_text_field.dart';

class OcrInvoiceScreen extends StatefulWidget {
  const OcrInvoiceScreen({super.key});

  @override
  State<OcrInvoiceScreen> createState() => _OcrInvoiceScreenState();
}

class _OcrInvoiceScreenState extends State<OcrInvoiceScreen> {
  final _imagePicker = ImagePicker();
  final _textController = TextEditingController();
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _batchCodeController = TextEditingController();

  late final OcrInvoiceViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = OcrInvoiceViewModel();
  }

  @override
  void dispose() {
    _textController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _batchCodeController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _syncControllersFromViewModel() {
    _quantityController.text = _viewModel.suggestedQuantityText;
    _purchasePriceController.text = _viewModel.suggestedPurchasePriceText;
    _batchCodeController.text = _viewModel.suggestedBatchCode;
  }

  Future<void> _scanDocument(ImageSource source) async {
    HapticFeedback.selectionClick();
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2400,
    );
    if (image == null || !mounted) return;

    final suppliers = context.read<SupplierProvider>().suppliers;
    final rices = context.read<RiceProvider>().rices;

    final result = await _viewModel.processImage(
      imagePath: image.path,
      suppliers: suppliers,
      rices: rices,
    );

    if (!mounted) return;

    if (!result.success) {
      HapticFeedback.vibrate();
      AppToast.warning(
        context,
        result.error ?? 'Không nhận diện được chữ trong ảnh.',
      );
      return;
    }

    _textController.text = result.recognizedText ?? '';
    _syncControllersFromViewModel();
  }

  void _runOcrExtraction() {
    final suppliers = context.read<SupplierProvider>().suppliers;
    final rices = context.read<RiceProvider>().rices;

    _viewModel.parseAndExtract(
      rawText: _textController.text,
      suppliers: suppliers,
      rices: rices,
    );

    HapticFeedback.lightImpact();
    _syncControllersFromViewModel();
  }

  Future<void> _confirmAndCreateImportReceipt() async {
    final result = await _viewModel.submit(
      importProvider: context.read<ImportProvider>(),
      quantityText: _quantityController.text,
      priceText: _purchasePriceController.text,
      batchCodeText: _batchCodeController.text,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop(
        result.message ??
            'Đã tạo phiếu nhập ${result.receiptCode ?? ''} từ OCR thành công!',
      );
    } else {
      AppToast.error(
        context,
        result.message ?? 'Không thể tạo phiếu nhập từ dữ liệu OCR.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suppliers = context.watch<SupplierProvider>().suppliers;
    final rices = context.watch<RiceProvider>().rices;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final qty = double.tryParse(_quantityController.text) ?? 0;
        final price = double.tryParse(_purchasePriceController.text) ?? 0;
        final totalCalc = qty * price;

        return Scaffold(
          appBar: AppBar(
            title: const Text('OCR Hóa đơn nhập kho'),
            actions: [
              IconButton(
                tooltip: 'Chụp hóa đơn',
                onPressed: _viewModel.isScanning
                    ? null
                    : () => _scanDocument(ImageSource.camera),
                icon: const Icon(Icons.document_scanner_outlined),
              ),
              IconButton(
                tooltip: 'Chọn ảnh hóa đơn',
                onPressed: _viewModel.isScanning
                    ? null
                    : () => _scanDocument(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
              ),
            ],
          ),
          body: Skeletonizer(
            enabled: _viewModel.isScanning,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Banner intro
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.document_scanner_outlined,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Trích xuất tự động thông tin nhà cung cấp, loại gạo, khối lượng, đơn giá và số lô từ hóa đơn / chứng từ.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Văn bản nhận dạng có thể được rà soát trước khi tạo phiếu.
                Text(
                  'Nội dung quét OCR (Văn bản nhận dạng):',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _textController,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'Chụp ảnh, chọn ảnh hoặc dán nội dung hóa đơn...',
                    suffixIcon: IconButton(
                      tooltip: 'Chạy phân tích OCR',
                      onPressed: _runOcrExtraction,
                      icon: const Icon(Icons.auto_awesome,
                          color: AppTheme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: _viewModel.isScanning ? null : _runOcrExtraction,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Phân tích lại OCR'),
                  ),
                ),

                const Divider(height: 28),

                // REVIEW SECTION (MANDATORY REQUIREMENT)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.rate_review_outlined,
                        color: AppTheme.accentGreen,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KIỂM TRA THÔNG TIN (REVIEW)',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accentGreen,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Bắt buộc kiểm tra & chỉnh sửa trước khi xác nhận tạo phiếu',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryColor(context),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Review dropdowns and inputs
                DropdownButtonFormField<SupplierModel>(
                  initialValue: _viewModel.selectedSupplier,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Nhà cung cấp (NCC)'),
                  items: suppliers
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => _viewModel.setSupplier(val),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<RiceModel>(
                  initialValue: _viewModel.selectedRice,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Loại gạo nhập'),
                  items: rices
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text('${r.name} (${r.code})',
                              overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => _viewModel.setRice(val),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _quantityController,
                        label: 'Số lượng (kg)',
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        controller: _purchasePriceController,
                        label: 'Đơn giá mua (VNĐ)',
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                CustomTextField(
                  controller: _batchCodeController,
                  label: 'Mã lô hàng mới',
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final rice = _viewModel.selectedRice;
                    final prefix = rice?.code ?? 'LO';
                    final existingBatches = rice == null
                        ? context.watch<BatchProvider>().batches
                        : context.watch<BatchProvider>().findByRiceId(rice.id);

                    return Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ActionChip(
                          backgroundColor: AppTheme.primaryLight,
                          label: Text(
                            'Mã mới: LO-$prefix-${(existingBatches.length + 1).toString().padLeft(3, '0')}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          onPressed: () {
                            _batchCodeController.text =
                                'LO-$prefix-${(existingBatches.length + 1).toString().padLeft(3, '0')}';
                          },
                        ),
                        ...existingBatches.take(3).map((b) => ActionChip(
                              label: Text(
                                b.code,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onPressed: () {
                                _batchCodeController.text = b.code;
                                _viewModel
                                    .setManufactureDate(b.manufactureDate);
                                _viewModel.setExpiryDate(b.expiryDate);
                              },
                            )),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title:
                            const Text('NSX:', style: TextStyle(fontSize: 12)),
                        subtitle: Text(
                          _viewModel.manufactureDate != null
                              ? DateFormatter.ddMMyyyy(
                                  _viewModel.manufactureDate!)
                              : 'Chưa chọn',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing:
                            const Icon(Icons.calendar_today_outlined, size: 16),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                _viewModel.manufactureDate ?? DateTime.now(),
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            _viewModel.setManufactureDate(picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title:
                            const Text('HSD:', style: TextStyle(fontSize: 12)),
                        subtitle: Text(
                          _viewModel.expiryDate != null
                              ? DateFormatter.ddMMyyyy(_viewModel.expiryDate!)
                              : 'Chưa chọn',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing:
                            const Icon(Icons.calendar_today_outlined, size: 16),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _viewModel.expiryDate ??
                                DateTime.now().add(const Duration(days: 365)),
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            _viewModel.setExpiryDate(picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Total amount summary
                Card(
                  color: const Color(0xFFDCFCE7),
                  child: ListTile(
                    leading: const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.accentGreen,
                    ),
                    title: const Text(
                      'Tổng tiền nhập tính toán',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Text(
                      CurrencyFormatter.formatVnd(totalCalc),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _viewModel.isSubmitting
                      ? null
                      : _confirmAndCreateImportReceipt,
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text(
                    'Xác nhận thông tin & Tạo phiếu nhập kho',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
