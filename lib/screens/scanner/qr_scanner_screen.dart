import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/services/qr_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({
    super.key,
    this.onBatchScanned,
    this.title = 'Quét mã QR Lô gạo',
  });

  final void Function(BatchModel batch)? onBatchScanned;
  final String title;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _manualController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (value.isNotEmpty) {
      await _handleQrData(value);
    }
  }

  Future<void> _handleQrData(String rawCode) async {
    if (_isProcessing || rawCode.isEmpty) {
      return;
    }
    setState(() => _isProcessing = true);

    final parsed = QrService.parseBatchQr(rawCode);
    final batches = context.read<BatchProvider>();
    BatchModel? matched;
    if (parsed.batchCode != null) {
      matched = batches.findByCode(parsed.batchCode!);
    }
    if (matched == null && parsed.batchId != null) {
      matched = batches.findById(parsed.batchId!);
    }

    if (matched == null) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'Không tìm thấy lô hàng với mã: $rawCode');
      setState(() => _isProcessing = false);
      return;
    }

    await _scannerController.stop();
    if (!mounted) {
      return;
    }
    if (widget.onBatchScanned != null) {
      widget.onBatchScanned!(matched);
      Navigator.of(context).pop(matched);
    } else {
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.batchDetail,
        arguments: matched.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Bật/tắt đèn flash',
            onPressed: _scannerController.toggleTorch,
            icon: const Icon(Icons.flash_on_rounded),
          ),
          IconButton(
            tooltip: 'Đổi camera',
            onPressed: _scannerController.switchCamera,
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => _ScannerError(error: error),
                ),
                IgnorePointer(
                  child: CustomPaint(painter: _ScannerFramePainter()),
                ),
                const Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: Text(
                    'Đặt mã QR vào giữa khung. Camera sẽ tự nhận diện.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                if (_isProcessing)
                  const ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualController,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (value) => _handleQrData(value.trim()),
                      decoration: const InputDecoration(
                        hintText: 'Hoặc nhập mã lô thủ công',
                        hintStyle: TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        _handleQrData(_manualController.text.trim()),
                    child: const Text('Tìm'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Không thể mở camera. Hãy cấp quyền camera trong cài đặt thiết bị.\n${error.errorCode.name}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * 0.68;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    final overlay = Path()..addRect(Offset.zero & size);
    overlay.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)));
    overlay.fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, Paint()..color = const Color(0x88000000));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      Paint()
        ..color = AppTheme.primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
