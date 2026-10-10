import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/screens/export/export_detail_screen.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';
import 'package:smart_rice_warehouse/widgets/transaction_receipt_card.dart';

class ExportListScreen extends StatelessWidget {
  const ExportListScreen({super.key});

  Future<void> _openCreate(BuildContext context) async {
    final message = await Navigator.of(context).pushNamed(AppRoutes.addExport);
    if (!context.mounted || message is! String) {
      return;
    }
    AppToast.success(context, message);
  }

  void _openDetail(BuildContext context, ExportReceiptModel receipt) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExportDetailScreen(receipt: receipt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receipts = [...context.watch<ExportProvider>().receipts]
      ..sort((first, second) => second.date.compareTo(first.date));
    final riceProvider = context.watch<RiceProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Phiếu xuất kho')),
      body: receipts.isEmpty
          ? EmptyState(
              icon: Icons.upload_outlined,
              message: 'Chưa có phiếu xuất',
              actionLabel: 'Tạo phiếu xuất',
              onAction: () => _openCreate(context),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: receipts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final receipt = receipts[index];
                final unit =
                    riceProvider.findById(receipt.riceId)?.unit ?? 'kg';
                return TransactionReceiptCard(
                  icon: Icons.upload_rounded,
                  code: receipt.code,
                  partyLabel: 'Khách hàng',
                  partyName: receipt.customerName,
                  dateText: DateFormatter.ddMMyyyy(receipt.date),
                  riceName: receipt.riceName,
                  quantityText:
                      '${NumberFormatter.quantity(receipt.quantity)} $unit',
                  totalText: CurrencyFormatter.formatVnd(receipt.totalAmount),
                  onTap: () => _openDetail(context, receipt),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo phiếu xuất'),
      ),
    );
  }
}
