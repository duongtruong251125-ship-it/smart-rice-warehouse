import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
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

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animScanLine;
  final TextEditingController _manualInputController = TextEditingController();
  bool _isTorchOn = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _animScanLine = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  void _handleQrData(String rawCode) {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final parsed = QrService.parseBatchQr(rawCode);
    final batchProvider = context.read<BatchProvider>();

    BatchModel? matchedBatch;
    if (parsed.batchCode != null) {
      matchedBatch = batchProvider.findByCode(parsed.batchCode!);
    }
    if (matchedBatch == null && parsed.batchId != null) {
      matchedBatch = batchProvider.findById(parsed.batchId!);
    }
    matchedBatch ??= batchProvider.findByCode(rawCode);

    if (matchedBatch != null) {
      if (widget.onBatchScanned != null) {
        widget.onBatchScanned!(matchedBatch);
        Navigator.of(context).pop(matchedBatch);
      } else {
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.batchDetail,
          arguments: matchedBatch.id,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không tìm thấy lô hàng với mã QR: "$rawCode"',
          ),
          backgroundColor: AppTheme.dangerColor,
          duration: const Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _isProcessing = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchProvider = context.watch<BatchProvider>();
    final availableBatches = batchProvider.batches;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: _isTorchOn ? 'Tắt đèn Flash' : 'Bật đèn Flash',
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? Colors.amber : Colors.white,
            ),
            onPressed: () {
              setState(() => _isTorchOn = !_isTorchOn);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isTorchOn ? 'Đã bật đèn Flash' : 'Đã tắt đèn Flash'),
                  duration: const Duration(milliseconds: 600),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Khung quét giả lập & viewfinder
            Expanded(
              flex: 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Hướng dẫn
                  Positioned(
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.center_focus_strong, color: Colors.white70, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Đặt mã QR của bao/lô gạo vào giữa khung',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Khung vuông Scanner 240x240
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primaryColor, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: AnimatedBuilder(
                      animation: _animScanLine,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _ScannerOverlayPainter(
                            progress: _animScanLine.value,
                            primaryColor: AppTheme.primaryColor,
                          ),
                        );
                      },
                    ),
                  ),

                  // 4 góc định vị
                  const SizedBox(
                    width: 256,
                    height: 256,
                    child: Stack(
                      children: [
                        Positioned(top: 0, left: 0, child: _CornerMarker(isTop: true, isLeft: true)),
                        Positioned(top: 0, right: 0, child: _CornerMarker(isTop: true, isLeft: false)),
                        Positioned(bottom: 0, left: 0, child: _CornerMarker(isTop: false, isLeft: true)),
                        Positioned(bottom: 0, right: 0, child: _CornerMarker(isTop: false, isLeft: false)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Khu vực Nhập mã thủ công & Chọn lô quét mẫu demo
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Nhập mã hoặc chọn lô để quét thử:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Ô nhập mã thủ công (hỗ trợ nhập tay hoặc đầu đọc barcode/QR ngoài)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualInputController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Nhập mã lô (VD: LO-ST25-001)',
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                filled: true,
                                fillColor: const Color(0xFF334155),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (text) {
                                if (text.trim().isNotEmpty) {
                                  _handleQrData(text.trim());
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              final text = _manualInputController.text.trim();
                              if (text.isNotEmpty) {
                                _handleQrData(text);
                              }
                            },
                            child: const Text(
                              'Quét',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Danh sách các chip lô hàng mẫu để test nhanh
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableBatches.take(6).map((b) {
                          return ActionChip(
                            backgroundColor: const Color(0xFF334155),
                            avatar: const Icon(Icons.qr_code, size: 16, color: AppTheme.accentGreen),
                            label: Text(
                              '${b.code} (${b.riceName})',
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                            onPressed: () => _handleQrData(b.code),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerMarker extends StatelessWidget {
  const _CornerMarker({required this.isTop, required this.isLeft});

  final bool isTop;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: Colors.white, width: 3.5) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: Colors.white, width: 3.5) : BorderSide.none,
          left: isLeft ? const BorderSide(color: Colors.white, width: 3.5) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: Colors.white, width: 3.5) : BorderSide.none,
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter({
    required this.progress,
    required this.primaryColor,
  });

  final double progress;
  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
