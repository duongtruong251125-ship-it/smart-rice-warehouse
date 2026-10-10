import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';
import 'package:smart_rice_warehouse/widgets/transaction_receipt_card.dart';

class ImportListScreen extends StatelessWidget {
  const ImportListScreen({super.key});

  Future<void> _openCreate(BuildContext context) async {
    final message = await Navigator.of(context).pushNamed(AppRoutes.addImport);
    if (!context.mounted || message is! String) {
      return;
    }
    AppToast.success(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final receipts = [...context.watch<ImportProvider>().receipts]
      ..sort((first, second) => second.date.compareTo(first.date));
    final riceProvider = context.watch<RiceProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Phiếu nhập kho')),
      body: receipts.isEmpty
          ? EmptyState(
              icon: Icons.download_outlined,
              message: 'Chưa có phiếu nhập',
              actionLabel: 'Tạo phiếu nhập',
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
                  icon: Icons.download_rounded,
                  code: receipt.code,
                  partyLabel: 'Nhà cung cấp',
                  partyName: receipt.supplierName,
                  dateText: DateFormatter.ddMMyyyy(receipt.date),
                  riceName: receipt.riceName,
                  quantityText:
                      '${NumberFormatter.quantity(receipt.quantity)} $unit',
                  totalText: CurrencyFormatter.formatVnd(receipt.totalAmount),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo phiếu nhập'),
      ),
    );
  }
}
