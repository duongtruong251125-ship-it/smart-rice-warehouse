import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/models/supplier_model.dart';
import 'package:smart_rice_warehouse/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/widgets/confirmation_dialog.dart';
import 'package:smart_rice_warehouse/widgets/management_list_scaffold.dart';
import 'package:smart_rice_warehouse/widgets/status_chip.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAdd() async {
    final message =
        await Navigator.of(context).pushNamed(AppRoutes.addSupplier);
    if (!mounted || message is! String) {
      return;
    }
    _showMessage(message);
  }

  Future<void> _openEdit(SupplierModel supplier) async {
    final message = await Navigator.of(context).pushNamed(
      AppRoutes.editSupplier,
      arguments: supplier.id,
    );
    if (!mounted || message is! String) {
      return;
    }
    _showMessage(message);
  }

  Future<void> _delete(SupplierModel supplier) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Xóa nhà cung cấp',
      message: 'Bạn có chắc muốn xóa nhà cung cấp ${supplier.name} không?',
    );
    if (!mounted || !confirmed) {
      return;
    }

    if (context.read<SupplierProvider>().deleteSupplier(supplier.id)) {
      _showMessage('Đã xóa nhà cung cấp');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = context.watch<SupplierProvider>().searchSuppliers(_query);

    return ManagementListScaffold(
      title: 'Nhà cung cấp',
      searchController: _searchController,
      searchHint: 'Tìm theo tên, điện thoại, email hoặc mã số thuế',
      onSearchChanged: (value) {
        setState(() {
          _query = value;
        });
      },
      onAdd: _openAdd,
      addLabel: 'Thêm nhà cung cấp',
      itemCount: suppliers.length,
      itemBuilder: (context, index) {
        final supplier = suppliers[index];
        return _SupplierCard(
          supplier: supplier,
          onEdit: () => _openEdit(supplier),
          onDelete: () => _delete(supplier),
        );
      },
      emptyMessage: 'Chưa có nhà cung cấp',
      emptyIcon: Icons.local_shipping_outlined,
      hasSearchQuery: _query.trim().isNotEmpty,
    );
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
  });

  final SupplierModel supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    supplier.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _InfoLine(icon: Icons.phone_outlined, text: supplier.phone),
                  if (supplier.email.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _InfoLine(icon: Icons.email_outlined, text: supplier.email),
                  ],
                  const SizedBox(height: 6),
                  _InfoLine(
                    icon: Icons.location_on_outlined,
                    text: supplier.address,
                  ),
                  if (supplier.taxCode.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _InfoLine(
                      icon: Icons.receipt_long_outlined,
                      text: 'MST: ${supplier.taxCode}',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                StatusChip.active(isActive: supplier.isActive),
                const Spacer(),
                IconButton(
                  tooltip: 'Sửa',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Xóa',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}

