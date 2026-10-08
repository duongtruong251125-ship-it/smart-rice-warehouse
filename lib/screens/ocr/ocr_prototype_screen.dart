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
import 'package:smart_rice_warehouse/services/ocr_service.dart';
import 'package:smart_rice_warehouse/widgets/custom_text_field.dart';

class OcrPrototypeScreen extends StatefulWidget {
  const OcrPrototypeScreen({super.key});

  @override
  State<OcrPrototypeScreen> createState() => _OcrPrototypeScreenState();
}

class _OcrPrototypeScreenState extends State<OcrPrototypeScreen> {
  final _ocrService = const OcrService();
  final _textController = TextEditingController();

  bool _isScanning = false;

  // Controllers for review form
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _batchCodeController = TextEditingController();
  SupplierModel? _selectedSupplier;
  RiceModel? _selectedRice;
  DateTime? _manufactureDate;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    // Khởi tạo sẵn bằng hóa đơn mẫu 1
    _loadSample(OcrService.samples.first);
  }

  @override
  void dispose() {
    _textController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _batchCodeController.dispose();
    super.dispose();
  }

  void _loadSample(OcrSampleInvoice sample) {
    setState(() {
      _textController.text = sample.rawText.trim();
    });
    _runOcrExtraction();
  }

  void _runOcrExtraction() {
    setState(() {
      _isScanning = true;
    });

    final suppliers = context.read<SupplierProvider>().suppliers;
    final rices = context.read<RiceProvider>().rices;

    final result = _ocrService.parseInvoice(
      rawText: _textController.text,
      suppliers: suppliers,
      rices: rices,
    );

    setState(() {
      _isScanning = false;

      // Fill in Review form
      _quantityController.text = result.quantity != null
          ? (result.quantity == result.quantity!.roundToDouble()
              ? result.quantity!.toInt().toString()
              : result.quantity!.toString())
          : '';

      _purchasePriceController.text = result.purchasePrice != null
          ? (result.purchasePrice == result.purchasePrice!.roundToDouble()
              ? result.purchasePrice!.toInt().toString()
              : result.purchasePrice!.toString())
          : '';

      _batchCodeController.text = result.batchCode ??
          'LO-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      if (result.matchedSupplierId != null) {
        _selectedSupplier = suppliers.cast<SupplierModel?>().firstWhere(
              (s) => s?.id == result.matchedSupplierId,
              orElse: () => null,
            );
      }

      if (result.matchedRiceId != null) {
        _selectedRice = rices.cast<RiceModel?>().firstWhere(
              (r) => r?.id == result.matchedRiceId,
              orElse: () => null,
            );
      }

      final now = DateTime.now();
      _manufactureDate = result.manufactureDate ?? now.subtract(const Duration(days: 7));
      _expiryDate = result.expiryDate ?? now.add(const Duration(days: 365));
    });
  }

  void _confirmAndCreateImportReceipt() {
    final supplier = _selectedSupplier;
    final rice = _selectedRice;
    final quantity = double.tryParse(_quantityController.text.trim().replaceAll(',', '.'));
    final price = double.tryParse(_purchasePriceController.text.trim().replaceAll(',', '.'));
    final batchCode = _batchCodeController.text.trim();

    if (supplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn hoặc xác nhận Nhà cung cấp')),
      );
      return;
    }
    if (rice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn hoặc xác nhận Loại gạo')),
      );
      return;
    }
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số lượng phải lớn hơn 0')),
      );
      return;
    }
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giá nhập phải lớn hơn 0')),
      );
      return;
    }
    if (batchCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã lô không được để trống')),
      );
      return;
    }

    final now = DateTime.now();
    final importProvider = context.read<ImportProvider>();
    // BatchProvider and ImportProvider allow both new batch and replenishing existing batch

    final newBatch = BatchModel(
      id: 'batch-${now.microsecondsSinceEpoch}',
      code: batchCode,
      riceId: rice.id,
      riceName: rice.name,
      quantity: quantity,
      importDate: now,
      manufactureDate: _manufactureDate ?? now,
      expiryDate: _expiryDate ?? now.add(const Duration(days: 365)),
      status: BatchStatus.available,
    );

    final newReceipt = ImportReceiptModel(
      id: 'import-${now.microsecondsSinceEpoch}',
      code: importProvider.generateReceiptCode(),
      supplierId: supplier.id,
      supplierName: supplier.name,
      date: now,
      riceId: rice.id,
      riceName: rice.name,
      quantity: quantity,
      purchasePrice: price,
      totalAmount: quantity * price,
      batchCode: batchCode,
      manufactureDate: _manufactureDate ?? now,
      expiryDate: _expiryDate ?? now.add(const Duration(days: 365)),
    );

    final success = importProvider.createImportReceipt(
      receipt: newReceipt,
      batch: newBatch,
    );

    if (success) {
      Navigator.of(context).pop('Đã tạo phiếu nhập ${newReceipt.code} từ OCR thành công!');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi khi tạo phiếu nhập kho')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suppliers = context.watch<SupplierProvider>().suppliers;
    final rices = context.watch<RiceProvider>().rices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Hóa đơn nhập kho (Prototype)'),
      ),
      body: ListView(
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

          // Sample chips
          Text(
            'Chọn mẫu hóa đơn thử nghiệm:',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: OcrService.samples.map((sample) {
                final isSelected = _textController.text.contains(
                  sample.rawText.trim().substring(0, 15),
                );
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.receipt_outlined, size: 16),
                    label: Text(sample.title),
                    backgroundColor: isSelected
                        ? AppTheme.primaryLight
                        : AppTheme.cardColor,
                    onPressed: () => _loadSample(sample),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Raw text / OCR simulator box
          Text(
            'Nội dung quét OCR (Văn bản nhận dạng):',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _textController,
            maxLines: 4,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'Dán nội dung hóa đơn hoặc chọn mẫu phía trên...',
              suffixIcon: IconButton(
                tooltip: 'Chạy phân tích OCR',
                onPressed: _runOcrExtraction,
                icon: const Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _isScanning ? null : _runOcrExtraction,
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
                        color: AppTheme.textSecondary,
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
            value: _selectedSupplier,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nhà cung cấp (NCC)'),
            items: suppliers
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedSupplier = val),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<RiceModel>(
            value: _selectedRice,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Loại gạo nhập'),
            items: rices
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text('${r.name} (${r.code})', overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedRice = val),
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
              final rice = _selectedRice;
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
                      setState(() {
                        _batchCodeController.text =
                            'LO-$prefix-${(existingBatches.length + 1).toString().padLeft(3, '0')}';
                      });
                    },
                  ),
                  ...existingBatches.take(3).map((b) => ActionChip(
                        label: Text(
                          b.code,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () {
                          setState(() {
                            _batchCodeController.text = b.code;
                            _manufactureDate = b.manufactureDate;
                            _expiryDate = b.expiryDate;
                          });
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
                  title: const Text('NSX:', style: TextStyle(fontSize: 12)),
                  subtitle: Text(
                    _manufactureDate != null
                        ? DateFormatter.ddMMyyyy(_manufactureDate!)
                        : 'Chưa chọn',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined, size: 16),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _manufactureDate ?? DateTime.now(),
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _manufactureDate = picked);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('HSD:', style: TextStyle(fontSize: 12)),
                  subtitle: Text(
                    _expiryDate != null
                        ? DateFormatter.ddMMyyyy(_expiryDate!)
                        : 'Chưa chọn',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined, size: 16),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _expiryDate = picked);
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
                CurrencyFormatter.formatVnd(
                  (double.tryParse(_quantityController.text) ?? 0) *
                      (double.tryParse(_purchasePriceController.text) ?? 0),
                ),
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
            onPressed: _confirmAndCreateImportReceipt,
            icon: const Icon(Icons.add_task_rounded),
            label: const Text(
              'Xác nhận thông tin & Tạo phiếu nhập kho',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
