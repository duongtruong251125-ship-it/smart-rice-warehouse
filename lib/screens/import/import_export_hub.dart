import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/core/utils/date_formatter.dart';
import 'package:smart_rice_warehouse/providers/export_provider.dart';
import 'package:smart_rice_warehouse/providers/import_provider.dart';
import 'package:smart_rice_warehouse/widgets/dashboard_card.dart';
import 'package:smart_rice_warehouse/widgets/section_title.dart';

class ImportExportHub extends StatelessWidget {
  const ImportExportHub({super.key});

  @override
  Widget build(BuildContext context) {
    final importProvider = context.watch<ImportProvider>();
    final exportProvider = context.watch<ExportProvider>();
    final isNarrow = MediaQuery.sizeOf(context).width < 340;
    final recentEntries = _buildRecentEntries(importProvider, exportProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const SectionTitle('Tổng quan phiếu kho'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: isNarrow ? 1 : 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: isNarrow ? 2.5 : 1.72,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            DashboardCard(
              icon: Icons.download_rounded,
              title: 'Tổng phiếu nhập',
              value: '${importProvider.receipts.length} phiếu',
              accentColor: AppTheme.accentGreen,
            ),
            DashboardCard(
              icon: Icons.upload_rounded,
              title: 'Tổng phiếu xuất',
              value: '${exportProvider.receipts.length} phiếu',
              accentColor: AppTheme.secondaryColor,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.addImport),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text(
                  'Tạo phiếu nhập',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.addExport),
                icon: const Icon(Icons.outbox_rounded, size: 18),
                label: const Text(
                  'Tạo phiếu xuất',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 11),
              side: const BorderSide(color: AppTheme.accentGreen),
            ),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.ocrPrototype),
            icon: const Icon(Icons.document_scanner_outlined,
                color: AppTheme.accentGreen, size: 18),
            label: const Text(
              'Nhập kho bằng OCR Hóa đơn (Prototype)',
              style: TextStyle(
                color: AppTheme.accentGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const SectionTitle('Sổ giao dịch Nhập / Xuất kho'),
        const SizedBox(height: 12),
        _TransactionCard(
          title: 'Phiếu nhập',
          subtitle: 'Quản lý các phiếu nhập kho & tạo lô gạo mới',
          badgeText: '${importProvider.receipts.length} phiếu',
          icon: Icons.download_rounded,
          accentColor: AppTheme.accentGreen,
          route: AppRoutes.import,
        ),
        const SizedBox(height: 10),
        _TransactionCard(
          title: 'Phiếu xuất',
          subtitle: 'Quản lý các phiếu xuất kho & bán hàng cho đại lý',
          badgeText: '${exportProvider.receipts.length} phiếu',
          icon: Icons.upload_rounded,
          accentColor: AppTheme.secondaryColor,
          route: AppRoutes.export,
        ),
        if (recentEntries.isNotEmpty) ...[
          const SizedBox(height: 22),
          const SectionTitle('Giao dịch gần đây'),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < recentEntries.length; i++) ...[
                  _RecentTransactionTile(entry: recentEntries[i]),
                  if (i < recentEntries.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.accentColor,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color accentColor;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accentColor, size: 24),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: accentColor,
          ),
        ),
        onTap: () => Navigator.of(context).pushNamed(route),
      ),
    );
  }
}

class _RecentEntry {
  const _RecentEntry({
    required this.code,
    required this.riceName,
    required this.partnerName,
    required this.date,
    required this.totalAmount,
    required this.isImport,
  });

  final String code;
  final String riceName;
  final String partnerName;
  final DateTime date;
  final double totalAmount;
  final bool isImport;
}

List<_RecentEntry> _buildRecentEntries(
  ImportProvider importProvider,
  ExportProvider exportProvider,
) {
  final list = <_RecentEntry>[
    for (final r in importProvider.receipts)
      _RecentEntry(
        code: r.code,
        riceName: r.riceName,
        partnerName: r.supplierName,
        date: r.date,
        totalAmount: r.totalAmount,
        isImport: true,
      ),
    for (final r in exportProvider.receipts)
      _RecentEntry(
        code: r.code,
        riceName: r.riceName,
        partnerName: r.customerName,
        date: r.date,
        totalAmount: r.totalAmount,
        isImport: false,
      ),
  ];
  list.sort((a, b) => b.date.compareTo(a.date));
  return list.take(4).toList();
}

class _RecentTransactionTile extends StatelessWidget {
  const _RecentTransactionTile({required this.entry});

  final _RecentEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        entry.isImport ? AppTheme.accentGreen : AppTheme.secondaryColor;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          entry.isImport ? Icons.south_west_rounded : Icons.north_east_rounded,
          color: color,
          size: 18,
        ),
      ),
      title: Text(
        '${entry.code} • ${entry.riceName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${entry.partnerName} • ${DateFormatter.ddMMyyyy(entry.date)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        '${entry.isImport ? '+' : '-'}${CurrencyFormatter.formatVnd(entry.totalAmount)}',
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

