import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/presentation/utils/app_toast.dart';
import 'package:smart_rice_warehouse/logic/models/batch_model.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/services/qr_service.dart';

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

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _manualController = TextEditingController();
  late final AnimationController _laserController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
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
      HapticFeedback.vibrate();
      AppToast.error(context, 'Không tìm thấy lô hàng với mã: $rawCode');
      setState(() => _isProcessing = false);
      return;
    }

    // Phản hồi xúc giác thành công nhẹ nhàng, êm ái
    HapticFeedback.lightImpact();

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
            onPressed: () {
              HapticFeedback.selectionClick();
              _scannerController.toggleTorch();
            },
            icon: const Icon(Icons.flash_on_rounded),
          ),
          IconButton(
            tooltip: 'Đổi camera',
            onPressed: () {
              HapticFeedback.selectionClick();
              _scannerController.switchCamera();
            },
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
                AnimatedBuilder(
                  animation: _laserController,
                  builder: (context, _) {
                    return IgnorePointer(
                      child: CustomPaint(
                        painter: _ScannerFramePainter(
                          animationValue: _laserController.value,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          color: AppTheme.primaryColor,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Đặt mã QR vào giữa khung để quét tự động',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isProcessing)
                  const ColoredBox(
                    color: Color(0x66000000),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    ),
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
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _handleQrData(_manualController.text.trim());
                    },
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
  const _ScannerFramePainter({required this.animationValue});

  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * 0.68;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );

    // 1. Lớp phủ đen mờ ngoài khung
    final overlay = Path()..addRect(Offset.zero & size);
    overlay.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)));
    overlay.fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, Paint()..color = const Color(0x99000000));

    // 2. Khung viền mờ xung quanh
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 3. 4 góc công nghệ cao màu Ngọc bích (Viewfinder corners)
    const cornerLength = 26.0;
    const cornerRadius = 16.0;
    final cornerPaint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    // Góc trên bên trái
    final topLeft = Path()
      ..moveTo(rect.left, rect.top + cornerLength)
      ..lineTo(rect.left, rect.top + cornerRadius)
      ..arcToPoint(
        Offset(rect.left + cornerRadius, rect.top),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(rect.left + cornerLength, rect.top);
    canvas.drawPath(topLeft, cornerPaint);

    // Góc trên bên phải
    final topRight = Path()
      ..moveTo(rect.right - cornerLength, rect.top)
      ..lineTo(rect.right - cornerRadius, rect.top)
      ..arcToPoint(
        Offset(rect.right, rect.top + cornerRadius),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(rect.right, rect.top + cornerLength);
    canvas.drawPath(topRight, cornerPaint);

    // Góc dưới bên phải
    final bottomRight = Path()
      ..moveTo(rect.right, rect.bottom - cornerLength)
      ..lineTo(rect.right, rect.bottom - cornerRadius)
      ..arcToPoint(
        Offset(rect.right - cornerRadius, rect.bottom),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(rect.right - cornerLength, rect.bottom);
    canvas.drawPath(bottomRight, cornerPaint);

    // Góc dưới bên trái
    final bottomLeft = Path()
      ..moveTo(rect.left + cornerLength, rect.bottom)
      ..lineTo(rect.left + cornerRadius, rect.bottom)
      ..arcToPoint(
        Offset(rect.left, rect.bottom - cornerRadius),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(rect.left, rect.bottom - cornerLength);
    canvas.drawPath(bottomLeft, cornerPaint);

    // 4. Tia Laser quét chuyển động (Laser Scanning Beam)
    final laserY = rect.top + 10 + (rect.height - 20) * animationValue;
    final laserRect =
        Rect.fromLTRB(rect.left + 4, laserY - 14, rect.right - 4, laserY);

    final sweepGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppTheme.primaryColor.withValues(alpha: 0.0),
        AppTheme.primaryColor.withValues(alpha: 0.08),
        AppTheme.primaryColor.withValues(alpha: 0.35),
      ],
    );
    canvas.drawRect(
      laserRect,
      Paint()..shader = sweepGradient.createShader(laserRect),
    );

    // Đường chỉ laser chính phát sáng
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.primaryColor.withValues(alpha: 0.1),
          const Color(0xFF34D399),
          AppTheme.primaryColor,
          const Color(0xFF34D399),
          AppTheme.primaryColor.withValues(alpha: 0.1),
        ],
      ).createShader(Rect.fromLTWH(rect.left, laserY, rect.width, 2.5))
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(rect.left + 6, laserY),
      Offset(rect.right - 6, laserY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
