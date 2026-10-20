import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/presentation/utils/app_toast.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
import 'package:smart_rice_warehouse/logic/models/customer_model.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/logic/services/catalog_form_service.dart';
import 'package:smart_rice_warehouse/presentation/widgets/confirmation_dialog.dart';
import 'package:smart_rice_warehouse/presentation/widgets/management_list_scaffold.dart';
import 'package:smart_rice_warehouse/presentation/widgets/status_chip.dart';

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

    final result = await CatalogFormService().deleteCustomer(
      customerProvider: context.read<CustomerProvider>(),
      exportProvider: context.read<ExportProvider>(),
      customer: customer,
    );
    if (!mounted) return;
    _showMessage(result.message);
  }

  void _showMessage(String message) {
    if (message.startsWith('Không')) {
      AppToast.error(context, message);
    } else {
      AppToast.success(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = context.watch<AuthProvider?>()?.isStaff ?? false;
    final customerProvider = context.watch<CustomerProvider>();
    final customers = customerProvider.searchCustomers(_query);

    return ManagementListScaffold(
      title: 'Khách hàng',
      roleBanner: isStaff ? const StaffReadOnlyBanner() : null,
      isLoading: customerProvider.isLoading,
      errorMessage: customerProvider.errorMessage,
      onRetry: customerProvider.retrySync,
      searchController: _searchController,
      searchHint: 'Tìm theo tên, điện thoại hoặc loại khách',
      onSearchChanged: (value) {
        setState(() {
          _query = value;
        });
      },
      onAdd: isStaff ? null : _openAdd,
      addLabel: 'Thêm khách hàng',
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return _CustomerCard(
          customer: customer,
          onEdit: isStaff ? null : () => _openEdit(customer),
          onDelete: isStaff ? null : () => _delete(customer),
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
    this.onEdit,
    this.onDelete,
  });

  final CustomerModel customer;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: AppTheme.softShadow,
      ),
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
                color: AppTheme.isDark(context)
                    ? AppTheme.darkCardElevated
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border(context)),
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
                if (onEdit != null)
                  IconButton(
                    tooltip: 'Sửa',
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                if (onDelete != null)
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
