import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/models/customer_model.dart';
import 'package:smart_rice_warehouse/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/widgets/confirmation_dialog.dart';
import 'package:smart_rice_warehouse/widgets/management_list_scaffold.dart';
import 'package:smart_rice_warehouse/widgets/status_chip.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAdd() async {
    final message =
        await Navigator.of(context).pushNamed(AppRoutes.addCustomer);
    if (!mounted || message is! String) {
      return;
    }
    _showMessage(message);
  }

  Future<void> _openEdit(CustomerModel customer) async {
    final message = await Navigator.of(context).pushNamed(
      AppRoutes.editCustomer,
      arguments: customer.id,
    );
    if (!mounted || message is! String) {
      return;
    }
    _showMessage(message);
  }

  Future<void> _delete(CustomerModel customer) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Xóa khách hàng',
      message: 'Bạn có chắc muốn xóa khách hàng ${customer.name} không?',
    );
    if (!mounted || !confirmed) {
      return;
    }

    if (context.read<CustomerProvider>().deleteCustomer(customer.id)) {
      _showMessage('Đã xóa khách hàng');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<CustomerProvider>().searchCustomers(_query);

    return ManagementListScaffold(
      title: 'Khách hàng',
      searchController: _searchController,
      searchHint: 'Tìm theo tên, điện thoại hoặc loại khách',
      onSearchChanged: (value) {
        setState(() {
          _query = value;
        });
      },
      onAdd: _openAdd,
      addLabel: 'Thêm khách hàng',
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return _CustomerCard(
          customer: customer,
          onEdit: () => _openEdit(customer),
          onDelete: () => _delete(customer),
        );
      },
      emptyMessage: 'Chưa có khách hàng',
      emptyIcon: Icons.groups_outlined,
      hasSearchQuery: _query.trim().isNotEmpty,
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomerModel customer;
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
                    Icons.person_outline_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customer.customerType.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
                  _InfoLine(icon: Icons.phone_outlined, text: customer.phone),
                  const SizedBox(height: 6),
                  _InfoLine(
                    icon: Icons.location_on_outlined,
                    text: customer.address,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                StatusChip.active(isActive: customer.isActive),
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

